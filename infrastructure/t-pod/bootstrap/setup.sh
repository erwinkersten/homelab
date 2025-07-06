#!/bin/bash

set -e

echo "Starting T-Pot setup..."

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required dependencies
sudo apt install -y curl wget git

git clone https://github.com/telekom-security/tpotce
cd tpotce
# Checkout the latest stable branch
git checkout master
# Run the setup script
echo "Run T-Pot installation script manually."
echo "To complete the installation, run the following command:"
echo "Run the installer as non-root: $ ./install.sh   from the directory tpotce"