#!/bin/bash

# CrowdSec first-boot initialization
# Registers bouncer and starts services
# This script is run once on first boot to generate a unique bouncer API key per instance

set -e

MARKER_DIR="/var/lib/dragon"
MARKER_CROWDSEC_STARTED="$MARKER_DIR/.crowdsec-started"
MARKER_BOUNCER_REGISTERED="$MARKER_DIR/.bouncer-registered"
MARKER_FIRST_BOOT_COMPLETE="/var/lib/crowdsec/.first-boot-complete"

mkdir -p "$MARKER_DIR"

# Exit if already fully initialized
if [ -f "$MARKER_FIRST_BOOT_COMPLETE" ]; then
    echo "CrowdSec already initialized."
    exit 0
fi

# Step 1: Start CrowdSec engine
if [ ! -f "$MARKER_CROWDSEC_STARTED" ]; then
    systemctl start crowdsec

    # Wait for CrowdSec service to be fully active (up to 60 seconds)
    echo "Waiting for CrowdSec service..."
    for i in {1..30}; do
        if systemctl is-active --quiet crowdsec; then
            # Service is active, now wait a moment for LAPI to initialize
            sleep 2
            if cscli lapi status 2>&1 | grep -qi "online\|url"; then
                echo "CrowdSec Local API is online."
                touch "$MARKER_CROWDSEC_STARTED"
                break
            fi
        fi
        if [ $i -eq 30 ]; then
            echo "Warning: Timed out waiting for CrowdSec LAPI. Continuing anyway..."
            touch "$MARKER_CROWDSEC_STARTED"
        fi
        sleep 2
    done
else
    # Ensure CrowdSec is running even if marker exists
    if ! systemctl is-active --quiet crowdsec; then
        systemctl start crowdsec
        sleep 3
    fi
    echo "CrowdSec engine already started."
fi

# Step 2: Register bouncer with fresh API key
if [ ! -f "$MARKER_BOUNCER_REGISTERED" ]; then
    # Delete existing bouncer registration (from image build) and re-register
    # This ensures each instance gets a unique API key
    cscli bouncers delete crowdsec-firewall-bouncer-iptables 2>/dev/null || true

    # Register bouncer with fresh API key
    echo "Registering firewall bouncer..."
    API_KEY=$(cscli bouncers add crowdsec-firewall-bouncer-iptables -o raw)

    if [ -z "$API_KEY" ]; then
        echo "Error: Failed to generate bouncer API key."
        exit 1
    fi

    # Update bouncer config with new API key (use | as delimiter since API key may contain /)
    sed -i "s|^api_key:.*|api_key: $API_KEY|" /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
    
    touch "$MARKER_BOUNCER_REGISTERED"
else
    echo "Firewall bouncer already registered."
fi

# Step 3: Start the firewall bouncer
if ! systemctl is-active --quiet crowdsec-firewall-bouncer; then
    echo "Starting firewall bouncer..."
    systemctl start crowdsec-firewall-bouncer
else
    echo "Firewall bouncer already running."
fi

# Create final marker file to prevent re-running
mkdir -p /var/lib/crowdsec
touch "$MARKER_FIRST_BOOT_COMPLETE"

echo "CrowdSec initialized successfully."
