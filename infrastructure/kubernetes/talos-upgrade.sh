#!/bin/bash
#
# Upgrade Talos and Kubernetes node by node, driven by environment.<env>.tfvars.
#
#   ./talos-upgrade.sh <dev|prod> [--check]
#
# Everything is read from environment.<env>.tfvars through `tofu console`:
#   nodes                       node names, roles and IP addresses
#   image.installer_image       target Talos installer, e.g.
#                               factory.talos.dev/nocloud-installer/<schematic>:v1.14.5
#                               (leave null to skip the Talos upgrade)
#   cluster.kubernetes_version  target Kubernetes version
#                               (equal to the running version skips the Kubernetes upgrade)
#
# Order of work:
#   1. Pre-flight: tools, config files, nodes in tfvars match the cluster, cluster health.
#   2. Talos: control plane nodes first, then workers, one node at a time.
#   3. Kubernetes: control plane components per control plane node, then the kubelet
#      per node (control planes first), then `talosctl upgrade-k8s` to sync the
#      bootstrap manifests.
#
# Every node change needs approval. Health checks run before and after each node,
# and the script stops at the first failed check.
#
# --check runs the pre-flight checks and prints the plan without changing anything.

set -euo pipefail

usage() {
  echo "Usage: $0 <dev|prod> [--check]"
  exit 1
}

ENV="${1:-}"
MODE="${2:-}"
[[ "$ENV" =~ ^(dev|prod)$ ]] || usage
[[ -z "$MODE" || "$MODE" == "--check" ]] || usage
CHECK_ONLY=false
[[ "$MODE" == "--check" ]] && CHECK_ONLY=true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TFVARS="${UPGRADE_TFVARS:-${SCRIPT_DIR}/environment.${ENV}.tfvars}" # override for testing only
CONFIG_DIR="${SCRIPT_DIR}/../../config/${ENV}"
export TALOSCONFIG="${CONFIG_DIR}/talos-config.yaml"
KUBECONFIG_FILE="${CONFIG_DIR}/kube-config.yaml"
API_PORT=6443
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

# Timeouts in seconds
TALOS_UPGRADE_TIMEOUT=1200
NODE_READY_TIMEOUT=600
HEALTH_TIMEOUT=10m

# ── Output helpers ──────────────────────────────────────────────────────────────

info() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
step() { printf '\033[1;36m  -> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ok %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  !! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m  xx %s\033[0m\n' "$*" >&2; exit 1; }

# Ask for approval. Returns 0 for yes, 1 for skip; quit stops the script.
confirm() {
  local answer
  while true; do
    read -r -p "  ?? $1 [y]es / [s]kip / [q]uit: " answer </dev/tty
    case "$answer" in
      y | Y | yes) return 0 ;;
      s | S | skip) return 1 ;;
      q | Q | quit) die "Stopped by user." ;;
    esac
  done
}

# Ask a yes/no question where "no" stops the script.
confirm_or_stop() {
  local answer
  read -r -p "  ?? $1 [y/N]: " answer </dev/tty
  [[ "$answer" =~ ^(y|Y|yes)$ ]] || die "Stopped by user."
}

# Run a command until it succeeds or the timeout (seconds) passes.
wait_until() {
  local timeout=$1
  shift
  local start=$SECONDS
  until "$@" >/dev/null 2>&1; do
    if ((SECONDS - start > timeout)); then
      return 1
    fi
    sleep 10
  done
}

# ── Version helpers ─────────────────────────────────────────────────────────────

strip_v() { echo "${1#v}"; }

same_version() { [[ "$(strip_v "$1")" == "$(strip_v "$2")" ]]; }

# Fails unless target is the same minor or the next minor of current, and not older.
check_version_step() {
  local what=$1 current target
  current=$(strip_v "$2")
  target=$(strip_v "$3")
  local c_major c_minor t_major t_minor
  IFS=. read -r c_major c_minor _ <<<"$current"
  IFS=. read -r t_major t_minor _ <<<"$target"
  if [[ "$(printf '%s\n%s\n' "$current" "$target" | sort -V | tail -1)" != "$target" ]]; then
    die "$what: target $target is older than the running $current. Downgrades are not supported."
  fi
  if ((t_major != c_major || t_minor - c_minor > 1)); then
    die "$what: $current -> $target skips a minor version. Upgrade one minor version at a time."
  fi
}

# ── Read environment.<env>.tfvars ───────────────────────────────────────────────

for cmd in tofu talosctl kubectl jq; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is not installed or not in PATH."
done
[[ -f "$TFVARS" ]] || die "$TFVARS not found."
[[ -f "$TALOSCONFIG" ]] || die "$TALOSCONFIG not found. Run setup-config.sh or tofu-deploy.sh first."
[[ -f "$KUBECONFIG_FILE" ]] || die "$KUBECONFIG_FILE not found."

info "Reading $(basename "$TFVARS")"
VARS_JSON=$(
  cd "$SCRIPT_DIR" &&
    echo 'jsonencode({ nodes = var.nodes, cluster = var.cluster, image = var.image })' |
    tofu console -var-file="$TFVARS" 2>"$LOG_DIR/console.log" | jq -r .
) || true
if [[ -z "$VARS_JSON" ]] || ! jq -e .nodes >/dev/null 2>&1 <<<"$VARS_JSON"; then
  cat "$LOG_DIR/console.log" >&2
  die "Could not read the tfvars. Run 'tofu init' in $SCRIPT_DIR first."
fi

node_names() {
  jq -r --arg t "$1" '.nodes | to_entries | map(select(.value.machine_type == $t)) | sort_by(.key) | .[].key' <<<"$VARS_JSON"
}
ip_of() { jq -r --arg n "$1" '.nodes[$n].ip' <<<"$VARS_JSON"; }

mapfile -t CP_NAMES < <(node_names controlplane)
mapfile -t WK_NAMES < <(node_names worker)
((${#CP_NAMES[@]} > 0)) || die "No controlplane nodes found in $TFVARS."
CP_IPS=()
for n in "${CP_NAMES[@]}"; do CP_IPS+=("$(ip_of "$n")"); done
WK_IPS=()
for n in "${WK_NAMES[@]}"; do WK_IPS+=("$(ip_of "$n")"); done

TARGET_K8S=$(strip_v "$(jq -r '.cluster.kubernetes_version' <<<"$VARS_JSON")")
TALOS_CFG_VERSION=$(jq -r '.cluster.talos_version' <<<"$VARS_JSON")
INSTALLER=$(jq -r '.image.installer_image // empty' <<<"$VARS_JSON")
TARGET_TALOS=""
INSTALLER_PLATFORM=""
if [[ -n "$INSTALLER" ]]; then
  [[ "$INSTALLER" != *"://"* ]] ||
    die "image.installer_image must be an image reference without a URL scheme. Remove '${INSTALLER%%://*}://' from $INSTALLER"
  TARGET_TALOS="${INSTALLER##*:}"
  [[ "$TARGET_TALOS" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]] ||
    die "image.installer_image must end with a version tag, e.g. :v1.14.5 (got $INSTALLER)."
  if [[ "$INSTALLER" =~ ^[^/]+/([a-z0-9]+)-installer/ ]]; then
    INSTALLER_PLATFORM="${BASH_REMATCH[1]}"
  else
    INSTALLER_PLATFORM="metal" # generic installer image
  fi
fi

# ── Talos and Kubernetes API helpers ────────────────────────────────────────────

# A control plane node other than $1, used as the Talos endpoint and API server.
endpoint_for() {
  local ip
  for ip in "${CP_IPS[@]}"; do
    if [[ "$ip" != "$1" ]]; then
      echo "$ip"
      return
    fi
  done
  echo "$1" # single control plane node
}

tctl() {
  local node=$1
  shift
  talosctl -n "$node" -e "$(endpoint_for "$node")" "$@"
}

# kubectl through the API server of a control plane node other than $1.
kc() {
  local avoid=$1
  shift
  kubectl --kubeconfig "$KUBECONFIG_FILE" --server "https://$(endpoint_for "$avoid"):${API_PORT}" "$@"
}

# Lookups print an empty string when the node or API is unreachable (e.g. during a reboot).
talos_version_of() {
  { tctl "$1" version --short 2>/dev/null || true; } | awk '/^Server:/ { s = 1 } s && /Tag:/ { print $2; exit }'
}
platform_of() { tctl "$1" get platformmetadata -o jsonpath='{.spec.platform}' 2>/dev/null || true; }
hostname_of() { tctl "$1" get hostname -o jsonpath='{.spec.hostname}' 2>/dev/null || true; }

node_field() { kc "$2" get node "$1" -o jsonpath="$3" 2>/dev/null || true; }
node_is_ready() { [[ "$(node_field "$1" "$2" '{.status.conditions[?(@.type=="Ready")].status}')" == "True" ]]; }
node_internal_ip() { node_field "$1" "$2" '{.status.addresses[?(@.type=="InternalIP")].address}'; }
kubelet_version_of() { strip_v "$(node_field "$1" "$2" '{.status.nodeInfo.kubeletVersion}')"; }

# Image of a control plane static pod, e.g. registry.k8s.io/kube-apiserver:v1.35.4
static_pod_image() {
  kc "$3" -n kube-system get pod "$1-$2" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true
}
static_pod_ready() {
  [[ "$(kc "$3" -n kube-system get pod "$1-$2" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)" == "True" ]]
}
kubelet_image_repo() {
  local img
  img=$({ tctl "$1" get machineconfig -o jsonpath='{.spec}' 2>/dev/null || true; } |
    awk '/^machine:/ { m = 1 } m && /^    kubelet:/ { k = 1 } k && /image:/ { print $2; exit }')
  echo "${img%:*}"
}

# Conditions polled by wait_until.
talos_at() { same_version "$(talos_version_of "$1")" "$2"; }                            # ip version
static_pod_at() {                                                                       # component node ip version
  local img
  img=$(static_pod_image "$1" "$2" "$3")
  [[ -n "$img" ]] && same_version "${img##*:}" "$4" && static_pod_ready "$1" "$2" "$3"
}
kubelet_at() { same_version "$(kubelet_version_of "$1" "$2")" "$3" && node_is_ready "$1" "$2"; } # node ip version

# Cluster-wide Talos health check: etcd, control plane pods, kubelets, all nodes Ready.
health_check() {
  local ep
  ep=$(endpoint_for "${1:-}")
  local args=(--control-plane-nodes "$(IFS=,; echo "${CP_IPS[*]}")" --wait-timeout "$HEALTH_TIMEOUT")
  ((${#WK_IPS[@]} > 0)) && args+=(--worker-nodes "$(IFS=,; echo "${WK_IPS[*]}")")
  step "Cluster health check (talosctl health, up to $HEALTH_TIMEOUT)"
  if talosctl -n "$ep" -e "$ep" health "${args[@]}" >"$LOG_DIR/health.log" 2>&1; then
    ok "Cluster is healthy."
  else
    tail -20 "$LOG_DIR/health.log" >&2
    die "Cluster health check failed. Fix the cluster before continuing."
  fi
}

# ── Pre-flight ──────────────────────────────────────────────────────────────────

info "Pre-flight checks for environment '$ENV'"

UTC_HOUR=$(date -u +%H)
if [[ "$UTC_HOUR" == "00" ]] && ! $CHECK_ONLY; then
  warn "It is between 00:00 and 01:00 UTC, when the nightly backup stalls the control plane."
  confirm_or_stop "Continue anyway?"
fi

declare -A CUR_TALOS CUR_KUBELET CUR_PLATFORM
for name in "${CP_NAMES[@]}" "${WK_NAMES[@]}"; do
  ip=$(ip_of "$name")
  v=$(talos_version_of "$ip")
  [[ -n "$v" ]] || die "$name ($ip): Talos API not reachable."
  CUR_TALOS[$name]=$v
  CUR_PLATFORM[$name]=$(platform_of "$ip")
  h=$(hostname_of "$ip")
  [[ "$h" == "$name" ]] || die "$name ($ip): hostname is '$h', expected '$name'."
  node_is_ready "$name" "$ip" || die "$name: Kubernetes node is not Ready."
  k_ip=$(node_internal_ip "$name" "$ip")
  [[ "$k_ip" == "$ip" ]] || die "$name: Kubernetes reports address $k_ip, tfvars says $ip."
  CUR_KUBELET[$name]=$(kubelet_version_of "$name" "$ip")
done
ok "All ${#CP_NAMES[@]} control plane and ${#WK_NAMES[@]} worker nodes from tfvars are reachable, Ready and match their name and address."

mapfile -t CLUSTER_NODES < <(kc "" get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
for n in "${CLUSTER_NODES[@]}"; do
  jq -e --arg n "$n" '.nodes | has($n)' >/dev/null <<<"$VARS_JSON" ||
    die "Kubernetes node '$n' is not in $TFVARS. Remove stale nodes or add them to tfvars first."
done

CLIENT_TALOS=$(talosctl version --client --short 2>/dev/null | awk '/Talos/ { print $2; exit }')
if [[ -n "$TARGET_TALOS" && -n "$CLIENT_TALOS" ]] &&
  [[ "$(printf '%s\n%s\n' "$(strip_v "$CLIENT_TALOS")" "$(strip_v "$TARGET_TALOS")" | sort -V | head -1)" != "$(strip_v "$TARGET_TALOS")" ]]; then
  warn "talosctl client $CLIENT_TALOS is older than target $TARGET_TALOS. Upgrade talosctl first."
fi

health_check

# ── Plan ────────────────────────────────────────────────────────────────────────

API_VERSION=$(strip_v "$(static_pod_image kube-apiserver "${CP_NAMES[0]}" "${CP_IPS[0]}" | sed 's/.*://')")

info "Plan"
printf '  %-20s %-13s %-16s %-24s %-22s %s\n' NODE ROLE IP TALOS KUBELET PLATFORM
for name in "${CP_NAMES[@]}" "${WK_NAMES[@]}"; do
  role=$(jq -r --arg n "$name" '.nodes[$n].machine_type' <<<"$VARS_JSON")
  t="${CUR_TALOS[$name]}"
  [[ -n "$TARGET_TALOS" ]] && ! same_version "$t" "$TARGET_TALOS" && t="$t -> $TARGET_TALOS"
  k="${CUR_KUBELET[$name]}"
  ! same_version "$k" "$TARGET_K8S" && k="$k -> $TARGET_K8S"
  printf '  %-20s %-13s %-16s %-24s %-22s %s\n' "$name" "$role" "$(ip_of "$name")" "$t" "$k" "${CUR_PLATFORM[$name]}"
done
echo
echo "  Talos target:       ${TARGET_TALOS:-none (image.installer_image is null)}"
[[ -n "$INSTALLER" ]] && echo "  Installer image:    $INSTALLER"
echo "  Kubernetes target:  $TARGET_K8S (control plane runs $API_VERSION)"

DO_TALOS=false
if [[ -n "$TARGET_TALOS" ]]; then
  for name in "${CP_NAMES[@]}" "${WK_NAMES[@]}"; do
    same_version "${CUR_TALOS[$name]}" "$TARGET_TALOS" && continue
    DO_TALOS=true
    check_version_step "Talos on $name" "${CUR_TALOS[$name]}" "$TARGET_TALOS"
    if [[ "${CUR_PLATFORM[$name]}" != "$INSTALLER_PLATFORM" ]]; then
      die "$name runs platform '${CUR_PLATFORM[$name]}', but the installer is for '$INSTALLER_PLATFORM'. Use factory.talos.dev/${CUR_PLATFORM[$name]}-installer/<schematic>:$TARGET_TALOS"
    fi
  done
fi

DO_K8S=false
for name in "${CP_NAMES[@]}" "${WK_NAMES[@]}"; do
  same_version "${CUR_KUBELET[$name]}" "$TARGET_K8S" || DO_K8S=true
done
same_version "$API_VERSION" "$TARGET_K8S" || DO_K8S=true
if $DO_K8S; then
  check_version_step "Kubernetes" "$API_VERSION" "$TARGET_K8S"
fi

if ! $DO_TALOS && ! $DO_K8S; then
  ok "Nothing to do: all nodes already run the target versions."
  exit 0
fi

if $CHECK_ONLY; then
  ok "Check finished. No changes made."
  exit 0
fi

UPGRADED=()
SKIPPED=()

# ── Talos ───────────────────────────────────────────────────────────────────────

upgrade_talos_node() {
  local name=$1 ip ep current
  ip=$(ip_of "$name")
  ep=$(endpoint_for "$ip")
  current=$(talos_version_of "$ip")

  info "Talos: $name ($ip)"
  if same_version "$current" "$TARGET_TALOS"; then
    ok "Already on $TARGET_TALOS."
    return
  fi
  echo "  Version:   $current -> $TARGET_TALOS"
  echo "  Installer: $INSTALLER"
  echo "  Endpoint:  $ep"
  if ! confirm "Upgrade Talos on $name?"; then
    warn "Skipped Talos upgrade of $name."
    SKIPPED+=("Talos $name")
    return
  fi

  health_check "$ip"
  step "Running talosctl upgrade (cordon, drain, install, reboot)"
  if ! talosctl -n "$ip" -e "$ep" upgrade --image "$INSTALLER" --wait --timeout "${TALOS_UPGRADE_TIMEOUT}s"; then
    die "talosctl upgrade failed for $name. If the node did not come back on $ip, check its console in Proxmox: it may have a different address."
  fi

  step "Verifying $name"
  wait_until "$NODE_READY_TIMEOUT" talos_at "$ip" "$TARGET_TALOS" ||
    die "$name does not report Talos $TARGET_TALOS."
  ok "Talos version is $TARGET_TALOS."
  [[ "$(platform_of "$ip")" == "${CUR_PLATFORM[$name]}" ]] ||
    die "$name now runs platform '$(platform_of "$ip")' instead of '${CUR_PLATFORM[$name]}'."
  ok "Platform is still ${CUR_PLATFORM[$name]}."
  [[ "$(hostname_of "$ip")" == "$name" ]] || die "$name came back with hostname '$(hostname_of "$ip")'."
  ok "Hostname is still $name."
  wait_until "$NODE_READY_TIMEOUT" node_is_ready "$name" "$ip" || die "Kubernetes node $name is not Ready."
  [[ "$(node_internal_ip "$name" "$ip")" == "$ip" ]] || die "Kubernetes node $name has a different address."
  ok "Kubernetes node is Ready on $ip."
  health_check "$ip"
  UPGRADED+=("Talos $name -> $TARGET_TALOS")
}

if $DO_TALOS; then
  info "Talos upgrade to $TARGET_TALOS: control plane nodes first, then workers"
  for name in "${CP_NAMES[@]}" "${WK_NAMES[@]}"; do
    upgrade_talos_node "$name"
  done
fi

# ── Kubernetes ──────────────────────────────────────────────────────────────────

CP_COMPONENTS=(kube-apiserver kube-controller-manager kube-scheduler)

upgrade_k8s_control_plane_node() {
  local name=$1 ip ep component img patch
  ip=$(ip_of "$name")
  ep=$(endpoint_for "$ip")
  info "Kubernetes control plane components: $name ($ip)"

  local pending=false
  for component in "${CP_COMPONENTS[@]}"; do
    img=$(static_pod_image "$component" "$name" "$ip")
    echo "  $component: ${img##*:}"
    same_version "${img##*:}" "$TARGET_K8S" || pending=true
  done
  if ! $pending; then
    ok "Already on $TARGET_K8S."
    return
  fi
  if ! confirm "Upgrade the control plane components on $name to $TARGET_K8S?"; then
    warn "Skipped control plane components on $name."
    SKIPPED+=("Kubernetes control plane $name")
    return
  fi

  health_check "$ip"
  patch="$LOG_DIR/cp-$name.yaml"
  {
    echo "cluster:"
    echo "  apiServer:"
    echo "    image: $(static_pod_image kube-apiserver "$name" "$ip" | sed 's/:[^:]*$//'):v$TARGET_K8S"
    echo "  controllerManager:"
    echo "    image: $(static_pod_image kube-controller-manager "$name" "$ip" | sed 's/:[^:]*$//'):v$TARGET_K8S"
    echo "  scheduler:"
    echo "    image: $(static_pod_image kube-scheduler "$name" "$ip" | sed 's/:[^:]*$//'):v$TARGET_K8S"
  } >"$patch"
  step "Patching machine config (no reboot)"
  talosctl -n "$ip" -e "$ep" patch machineconfig --mode=no-reboot --patch @"$patch"

  for component in "${CP_COMPONENTS[@]}"; do
    step "Waiting for $component on $name"
    wait_until "$NODE_READY_TIMEOUT" static_pod_at "$component" "$name" "$ip" "$TARGET_K8S" ||
      die "$component on $name did not become Ready on $TARGET_K8S."
    ok "$component runs $TARGET_K8S."
  done
  health_check "$ip"
  UPGRADED+=("Kubernetes control plane $name -> $TARGET_K8S")
}

upgrade_kubelet_node() {
  local name=$1 ip ep current repo patch
  ip=$(ip_of "$name")
  ep=$(endpoint_for "$ip")
  current=$(kubelet_version_of "$name" "$ip")
  info "Kubelet: $name ($ip)"
  if same_version "$current" "$TARGET_K8S"; then
    ok "Already on $TARGET_K8S."
    return
  fi
  repo=$(kubelet_image_repo "$ip")
  [[ -n "$repo" ]] || repo="ghcr.io/siderolabs/kubelet"
  echo "  Version: $current -> $TARGET_K8S"
  echo "  Image:   $repo:v$TARGET_K8S"
  if ! confirm "Upgrade the kubelet on $name to $TARGET_K8S?"; then
    warn "Skipped kubelet on $name."
    SKIPPED+=("Kubelet $name")
    return
  fi

  health_check "$ip"
  patch="$LOG_DIR/kubelet-$name.yaml"
  printf 'machine:\n  kubelet:\n    image: %s:v%s\n' "$repo" "$TARGET_K8S" >"$patch"
  step "Patching machine config (no reboot, kubelet restarts)"
  talosctl -n "$ip" -e "$ep" patch machineconfig --mode=no-reboot --patch @"$patch"

  step "Waiting for $name to report kubelet $TARGET_K8S and Ready"
  wait_until "$NODE_READY_TIMEOUT" kubelet_at "$name" "$ip" "$TARGET_K8S" ||
    die "$name did not come back Ready with kubelet $TARGET_K8S."
  ok "Kubelet runs $TARGET_K8S and the node is Ready."
  health_check "$ip"
  UPGRADED+=("Kubelet $name -> $TARGET_K8S")
}

if $DO_K8S; then
  info "Kubernetes upgrade to $TARGET_K8S"
  step "Pre-checks: talosctl upgrade-k8s --dry-run (Talos compatibility, image pre-pull)"
  MANIFESTS_IN_SYNC=true
  DRY_RUN_LOG="$LOG_DIR/k8s-dry-run.log"
  if talosctl -n "${CP_IPS[0]}" -e "${CP_IPS[0]}" upgrade-k8s --from "$API_VERSION" --to "$TARGET_K8S" --dry-run \
    >"$DRY_RUN_LOG" 2>&1; then
    grep -E 'compatible|deprecated|removed' "$DRY_RUN_LOG" | sed 's/^/  /' || true
    ok "Pre-checks passed."
  elif grep -q '^updating manifests' "$DRY_RUN_LOG"; then
    # Compatibility, removed flags/APIs and all component steps passed; only the
    # bootstrap manifest diff failed. The per-node upgrade does not need that sync.
    grep -E 'compatible|deprecated|removed' "$DRY_RUN_LOG" | sed 's/^/  /' || true
    ok "Compatibility and API pre-checks passed."
    warn "The bootstrap manifests cannot be synced:"
    grep -iE 'error|invalid' "$DRY_RUN_LOG" | cut -c1-300 | sed 's/^/     /' >&2 || true
    warn "This usually means a manifest in the machine config (inlineManifests or extraManifests)"
    warn "changed an immutable field, e.g. the cilium-install Job. The control plane components and"
    warn "kubelets can still be upgraded per node; the manifest sync step will be skipped."
    MANIFESTS_IN_SYNC=false
  else
    grep -v 'pre-pulling' "$DRY_RUN_LOG" | tail -30 >&2
    die "Kubernetes pre-checks failed. Talos may not support $TARGET_K8S yet: upgrade Talos first."
  fi
  confirm_or_stop "Start the Kubernetes upgrade to $TARGET_K8S?"

  # 1. Control plane components, one control plane node at a time.
  for name in "${CP_NAMES[@]}"; do
    upgrade_k8s_control_plane_node "$name"
  done

  # 2. Kubelets, control planes first. A kubelet must never be newer than the API server,
  #    so do not upgrade kubelets while control plane components were skipped.
  for name in "${CP_NAMES[@]}"; do
    img=$(static_pod_image kube-apiserver "$name" "$(ip_of "$name")")
    same_version "${img##*:}" "$TARGET_K8S" ||
      die "kube-apiserver on $name is not on $TARGET_K8S. Upgrade all control plane components before the kubelets."
  done
  for name in "${CP_NAMES[@]}" "${WK_NAMES[@]}"; do
    upgrade_kubelet_node "$name"
  done

  # 3. Bootstrap manifests (CoreDNS, kube-proxy, RBAC) through talosctl upgrade-k8s.
  info "Kubernetes bootstrap manifests"
  if ! $MANIFESTS_IN_SYNC; then
    warn "Skipping the manifest sync: the dry run could not diff the bootstrap manifests (see above)."
    warn "Fix the manifest in the machine config, then run: talosctl upgrade-k8s --to $TARGET_K8S --dry-run"
    SKIPPED+=("Kubernetes bootstrap manifests (dry run failed)")
  else
    echo "  talosctl upgrade-k8s syncs the bootstrap manifests for $TARGET_K8S: Talos' own manifests"
    echo "  (CoreDNS, RBAC) plus every inlineManifest and extraManifest in the machine config."
    echo "  Components and kubelets that already run $TARGET_K8S keep running."
  fi
  if $MANIFESTS_IN_SYNC && confirm "Run talosctl upgrade-k8s --to $TARGET_K8S --upgrade-kubelet=false?"; then
    talosctl -n "${CP_IPS[0]}" -e "${CP_IPS[0]}" upgrade-k8s --to "$TARGET_K8S" --upgrade-kubelet=false
    health_check
    UPGRADED+=("Kubernetes bootstrap manifests -> $TARGET_K8S")
  elif $MANIFESTS_IN_SYNC; then
    SKIPPED+=("Kubernetes bootstrap manifests")
  fi
fi

# ── Summary ─────────────────────────────────────────────────────────────────────

info "Summary"
for item in "${UPGRADED[@]:-}"; do [[ -n "$item" ]] && ok "$item"; done
for item in "${SKIPPED[@]:-}"; do [[ -n "$item" ]] && warn "Skipped: $item"; done

echo
echo "Next steps:"
if $DO_TALOS; then
  echo "  - In $(basename "$TFVARS"): set cluster.talos_version = \"$TARGET_TALOS\" (now \"$TALOS_CFG_VERSION\"),"
  echo "    set image.file_id to the new image's file_id, and set image.update_file_id and"
  echo "    image.installer_image back to null."
  echo "  - Remove the old version from images.${ENV}.tfvars and run ./tofu-images.sh ${ENV}."
fi
echo "  - Review 'tofu plan -var-file=$(basename "$TFVARS")' before running ./tofu-deploy.sh ${ENV}."
