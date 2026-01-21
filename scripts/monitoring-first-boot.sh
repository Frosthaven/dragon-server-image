#!/bin/bash

# Monitoring stack first-boot initialization
# Deploys VictoriaMetrics + Grafana with generated credentials
# This script runs once on first boot to configure the monitoring dashboard
#
# Manual cleanup (if needed):
#   cd /var/www/containers/monitoring && docker compose down -v
#   sudo rm /var/lib/dragon/.monitoring-configured

set -e

MONITORING_DIR="/var/www/containers/monitoring"
ENV_FILE="$MONITORING_DIR/.env"
CREDENTIALS_FILE="$MONITORING_DIR/.credentials"
MARKER_FILE="/var/lib/dragon/.monitoring-configured"

# Exit if already initialized
if [ -f "$MARKER_FILE" ]; then
    echo "Monitoring stack already configured."
    exit 0
fi

# Check if domain is configured
if [ ! -f "/var/lib/dragon/.domain" ]; then
    echo "Error: Domain not configured. Please complete Step 1 first."
    exit 1
fi

DOMAIN=$(cat /var/lib/dragon/.domain)

echo "Configuring monitoring stack (VictoriaMetrics + Grafana)..."

# Generate secure random passwords
GRAFANA_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)
METRICS_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)

# Generate bcrypt hash for Caddy basic auth (requires caddy binary)
METRICS_PASSWORD_HASH=$(caddy hash-password --plaintext "$METRICS_PASSWORD" 2>/dev/null || echo "")

if [ -z "$METRICS_PASSWORD_HASH" ]; then
    echo "Error: Failed to generate password hash. Is Caddy installed?"
    exit 1
fi

# Create .env file from template
if [ -f "$MONITORING_DIR/.env.template" ]; then
    cp "$MONITORING_DIR/.env.template" "$ENV_FILE"
else
    echo "Error: .env.template not found in $MONITORING_DIR"
    exit 1
fi

# Replace placeholders in .env
sed -i "s|__DOMAIN__|$DOMAIN|g" "$ENV_FILE"
sed -i "s|__GRAFANA_PASSWORD__|$GRAFANA_PASSWORD|g" "$ENV_FILE"
sed -i "s|__METRICS_PASSWORD__|$METRICS_PASSWORD|g" "$ENV_FILE"
sed -i "s|__METRICS_PASSWORD_HASH__|$METRICS_PASSWORD_HASH|g" "$ENV_FILE"

# Save credentials for user reference
cat > "$CREDENTIALS_FILE" << EOF
# Dragon Server Monitoring Credentials
# Generated: $(date)
# Keep this file secure!

Grafana Dashboard:
  URL: https://grafana.$DOMAIN
  Username: admin
  Password: $GRAFANA_PASSWORD

Metrics Endpoint (for external scrapers):
  URL: https://metrics.$DOMAIN
  Username: metrics
  Password: $METRICS_PASSWORD

DNS Requirements:
  Create CNAME records pointing to your domain:
    grafana.$DOMAIN -> $DOMAIN
    metrics.$DOMAIN -> $DOMAIN
EOF

chmod 600 "$CREDENTIALS_FILE"
chmod 600 "$ENV_FILE"

# Start the monitoring stack
echo "Starting monitoring containers..."
cd "$MONITORING_DIR"
docker compose up -d

# Wait for containers to be ready
echo -n "Waiting for services to start..."
for i in {1..30}; do
    if docker compose ps 2>/dev/null | grep -q "running" && \
       curl -s http://localhost:8428/health >/dev/null 2>&1; then
        echo ""
        echo "Monitoring services are online."
        break
    fi
    echo -n "."
    sleep 2
done

# Verify services
echo ""
echo "Checking service status..."

if docker ps --format '{{.Names}}' | grep -q "victoriametrics"; then
    echo "  VictoriaMetrics: running"
else
    echo "  VictoriaMetrics: not running (check 'docker logs victoriametrics')"
fi

if docker ps --format '{{.Names}}' | grep -q "grafana"; then
    echo "  Grafana: running"
else
    echo "  Grafana: not running (check 'docker logs grafana')"
fi

# Create marker file
mkdir -p /var/lib/dragon
touch "$MARKER_FILE"

echo ""
echo "Monitoring stack configured successfully!"
echo ""
echo "DNS Requirements:"
echo "  Create CNAME records pointing to your domain:"
echo "    grafana.$DOMAIN -> $DOMAIN"
echo "    metrics.$DOMAIN -> $DOMAIN"
echo ""
echo "Your credentials have been saved to:"
echo "  $CREDENTIALS_FILE"
echo ""
echo "Run 'dragon-show-credentials' to view them anytime."
