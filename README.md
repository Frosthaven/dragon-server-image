# 🐲 dragon-server

## THIS IS A WORK IN PROGRESS PROJECT AND IS NOT YET READY FOR PRODUCTION USE

`dragon-server` is a long-lived web server with a few key features:

- Autodiscovery of labeled docker containers
- Automatic SSL certificate generation and renewal
- Automatic DNS configuration support for
  - Cloudflare,
  - Amazon Route53,
  - DigitalOcean

## Use Case

This server is designed to be long-lived and low maintenance. It is ideal for
containerized projects that do not require horizontal scaling consideration. For
projects that do require horizontal scaling, container orchestration tools
like Kubernetes are recommended.

## Included Software

- [Caddy](https://caddyserver.com/)
  - [caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare)
  - [caddy-dns/route53](https://github.com/caddy-dns/route53)
  - [caddy-dns/digitalocean](https://github.com/caddy-dns/digitalocean)
  - [caddyserver/transform-encoder](https://github.com/caddyserver/transform-encoder)
  - [lucaslorentz/caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy/plugin/v2)
- [CrowdSec](https://www.crowdsec.net/) - Security engine with crowd-sourced threat intelligence
  - [crowdsec-firewall-bouncer](https://docs.crowdsec.net/u/bouncers/firewall/) - Firewall-level IP blocking
  - [crowdsecurity/linux](https://hub.crowdsec.net/author/crowdsecurity/collections/linux) - Linux system protection
  - [crowdsecurity/sshd](https://hub.crowdsec.net/author/crowdsecurity/collections/sshd) - SSH brute force protection
  - [crowdsecurity/caddy](https://hub.crowdsec.net/author/crowdsecurity/collections/caddy) - Caddy log analysis and HTTP attack detection
- [Docker](https://www.docker.com/)

## Documentation

- [Building the Image](README_BUILDING.md)
- [Usage](README_USAGE.md)

---


## Planned

- [x] Harden server with [CrowdSec](https://www.crowdsec.net/)
- [x] Default error pages for static server
- [x] Create first-boot experience to collect domain and email for caddy
- [x] Add caddy configs for automatic dns (comment out by default)
- [x] [Disable root login](https://www.digitalocean.com/community/tutorials/how-to-disable-root-login-on-ubuntu-20-04)
    - [x] Ensure we copy the ssh key to the new user on first boot
- [x] Issue with storage config permissions in Caddyfile
- [ ] Look into Podman auto-discovery progress for Caddy
    - [x] Podman is supported via Docker-compatible API socket (requires `CADDY_DOCKER_NO_SCOPE=true`)
    - [ ] [#707](https://github.com/lucaslorentz/caddy-docker-proxy/issues/707) - Caddyfile regenerates every polling interval (affects multi-network containers, breaks websockets)
    - [ ] [#703](https://github.com/lucaslorentz/caddy-docker-proxy/issues/703) - Same config/domain errors with Podman
    - [ ] No official Podman documentation in caddy-docker-proxy README
