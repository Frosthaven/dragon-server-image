#!/bin/bash

# Dragon User Setup - First Boot Script
# This script runs on first boot to:
# 1. Copy SSH keys from root to dragon user
# 2. Prompt for optional Recovery Console password
# 3. Disable root SSH login

set -e

NORMAL=$'\e[0m'
YELLOW=$'\e[33m'
CYAN=$'\e[36m'
RED=$'\e[31m'
GREEN=$'\e[32m'

MARKER_FILE="/home/dragon/.ssh/.dragon-setup-complete"

# Check if already completed
if [ -f "$MARKER_FILE" ]; then
    echo "Dragon user setup already completed."
    exit 0
fi

echo ""
echo "${GREEN}――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――${NORMAL}"
echo "${GREEN}Dragon User Setup${NORMAL}"
echo "${GREEN}――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――${NORMAL}"
echo ""

# Step 1: Copy SSH keys from root to dragon
echo "Copying SSH keys to dragon user..."

if [ -f /root/.ssh/authorized_keys ]; then
    mkdir -p /home/dragon/.ssh
    cp /root/.ssh/authorized_keys /home/dragon/.ssh/authorized_keys
    chown -R dragon:dragon /home/dragon/.ssh
    chmod 700 /home/dragon/.ssh
    chmod 600 /home/dragon/.ssh/authorized_keys
    echo "${GREEN}SSH keys copied successfully.${NORMAL}"
else
    echo "${RED}Warning: No SSH keys found in /root/.ssh/authorized_keys${NORMAL}"
    echo "You may need to add SSH keys manually to /home/dragon/.ssh/authorized_keys"
fi

# Get server IP for display
server_ip=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "You can now SSH into this server as: ${CYAN}ssh dragon@${server_ip}${NORMAL}"
echo ""
echo "Root SSH login will be disabled for security."
echo ""

# Step 2: Prompt for Recovery Console password
echo "${YELLOW}WARNING: Cloud provider recovery consoles require a password to log in.${NORMAL}"
echo "If you do not set a password for the 'dragon' user, you will lose access"
echo "to the recovery console. This console is only needed if SSH becomes"
echo "completely unavailable (e.g., firewall misconfiguration, SSH daemon crash)."
echo ""
echo "Normal SSH access will continue to work with your SSH key regardless of"
echo "whether you set a password."
echo ""
echo -n "Set a password for 'dragon' user for recovery console access? (y/N): "
read -r set_password

if [[ "$set_password" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Please enter a password for the 'dragon' user:"
    passwd dragon
    echo ""
    echo "${GREEN}Password set successfully.${NORMAL}"
else
    echo ""
    echo "Skipping password setup. Recovery console will not be available."
    echo "You can set a password later with: ${YELLOW}sudo passwd dragon${NORMAL}"
fi

echo ""

# Step 3: Disable root SSH login
echo "Disabling root SSH login..."

# Check if PermitRootLogin is already set in drop-in config
if grep -q "^PermitRootLogin" /etc/ssh/sshd_config.d/99-hardening.conf 2>/dev/null; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config.d/99-hardening.conf
else
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config.d/99-hardening.conf
fi

# Also update main sshd_config in case drop-in isn't used
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Restart SSH daemon
systemctl restart sshd

echo "${GREEN}Root SSH login has been disabled.${NORMAL}"
echo ""

# Create marker file
touch "$MARKER_FILE"
chown dragon:dragon "$MARKER_FILE"

echo "${GREEN}Dragon user setup complete!${NORMAL}"
echo ""
