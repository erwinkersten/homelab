#!/bin/bash

# Talos Node Upgrade Script
# Usage: upgrade-node.sh <node_ip> <node_name> <target_version> <schematic_id> <talos_config_path>

set -e

NODE_IP=$1
NODE_NAME=$2
TARGET_VERSION=$3
SCHEMATIC_ID=$4
TALOS_CONFIG=$5

if [[ -z "$NODE_IP" || -z "$NODE_NAME" || -z "$TARGET_VERSION" || -z "$SCHEMATIC_ID" || -z "$TALOS_CONFIG" ]]; then
    echo "Usage: $0 <node_ip> <node_name> <target_version> <schematic_id> <talos_config_path>"
    exit 1
fi

echo "==========================================="
echo "Upgrading Talos Node: $NODE_NAME ($NODE_IP)"
echo "Target Version: $TARGET_VERSION"
echo "Schematic ID: $SCHEMATIC_ID"
echo "==========================================="

# Check if talosctl is available
if ! command -v talosctl &> /dev/null; then
    echo "ERROR: talosctl is not installed or not in PATH"
    exit 1
fi

# Check if node is reachable
echo "Checking node connectivity..."
if ! talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" version > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to node $NODE_IP"
    exit 1
fi

# Get current version
echo "Getting current Talos version..."
CURRENT_VERSION=$(talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" version --client=false --short 2>/dev/null | grep "Tag:" | awk '{print $2}' || echo "unknown")
echo "Current version: $CURRENT_VERSION"

if [[ "$CURRENT_VERSION" == "$TARGET_VERSION" ]]; then
    echo "Node is already at target version $TARGET_VERSION"
    exit 0
fi

# Construct installer image
INSTALLER_IMAGE="factory.talos.dev/installer/${SCHEMATIC_ID}:${TARGET_VERSION}"
echo "Using installer image: $INSTALLER_IMAGE"

# Check if it's a control plane node
MACHINE_TYPE=$(talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" get machineconfig -o json 2>/dev/null | jq -r '.spec.machine.type' 2>/dev/null || echo "unknown")
echo "Machine type: $MACHINE_TYPE"

# Perform the upgrade
echo "Starting upgrade process..."
talosctl upgrade \
    --talosconfig "$TALOS_CONFIG" \
    --nodes "$NODE_IP" \
    --image "$INSTALLER_IMAGE" \
    --wait=false

echo "Upgrade command sent. Waiting for node to reboot..."

# Wait for node to become unreachable (indicating reboot started)
echo "Waiting for reboot to start..."
sleep 30

# Wait for node to come back online
echo "Waiting for node to come back online..."
TIMEOUT=600  # 10 minutes
ELAPSED=0
INTERVAL=10

while [[ $ELAPSED -lt $TIMEOUT ]]; do
    if talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" version > /dev/null 2>&1; then
        echo "Node is back online!"
        break
    fi
    
    echo "Waiting... ($ELAPSED/$TIMEOUT seconds)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [[ $ELAPSED -ge $TIMEOUT ]]; then
    echo "ERROR: Timeout waiting for node to come back online"
    exit 1
fi

# Additional wait for services to be ready
echo "Waiting for services to be ready..."
sleep 30

# Verify the upgrade
echo "Verifying upgrade..."
NEW_VERSION=$(talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" version --client=false --short 2>/dev/null | grep "Tag:" | awk '{print $2}' || echo "unknown")

if [[ "$NEW_VERSION" == "$TARGET_VERSION" ]]; then
    echo "✅ Upgrade successful! Node $NODE_NAME is now running Talos $NEW_VERSION"
else
    echo "❌ Upgrade verification failed. Expected $TARGET_VERSION, got $NEW_VERSION"
    exit 1
fi

# If it's a control plane node, wait for it to rejoin the cluster
if [[ "$MACHINE_TYPE" == "controlplane" ]]; then
    echo "Waiting for control plane node to rejoin cluster..."
    sleep 60
    
    # Check cluster health
    echo "Checking cluster health..."
    if talosctl --talosconfig "$TALOS_CONFIG" --nodes "$NODE_IP" health > /dev/null 2>&1; then
        echo "✅ Control plane node is healthy"
    else
        echo "⚠️  Warning: Control plane health check failed, but upgrade completed"
    fi
fi

echo "==========================================="
echo "Upgrade completed successfully!"
echo "Node: $NODE_NAME ($NODE_IP)"
echo "Version: $CURRENT_VERSION → $NEW_VERSION"
echo "==========================================="
