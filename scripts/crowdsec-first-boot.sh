#!/bin/bash

# CrowdSec first-boot initialization
# Registers bouncer and starts services
# This script is run once on first boot to generate a unique bouncer API key per instance

set -e

MARKER_FILE="/var/lib/crowdsec/.first-boot-complete"

# Exit if already initialized
if [ -f "$MARKER_FILE" ]; then
    echo "CrowdSec already initialized."
    exit 0
fi

echo "Initializing CrowdSec security engine..."

# Start CrowdSec engine first
systemctl start crowdsec

# Wait for LAPI to be available (up to 60 seconds)
echo "Waiting for CrowdSec Local API..."
for i in {1..30}; do
    if cscli lapi status 2>/dev/null | grep -q "online"; then
        echo "CrowdSec Local API is online."
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Warning: Timed out waiting for CrowdSec LAPI. Continuing anyway..."
    fi
    sleep 2
done

# Delete existing bouncer registration (from image build) and re-register
# This ensures each droplet instance gets a unique API key
cscli bouncers delete crowdsec-firewall-bouncer-iptables 2>/dev/null || true

# Register bouncer with fresh API key
echo "Registering firewall bouncer..."
API_KEY=$(cscli bouncers add crowdsec-firewall-bouncer-iptables -o raw)

if [ -z "$API_KEY" ]; then
    echo "Error: Failed to generate bouncer API key."
    exit 1
fi

# Update bouncer config with new API key
sed -i "s/^api_key:.*/api_key: $API_KEY/" /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml

# Start the firewall bouncer
echo "Starting firewall bouncer..."
systemctl start crowdsec-firewall-bouncer

# Create marker file to prevent re-running
mkdir -p /var/lib/crowdsec
touch "$MARKER_FILE"

echo "CrowdSec initialized successfully."
