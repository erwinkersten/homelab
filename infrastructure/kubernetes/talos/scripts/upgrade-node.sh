#!/bin/bash

# Talos Node Upgrade Script
# Usage: upgrade-node.sh <node_ip> <node_name> <installer_image> <talos_config_path>
#
# installer_image — full image URL, e.g. factory.talos.dev/installer/{schematic}:v1.9.3
# Obtain from: tofu -chdir=images output -json images | jq -r '.[].installer_image'

set -euo pipefail

NODE_IP=$1
NODE_NAME=$2
INSTALLER_IMAGE=$3
TALOS_CONFIG=$4

if [[ -z "$NODE_IP" || -z "$NODE_NAME" || -z "$INSTALLER_IMAGE" || -z "$TALOS_CONFIG" ]]; then
  echo "Usage: $0 <node_ip> <node_name> <installer_image> <talos_config_path>"
  exit 1
fi

# Extract target version from the installer image tag
TARGET_VERSION="${INSTALLER_IMAGE##*:}"

echo "==========================================="
echo "Upgrading Talos Node: $NODE_NAME ($NODE_IP)"
echo "Installer image: $INSTALLER_IMAGE"
echo "Target version:  $TARGET_VERSION"
echo "==========================================="

if ! command -v talosctl &>/dev/null; then
  echo "ERROR: talosctl is not installed or not in PATH"
  exit 1
fi

echo "Checking node connectivity..."
if ! talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" version >/dev/null 2>&1; then
  echo "ERROR: Cannot connect to node $NODE_IP"
  exit 1
fi

CURRENT_VERSION=$(talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" version --client=false --short 2>/dev/null | grep "Tag:" | awk '{print $2}' || echo "unknown")
echo "Current version: $CURRENT_VERSION"

if [[ "$CURRENT_VERSION" == "$TARGET_VERSION" ]]; then
  echo "Node is already at $TARGET_VERSION — skipping upgrade."
  exit 0
fi

MACHINE_TYPE=$(talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" get machineconfig -o json 2>/dev/null | jq -r '.spec.machine.type' 2>/dev/null || echo "unknown")
echo "Machine type: $MACHINE_TYPE"

echo "Starting upgrade..."
talosctl upgrade \
  --talosconfig "$TALOS_CONFIG" \
  --nodes "$NODE_IP" \
  --image "$INSTALLER_IMAGE" \
  --preserve \
  --wait=false

echo "Upgrade command sent. Waiting for node to reboot..."
sleep 30

echo "Waiting for node to come back online..."
TIMEOUT=600
ELAPSED=0
INTERVAL=10

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  if talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" version >/dev/null 2>&1; then
    echo "Node is back online!"
    break
  fi
  echo "Waiting... (${ELAPSED}/${TIMEOUT}s)"
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

if [[ $ELAPSED -ge $TIMEOUT ]]; then
  echo "ERROR: Timeout waiting for node $NODE_NAME to come back online"
  exit 1
fi

sleep 30

NEW_VERSION=$(talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" version --client=false --short 2>/dev/null | grep "Tag:" | awk '{print $2}' || echo "unknown")

if [[ "$NEW_VERSION" != "$TARGET_VERSION" ]]; then
  echo "ERROR: Upgrade verification failed. Expected $TARGET_VERSION, got $NEW_VERSION"
  exit 1
fi

if [[ "$MACHINE_TYPE" == "controlplane" ]]; then
  echo "Waiting for control plane node to rejoin cluster..."
  sleep 60
  if talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" health >/dev/null 2>&1; then
    echo "Control plane node is healthy."
  else
    echo "WARNING: Control plane health check failed, but upgrade completed."
  fi
fi

echo "==========================================="
echo "Upgrade completed: $NODE_NAME ($NODE_IP)"
echo "Version: $CURRENT_VERSION -> $NEW_VERSION"
echo "==========================================="
