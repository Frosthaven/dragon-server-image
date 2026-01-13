#!/bin/bash

# Alloy first-boot initialization
# Configures Alloy with the server hostname and starts the service
# This script runs once on first boot to configure Alloy metrics collection
#
# Manual cleanup (if needed):
#   sudo systemctl stop alloy
#   sudo rm /var/lib/dragon/.alloy-configured

set -e

CONFIG_FILE="/etc/alloy/config.alloy"
MARKER_FILE="/var/lib/dragon/.alloy-configured"

# Exit if already initialized
if [ -f "$MARKER_FILE" ]; then
    echo "Alloy already configured."
    exit 0
fi

echo "Configuring Grafana Alloy metrics agent..."

# Get the server hostname
HOSTNAME=$(hostname -f 2>/dev/null || hostname)

# Update the Alloy config with the actual hostname
if [ -f "$CONFIG_FILE" ]; then
    sed -i "s|__HOSTNAME__|$HOSTNAME|g" "$CONFIG_FILE"
    echo "Configured Alloy with hostname: $HOSTNAME"
else
    echo "Error: Alloy config file not found at $CONFIG_FILE"
    exit 1
fi

# Start Alloy service
echo "Starting Alloy metrics agent..."
systemctl enable alloy
systemctl start alloy

# Wait for Alloy to be ready
sleep 2

# Verify Alloy is running
if systemctl is-active --quiet alloy; then
    echo "Alloy metrics agent is running."
else
    echo "Warning: Alloy failed to start. Check 'systemctl status alloy'"
    echo "You can retry with: sudo systemctl restart alloy"
fi

# Create marker file to prevent re-running
mkdir -p /var/lib/dragon
touch "$MARKER_FILE"

echo "Alloy configured successfully."
echo "Metrics are being collected and sent to VictoriaMetrics."
