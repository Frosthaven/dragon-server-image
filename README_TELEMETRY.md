# Dragon Server Telemetry & Monitoring

This guide covers the monitoring and telemetry capabilities built into Dragon Server images. You can use these features in three modes:

1. **Dashboard Mode** - Run VictoriaMetrics + Grafana to receive and visualize metrics
2. **Exporter Mode** - Collect and send metrics from a Dragon Server to a central dashboard
3. **External Exporter Mode** - Collect and send metrics from any Linux server to a Dragon Server dashboard

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Setting Up a Monitoring Dashboard](#setting-up-a-monitoring-dashboard)
- [Setting Up a Telemetry Exporter Node](#setting-up-a-telemetry-exporter-node)
- [Setting Up Any Server to Report to Dragon Server](#setting-up-any-server-to-report-to-dragon-server)
- [Available Dashboards](#available-dashboards)
- [Credentials Management](#credentials-management)
- [Manual Configuration](#manual-configuration)
- [Troubleshooting](#troubleshooting)

---

## Overview

Dragon Server includes:

- **Grafana Alloy** - A metrics collection agent that scrapes metrics from various sources
- **VictoriaMetrics** - A Prometheus-compatible time-series database (optional, for dashboard servers)
- **Grafana** - Visualization and dashboards (optional, for dashboard servers)

### What Gets Collected

Alloy collects metrics from:

| Source | Metrics |
|--------|---------|
| **Node/System** | CPU, memory, disk, network, load averages |
| **Docker** | Container CPU, memory, network, I/O via cAdvisor |
| **Caddy** | HTTP requests, response times, active connections |
| **CrowdSec** | Blocked IPs, parsed logs, active decisions |

---

## Architecture

### Single Server (Default Setup)

```
┌─────────────────────────────────────────────────────┐
│                   Dragon Server                      │
│                                                      │
│  ┌─────────┐    ┌────────────────┐    ┌──────────┐ │
│  │  Alloy  │───>│ VictoriaMetrics│<───│ Grafana  │ │
│  └─────────┘    └────────────────┘    └──────────┘ │
│       │                                      │       │
│       v                                      v       │
│  [Node, Docker,                      https://grafana │
│   Caddy, CrowdSec]                    .yourdomain.com│
└─────────────────────────────────────────────────────┘
```

### Multi-Server (Central Dashboard)

```
┌──────────────────────┐      ┌──────────────────────┐
│   Exporter Node 1    │      │   Exporter Node 2    │
│   (Dragon Server)    │      │   (Dragon Server)    │
│  ┌─────────┐         │      │  ┌─────────┐         │
│  │  Alloy  │─────────┼──────┼──│  Alloy  │─────────┼──┐
│  └─────────┘         │      │  └─────────┘         │  │
└──────────────────────┘      └──────────────────────┘  │
                                                        │
                              ┌─────────────────────────▼─┐
                              │     Dashboard Server       │
                              │     (Dragon Server)        │
                              │  ┌────────────────┐        │
                              │  │ VictoriaMetrics│<──────┐│
                              │  └────────────────┘       ││
                              │         │                 ││
                              │  ┌──────▼──────┐          ││
                              │  │   Grafana   │          ││
                              │  └─────────────┘          ││
                              │                           ││
                              │  https://metrics.domain───┘│
                              │  (basic auth protected)    │
                              └────────────────────────────┘
```

### Heterogeneous Environment (Mixed Servers)

```
┌──────────────────────┐      ┌──────────────────────┐
│   External Server 1  │      │   External Server 2  │
│   (Ubuntu/Debian)    │      │   (RHEL/CentOS)      │
│  ┌─────────┐         │      │  ┌─────────┐         │
│  │  Alloy  │─────────┼──┐   │  │  Alloy  │─────────┼──┐
│  └─────────┘         │  │   │  └─────────┘         │  │
└──────────────────────┘  │   └──────────────────────┘  │
                          │                             │
┌──────────────────────┐  │   ┌─────────────────────────▼─┐
│   Dragon Server      │  │   │     Dashboard Server       │
│   (Exporter Node)    │  │   │     (Dragon Server)        │
│  ┌─────────┐         │  │   │                            │
│  │  Alloy  │─────────┼──┼───│─> VictoriaMetrics          │
│  └─────────┘         │  │   │         │                  │
└──────────────────────┘  │   │   ┌─────▼─────┐            │
                          └───┼──>│  Grafana  │            │
                              │   └───────────┘            │
                              │                            │
                              │   https://grafana.domain   │
                              └────────────────────────────┘
```

---

## Setting Up a Monitoring Dashboard

A **Dashboard Server** runs VictoriaMetrics and Grafana to collect and visualize metrics. This is configured automatically during first boot.

### During First Boot

When you first log in to a new Dragon Server, the setup wizard will ask:

```
Set up monitoring dashboard? (Y/n):
```

Choose **Y** to:
1. Generate secure credentials for Grafana and the metrics endpoint
2. Start VictoriaMetrics and Grafana containers
3. Configure Caddy to proxy `grafana.yourdomain.com` and `metrics.yourdomain.com`

### After Setup

Your dashboard will be available at:
- **Grafana**: `https://grafana.yourdomain.com`
- **Metrics Endpoint**: `https://metrics.yourdomain.com` (basic auth protected)

Credentials are saved and can be viewed anytime:

```bash
dragon-show-credentials
```

### DNS Records

Add these DNS records for your monitoring subdomains:

| Name | Type | Value |
|------|------|-------|
| `grafana.yourdomain.com` | CNAME | `yourdomain.com` |
| `metrics.yourdomain.com` | CNAME | `yourdomain.com` |

---

## Setting Up a Telemetry Exporter Node

An **Exporter Node** only runs Alloy to collect and send metrics to a central dashboard server. Use this for additional servers you want to monitor.

### Option 1: Send to Local VictoriaMetrics (Default)

By default, Alloy sends metrics to `localhost:8428`. If you enabled the monitoring dashboard, metrics flow automatically.

### Option 2: Send to Remote Dashboard Server

To send metrics to a central dashboard server, edit the Alloy configuration:

```bash
sudo nano /etc/alloy/config.alloy
```

Find the `prometheus.remote_write` section and update it:

```hcl
prometheus.remote_write "victoriametrics" {
  endpoint {
    url = "https://metrics.your-dashboard-server.com/api/v1/write"
    
    basic_auth {
      username = "metrics"
      password = "YOUR_METRICS_PASSWORD"
    }
  }

  external_labels = {
    instance = "exporter-node-hostname",
  }
}
```

Then restart Alloy:

```bash
sudo systemctl restart alloy
```

### Option 3: Skip Dashboard, Only Export

During first boot, you can:
1. Say **N** to "Set up monitoring dashboard?"
2. Say **Y** to "Enable metrics collection?"

This will only enable Alloy without VictoriaMetrics/Grafana. Then configure Alloy to send to your remote dashboard as shown above.

### Disabling Local Monitoring Stack

If you set up the monitoring stack but later want to disable it:

```bash
cd /var/www/containers/monitoring
docker compose down

# Optionally remove data
docker compose down -v
```

---

## Setting Up Any Server to Report to Dragon Server

This section covers installing Grafana Alloy on **any Linux server** (Ubuntu, Debian, RHEL, etc.) to send metrics to a Dragon Server monitoring dashboard. This is useful for:

- Non-Dragon servers in your infrastructure
- Existing servers you want to add to your monitoring
- Development machines or VMs
- Cloud instances from any provider

### Prerequisites

- A Dragon Server with the monitoring dashboard enabled (your "receiving" server)
- The metrics endpoint URL and credentials from `dragon-show-credentials`
- Root/sudo access on the server you want to monitor

### Step 1: Install Grafana Alloy

**Ubuntu/Debian:**

```bash
# Add Grafana GPG key and repository
sudo apt-get install -y apt-transport-https software-properties-common
sudo mkdir -p /etc/apt/keyrings/
curl -fsSL https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# Install Alloy
sudo apt-get update
sudo apt-get install -y alloy
```

**RHEL/CentOS/Fedora:**

```bash
# Add Grafana repository
cat <<EOF | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# Install Alloy
sudo dnf install -y alloy
```

**Binary Install (any Linux):**

```bash
# Download latest release
curl -LO https://github.com/grafana/alloy/releases/latest/download/alloy-linux-amd64.zip
unzip alloy-linux-amd64.zip
sudo mv alloy-linux-amd64 /usr/local/bin/alloy
sudo chmod +x /usr/local/bin/alloy
```

### Step 2: Configure Alloy

Create the Alloy configuration file:

```bash
sudo mkdir -p /etc/alloy
sudo nano /etc/alloy/config.alloy
```

Use this configuration template (adjust as needed for your server):

```hcl
// =============================================================================
// PROMETHEUS EXPORTERS
// =============================================================================

// Node Exporter - System metrics (CPU, memory, disk, network, etc.)
prometheus.exporter.unix "node" {
  set_collectors = [
    "cpu",
    "diskstats",
    "filesystem",
    "loadavg",
    "meminfo",
    "netdev",
    "netstat",
    "stat",
    "time",
    "uname",
    "vmstat",
  ]
}

// =============================================================================
// SCRAPE CONFIGURATIONS
// =============================================================================

// Scrape node metrics from unix exporter
prometheus.scrape "node" {
  targets         = prometheus.exporter.unix.node.targets
  forward_to      = [prometheus.relabel.instance.receiver]
  scrape_interval = "15s"
  job_name        = "node"
}

// Relabel to set consistent instance name
// (external_labels don't override scrape-derived instance labels)
prometheus.relabel "instance" {
  forward_to = [prometheus.remote_write.dragon_server.receiver]

  rule {
    target_label = "instance"
    replacement  = "YOUR_SERVER_HOSTNAME"
  }
}

// =============================================================================
// REMOTE WRITE TO DRAGON SERVER
// =============================================================================

prometheus.remote_write "dragon_server" {
  endpoint {
    url = "https://metrics.YOUR_DRAGON_SERVER_DOMAIN/api/v1/write"

    basic_auth {
      username = "YOUR_METRICS_USERNAME"
      password = "YOUR_METRICS_PASSWORD"
    }
  }
}
```

**Replace these placeholders:**
- `YOUR_DRAGON_SERVER_DOMAIN` - Your Dragon Server's domain (e.g., `thedragon.dev`)
- `YOUR_METRICS_USERNAME` - The metrics username from `dragon-show-credentials`
- `YOUR_METRICS_PASSWORD` - The metrics password from `dragon-show-credentials`
- `YOUR_SERVER_HOSTNAME` - A unique identifier for this server (e.g., `web-server-01`)

### Step 3: Optional - Add Docker Metrics

If Docker is installed, add cAdvisor metrics collection:

```hcl
// Docker container metrics (add after prometheus.exporter.unix)
prometheus.exporter.cadvisor "containers" {
  docker_host = "unix:///var/run/docker.sock"
  storage_duration = "5m"
}

// Scrape container metrics (add after prometheus.scrape "node")
prometheus.scrape "cadvisor" {
  targets    = prometheus.exporter.cadvisor.containers.targets
  forward_to = [prometheus.remote_write.dragon_server.receiver]
  
  scrape_interval = "15s"
  job_name        = "cadvisor"
}
```

**Important:** For cAdvisor to work, Alloy must run as root. Create a systemd override:

```bash
sudo mkdir -p /etc/systemd/system/alloy.service.d
cat <<EOF | sudo tee /etc/systemd/system/alloy.service.d/override.conf
[Service]
User=root
Group=root
EOF
sudo systemctl daemon-reload
```

### Step 4: Optional - Add Application Metrics

If your applications expose Prometheus metrics, add scrape targets:

```hcl
// Example: Scrape a Node.js app on port 9090
prometheus.scrape "my_app" {
  targets = [
    {"__address__" = "localhost:9090"},
  ]
  forward_to = [prometheus.remote_write.dragon_server.receiver]
  
  scrape_interval = "15s"
  job_name        = "my_app"
  metrics_path    = "/metrics"
}

// Example: Scrape nginx with nginx-prometheus-exporter
prometheus.scrape "nginx" {
  targets = [
    {"__address__" = "localhost:9113"},
  ]
  forward_to = [prometheus.remote_write.dragon_server.receiver]
  
  scrape_interval = "15s"
  job_name        = "nginx"
}

// Example: Scrape PostgreSQL with postgres_exporter
prometheus.scrape "postgres" {
  targets = [
    {"__address__" = "localhost:9187"},
  ]
  forward_to = [prometheus.remote_write.dragon_server.receiver]
  
  scrape_interval = "15s"
  job_name        = "postgres"
}
```

### Step 5: Start Alloy

```bash
# Enable and start the service
sudo systemctl enable alloy
sudo systemctl start alloy

# Check status
sudo systemctl status alloy

# View logs
sudo journalctl -u alloy -f
```

### Step 6: Verify Metrics

On your Dragon Server, verify metrics are arriving:

```bash
# Check for the new instance
curl -s 'http://localhost:8428/api/v1/label/instance/values'

# Query a metric from the new server
curl -s 'http://localhost:8428/api/v1/query?query=up{instance="YOUR_SERVER_HOSTNAME"}'
```

In Grafana, you should see the new server appear in dashboard dropdowns.

### Complete Example Configuration

Here's a full configuration for a typical web server with Docker and nginx:

```hcl
// =============================================================================
// Grafana Alloy Configuration
// Server: web-server-01
// Reports to: metrics.thedragon.dev
// =============================================================================

// --- System Metrics ---
prometheus.exporter.unix "node" {
  set_collectors = [
    "cpu", "diskstats", "filesystem", "loadavg",
    "meminfo", "netdev", "netstat", "stat",
    "time", "uname", "vmstat",
  ]
}

prometheus.scrape "node" {
  targets         = prometheus.exporter.unix.node.targets
  forward_to      = [prometheus.relabel.instance.receiver]
  scrape_interval = "15s"
  job_name        = "node"
}

// --- Docker Metrics ---
prometheus.exporter.cadvisor "containers" {
  docker_host = "unix:///var/run/docker.sock"
  storage_duration = "5m"
}

prometheus.scrape "cadvisor" {
  targets         = prometheus.exporter.cadvisor.containers.targets
  forward_to      = [prometheus.relabel.instance.receiver]
  scrape_interval = "15s"
  job_name        = "cadvisor"
}

// --- Nginx Metrics (requires nginx-prometheus-exporter) ---
prometheus.scrape "nginx" {
  targets         = [{"__address__" = "localhost:9113"}]
  forward_to      = [prometheus.relabel.instance.receiver]
  scrape_interval = "15s"
  job_name        = "nginx"
}

// --- Relabel to set consistent instance name ---
// (external_labels don't override scrape-derived instance labels)
prometheus.relabel "instance" {
  forward_to = [prometheus.remote_write.dragon_server.receiver]

  rule {
    target_label = "instance"
    replacement  = "web-server-01"
  }
}

// --- Remote Write ---
prometheus.remote_write "dragon_server" {
  endpoint {
    url = "https://metrics.thedragon.dev/api/v1/write"
    basic_auth {
      username = "your-metrics-username"
      password = "your-metrics-password"
    }
  }
}
```

### Firewall Considerations

Alloy only needs **outbound** HTTPS access to your Dragon Server. No inbound ports need to be opened.

If your server has strict egress rules, allow:
- **Port 443** to your Dragon Server's IP or domain

### Updating Alloy

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get upgrade alloy

# RHEL/CentOS/Fedora
sudo dnf upgrade alloy

# Restart after upgrade
sudo systemctl restart alloy
```

---

## Available Dashboards

The following dashboards are pre-installed in Grafana:

| Dashboard | Description |
|-----------|-------------|
| **Dragon Server Glance** | Quick overview of all nodes: system health, security, containers |
| **Node Exporter Full** | Detailed system metrics (CPU, memory, disk, network) |
| **Docker Containers** | Container resource usage via cAdvisor |
| **CrowdSec Overview** | Security overview and blocked threats |
| **CrowdSec Insight** | Detailed threat analysis |
| **CrowdSec Details** | Per-machine security details |
| **CrowdSec LAPI** | Local API metrics |

### Dragon Server Glance

The **Dragon Server Glance** dashboard provides a quick at-a-glance view of all reporting nodes. It includes:

- **Node Health Table**: Instance, Uptime, CPU %, Memory %, Disk %, Load 1m, Container count
- **Security Status Table**: Active Bans, Alerts (24h), Attacks Blocked (24h), Logs Parsed (24h)
- **Resource Trends**: CPU & Memory graphs, Network Traffic graphs
- **Docker Containers**: Container CPU/Memory graphs, detailed container table

Use the **Instance** dropdown at the top to filter by specific nodes or select "All" to view everything.

This is the recommended starting dashboard for monitoring your infrastructure.

### Adding Custom Dashboards

You can import additional dashboards from [Grafana Dashboards](https://grafana.com/grafana/dashboards/):

1. In Grafana, go to **Dashboards > Import**
2. Enter a dashboard ID or paste JSON
3. Select **VictoriaMetrics** as the data source

---

## Credentials Management

### Viewing Credentials

```bash
dragon-show-credentials
```

### Credential Locations

| Credential | Location |
|------------|----------|
| Grafana admin password | `/var/www/containers/monitoring/.credentials` |
| Metrics endpoint auth | `/var/www/containers/monitoring/.credentials` |
| Environment variables | `/var/www/containers/monitoring/.env` |

### Changing Passwords

**Grafana Admin Password:**

```bash
# Via Grafana CLI inside container
docker exec -it grafana grafana-cli admin reset-admin-password NEW_PASSWORD

# Also update the .env file for container restarts
nano /var/www/containers/monitoring/.env
```

**Metrics Endpoint Password:**

```bash
# Generate new bcrypt hash
caddy hash-password --plaintext 'NEW_PASSWORD'

# Update the .env file with new password and hash
nano /var/www/containers/monitoring/.env

# Restart to apply
cd /var/www/containers/monitoring && docker compose up -d
```

---

## Manual Configuration

### Running First-Boot Scripts Manually

If you skipped setup during first boot, you can run the scripts manually:

```bash
# Set up VictoriaMetrics + Grafana
sudo /usr/local/bin/monitoring-first-boot.sh

# Enable Alloy metrics collection
sudo /usr/local/bin/alloy-first-boot.sh
```

### Alloy Configuration

The Alloy configuration is located at `/etc/alloy/config.alloy`. Key sections:

```hcl
// Node/system metrics
prometheus.exporter.unix "node" { ... }

// Docker container metrics
prometheus.exporter.cadvisor "containers" { ... }

// Caddy web server metrics
prometheus.scrape "caddy" {
  targets = [{"__address__" = "localhost:2019"}]
  ...
}

// CrowdSec security metrics
prometheus.scrape "crowdsec" {
  targets = [{"__address__" = "localhost:6060"}]
  ...
}

// Where to send metrics
prometheus.remote_write "victoriametrics" {
  endpoint {
    url = "http://localhost:8428/api/v1/write"
  }
  ...
}
```

### Adding New Scrape Targets

To scrape metrics from additional services, add a new `prometheus.scrape` block:

```hcl
prometheus.scrape "my_app" {
  targets = [
    {"__address__" = "localhost:9090"},
  ]
  forward_to = [prometheus.remote_write.victoriametrics.receiver]
  
  scrape_interval = "15s"
  job_name        = "my_app"
  metrics_path    = "/metrics"
}
```

Then restart Alloy:

```bash
sudo systemctl restart alloy
```

---

## Troubleshooting

### Check Alloy Status

```bash
sudo systemctl status alloy
sudo journalctl -u alloy -f
```

### Check VictoriaMetrics

```bash
# Container status
docker ps | grep victoriametrics

# Verify metrics are being received
curl -s 'http://localhost:8428/api/v1/label/job/values'

# Check specific metric
curl -s 'http://localhost:8428/api/v1/query?query=up'
```

### Check Grafana

```bash
docker ps | grep grafana
docker logs grafana
```

### Common Issues

**Alloy fails to start:**
- Check that Docker is running: `sudo systemctl status docker`
- Verify config syntax: `alloy fmt /etc/alloy/config.alloy`

**No container metrics:**
- Alloy needs root access for cAdvisor. Verify the systemd override exists:
  ```bash
  cat /etc/systemd/system/alloy.service.d/override.conf
  ```

**CrowdSec metrics missing:**
- Verify Prometheus is enabled in CrowdSec:
  ```bash
  grep -A4 "prometheus:" /etc/crowdsec/config.yaml
  ```
- Test the endpoint:
  ```bash
  curl http://localhost:6060/metrics
  ```

**Caddy metrics missing:**
- Caddy admin API should be on port 2019:
  ```bash
  curl http://localhost:2019/metrics
  ```

**Remote write failing:**
- Check network connectivity to the dashboard server
- Verify basic auth credentials are correct
- Check Alloy logs for specific errors

**SWAP shows N/A:**
- This is normal if no swap is configured on the server (check with `free -h`)

### Resetting Everything

To completely reset the monitoring setup:

```bash
# Stop and remove containers
cd /var/www/containers/monitoring && docker compose down -v

# Stop Alloy
sudo systemctl stop alloy

# Remove marker files
sudo rm -f /var/lib/dragon/.monitoring-configured
sudo rm -f /var/lib/dragon/.alloy-configured

# Re-run first boot on next login
```

---

## Security Considerations

1. **Metrics Endpoint**: Always protected with basic authentication
2. **Grafana**: Uses generated admin password, anonymous access disabled
3. **Internal Ports**: VictoriaMetrics (8428) only bound to localhost
4. **TLS**: All external access through Caddy with automatic HTTPS
5. **Credentials**: Stored with 600 permissions in `/var/www/containers/monitoring/`

For production environments, consider:
- Rotating passwords periodically
- Using Grafana's built-in user management for team access
- Setting up alerting for critical metrics
