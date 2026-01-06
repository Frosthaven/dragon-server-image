#!/bin/bash

# CrowdSec first-boot initialization
# Registers bouncer and starts services
# This script runs once on first boot to generate a unique bouncer API key
#
# Manual cleanup for existing servers (if needed):
#   sudo cscli bouncers list
#   sudo cscli bouncers delete <stale-bouncer-name>

set -e

BOUNCER_NAME="dragon-server-firewall-bouncer"
BOUNCER_CONFIG="/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml"
MARKER_FILE="/var/lib/crowdsec/.first-boot-complete"

# Exit if already fully initialized
if [ -f "$MARKER_FILE" ]; then
    echo "CrowdSec already initialized."
    exit 0
fi

echo "Initializing CrowdSec security engine..."

# Step 1: Start CrowdSec engine
if ! systemctl is-active --quiet crowdsec; then
    systemctl start crowdsec
fi

# Wait for CrowdSec LAPI to be ready (up to 120 seconds)
echo -n "Waiting for CrowdSec Local API..."
LAPI_READY=false
for i in {1..60}; do
    if cscli lapi status >/dev/null 2>&1; then
        echo ""
        echo "CrowdSec Local API is online."
        LAPI_READY=true
        break
    fi
    echo -n "."
    sleep 2
done

if [ "$LAPI_READY" = false ]; then
    echo ""
    echo "Error: CrowdSec LAPI not responding after 120 seconds."
    echo "Please check 'systemctl status crowdsec' and try again."
    exit 1
fi

# Step 2: Clean up any stale bouncer registrations
echo "Cleaning up any stale bouncer registrations..."

# Delete our target bouncer name if it exists
cscli bouncers delete "$BOUNCER_NAME" 2>/dev/null || true

# Delete any cs-firewall-bouncer-* registrations (from package installs)
for bouncer in $(cscli bouncers list -o raw 2>/dev/null | awk '/cs-firewall-bouncer/ {print $1}'); do
    cscli bouncers delete "$bouncer" 2>/dev/null || true
done

# Delete the old hardcoded name from previous script versions
cscli bouncers delete "crowdsec-firewall-bouncer-iptables" 2>/dev/null || true

# Step 3: Register bouncer with fresh API key
echo "Registering firewall bouncer as: $BOUNCER_NAME"
API_KEY=$(cscli bouncers add "$BOUNCER_NAME" -o raw)

if [ -z "$API_KEY" ]; then
    echo "Error: Failed to generate bouncer API key."
    exit 1
fi

# Update bouncer config with new API key
sed -i "s|^api_key:.*|api_key: $API_KEY|" "$BOUNCER_CONFIG"

# Save bouncer ID for package upgrade compatibility
echo "$BOUNCER_NAME" > "$BOUNCER_CONFIG.id"

echo "Bouncer registered successfully."

# Step 4: Start the firewall bouncer
echo "Starting firewall bouncer..."
systemctl start crowdsec-firewall-bouncer

# Verify bouncer is running
if systemctl is-active --quiet crowdsec-firewall-bouncer; then
    echo "Firewall bouncer is running."
else
    echo "Warning: Firewall bouncer failed to start. Check 'systemctl status crowdsec-firewall-bouncer'"
fi

# Create marker file to prevent re-running
mkdir -p /var/lib/crowdsec
touch "$MARKER_FILE"

echo "CrowdSec initialized successfully."
