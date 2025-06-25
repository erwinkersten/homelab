#!/bin/bash

set -e

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required dependencies
sudo apt install -y curl wget gnupg2 ca-certificates lsb-release

# Determine system architecture
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
  ARCH="amd64"
elif [ "$ARCH" == "aarch64" ]; then
  ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Download Pangolin installer
INSTALLER_URL="https://github.com/fosrl/pangolin/releases/latest/download/installer_linux_${ARCH}"
wget -O pangolin_installer "$INSTALLER_URL"
chmod +x pangolin_installer

# Run the installer
sudo ./pangolin_installer

# Clean up installer
rm -f pangolin_installer

# Enable and start Pangolin service
sudo systemctl enable pangolin
sudo systemctl start pangolin

# Display status
sudo systemctl status pangolin --no-pager
echo "Pangolin setup completed successfully."