# dragon-server

[Back to README](README.md)

## Usage

### SSH Login

You will need to provide an SSH key when spinning up server
instances based on this image, as password login is disabled by default.

On first boot, you'll log in as `root`. After completing the [first-time setup](README_FIRST_BOOT.md),
root SSH access is disabled and you'll use the `dragon` user instead:

```bash
# First boot only
ssh root@your-server-ip

# After first-time setup is complete
ssh dragon@your-server-ip
```

The `dragon` user has passwordless sudo access for administrative tasks.

### Caddy Server

[Caddy Documentation](https://caddyserver.com/docs)

1. Caddy is installed as a systemd service (`/etc/systemd/system/caddy.service`):
   - Start: `sudo systemctl start caddy`.
   - Enable (already enabled by default): `sudo systemctl enable caddy`.
   - Disable: `sudo systemctl disable caddy`.
   - Status: `sudo systemctl status caddy`.
   - Restart: `sudo systemctl restart caddy`.
   - Stop: `sudo systemctl stop caddy`.
2. Caddy configuration and storage is located in `/var/www/_caddy/`. Symbolic
   links have been added that point to the Caddy logs and systemd service file.
3. A static file server hosts from `/var/www/static` by default.

#### Error Pages

Custom error pages are included for 404 (Not Found) and 5xx (Server Error)
responses. These are located in `/var/www/static/errors/` and are automatically
used by the static file server.

**For Docker containers:** By default, containers handle their own error
responses. If a container is unreachable (stopped or crashed), Caddy will return
a 502 error. To use the custom error pages for your containers, add the
following label to your docker-compose:

```yaml
labels:
    caddy: example.com
    caddy.reverse_proxy: "{{upstreams 80}}"
    caddy.import: error_pages
```

The `error_pages` snippet handles:
- **404** - File/page not found
- **5xx** - Server errors (500, 502, 503, etc.)

**Customizing error pages:** Edit the HTML files in `/var/www/static/errors/`:
- `/var/www/static/errors/404.html`
- `/var/www/static/errors/500.html`

### Docker Container Configuration

[Docker Compose Documentation](https://docs.docker.com/compose/)

Docker compose files can be stored anywhere, but we use the convention of
storing them in `/var/www/containers/`.

In order to enable auto-discovery of running containers, you must add both
the caddy network and the caddy labels to your docker-compose files:

```yaml
services:
  your_service:
      # ...
      networks:
        - caddy
      labels:
          caddy: example.com # change to your domain
          caddy.reverse_proxy: "{{upstreams 80}}"
      # ...

networks:
  caddy:
    external: true
```

An example is located at `/var/www/containers/whoami/docker-compose.yml`. You
can learn more about `caddy-docker-proxy` labels [here](https://github.com/lucaslorentz/caddy-docker-proxy?tab=readme-ov-file#labels-to-caddyfile-conversion).

### CrowdSec Security

[CrowdSec Documentation](https://docs.crowdsec.net/)

CrowdSec is a security engine that detects and blocks malicious IPs using
behavioral analysis and crowd-sourced threat intelligence.

#### Service Management

CrowdSec runs as two systemd services:

1. **CrowdSec Engine** (`crowdsec`):
   - Start: `sudo systemctl start crowdsec`
   - Stop: `sudo systemctl stop crowdsec`
   - Status: `sudo systemctl status crowdsec`
   - Restart: `sudo systemctl restart crowdsec`

2. **Firewall Bouncer** (`crowdsec-firewall-bouncer`):
   - Start: `sudo systemctl start crowdsec-firewall-bouncer`
   - Stop: `sudo systemctl stop crowdsec-firewall-bouncer`
   - Status: `sudo systemctl status crowdsec-firewall-bouncer`
   - Restart: `sudo systemctl restart crowdsec-firewall-bouncer`

#### Useful Commands

```bash
# View current decisions (blocked IPs)
sudo cscli decisions list

# View alerts
sudo cscli alerts list

# View installed collections/scenarios
sudo cscli collections list
sudo cscli scenarios list

# Manually ban an IP (4 hour default)
sudo cscli decisions add --ip 1.2.3.4

# Manually unban an IP
sudo cscli decisions delete --ip 1.2.3.4

# View metrics
sudo cscli metrics
```

#### Console Enrollment (Optional)

The CrowdSec Console provides a free web dashboard to monitor your server's
security across multiple instances. You can enroll during [first-boot setup](README_FIRST_BOOT.md),
or manually at any time:

1. Sign up at [app.crowdsec.net](https://app.crowdsec.net/signup)
2. Navigate to the Security Engines page
3. Copy your enrollment key from the bottom of the page
4. Run the enrollment command on your server:
   ```bash
   sudo cscli console enroll <YOUR_ENROLLMENT_KEY>
   ```
5. Go back to the console and accept the enrollment request
6. Restart CrowdSec:
   ```bash
   sudo systemctl restart crowdsec
   ```

#### Configuration Files

| File | Purpose |
|------|---------|
| `/etc/crowdsec/config.yaml` | Main CrowdSec configuration |
| `/etc/crowdsec/acquis.d/` | Log acquisition configs (what logs to monitor) |
| `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml` | Firewall bouncer config |
| `/var/log/crowdsec.log` | CrowdSec engine logs |
| `/var/log/crowdsec-firewall-bouncer.log` | Firewall bouncer logs |

#### Whitelisting IPs

To prevent legitimate IPs from being blocked, add them to the whitelist:

```bash
# Create a whitelist file
sudo nano /etc/crowdsec/parsers/s02-enrich/my-whitelist.yaml
```

Add the following content:

```yaml
name: my-whitelist
description: "Whitelist for trusted IPs"
whitelist:
  reason: "Trusted IP addresses"
  ip:
    - "1.2.3.4"
    - "5.6.7.8"
  cidr:
    - "10.0.0.0/8"
```

Then restart CrowdSec:

```bash
sudo systemctl restart crowdsec
```
