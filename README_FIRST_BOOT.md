# dragon-server

[Back to README](README.md)

## First Time Boot

When you first SSH into your new server, you'll be guided through an
interactive setup process. Here's what to expect:

### Step 1: Domain Configuration

```
Welcome to your dragon-server instance! Please complete the following steps to get started.

Enter the base domain name (e.g. example.com):
```

Enter your root domain (e.g., `example.com`). This will be used to configure
Caddy and the example containers.

### Step 2: Administrator Email

```
Enter the server administrator email address:
```

Enter your email address. This is used for SSL certificate notifications from
Let's Encrypt.

### Step 3: DNS Records

```
Add the following DNS records to your domain registrar:

Domain Name          Type   Value
example.com          A      123.45.67.89
whoami.example.com   CNAME  example.com
static.example.com   CNAME  example.com

Press Enter when done...
```

The setup will display the DNS records you need to create. Add these to your
DNS provider (Cloudflare, Route53, DigitalOcean, etc.) before continuing.

### Step 4: Dragon User Setup

```
------------------------------------------------------------
Dragon User Setup
------------------------------------------------------------

Copying SSH keys to dragon user...
SSH keys copied successfully.

You can now SSH into this server as: ssh dragon@123.45.67.89

Root SSH login will be disabled for security.

WARNING: Cloud provider recovery consoles require a password to log in.
If you do not set a password for the 'dragon' user, you will lose access
to the recovery console. This console is only needed if SSH becomes
completely unavailable (e.g., firewall misconfiguration, SSH daemon crash).

Normal SSH access will continue to work with your SSH key regardless of
whether you set a password.

Set a password for 'dragon' user for recovery console access? (y/N):
```

This step:
1. Copies your SSH keys from `root` to the `dragon` user
2. Optionally sets a password for recovery console access (recommended)
3. Disables root SSH login for security

**About the recovery console password:**
- Cloud providers offer browser-based recovery consoles for emergencies
- They require a password (SSH keys don't work there)
- You only need it if SSH becomes completely unavailable
- If you skip this, you can set a password later with `sudo passwd dragon`

### Step 5: CrowdSec Security Setup

```
Initializing CrowdSec security engine...
CrowdSec Local API is online.
Registering firewall bouncer...
Starting firewall bouncer...
CrowdSec initialized successfully.

CrowdSec is now protecting your server with:
  - SSH brute force protection
  - HTTP/Caddy attack detection
  - Crowd-sourced threat intelligence

Would you like to enroll in the CrowdSec Console?
The console provides a web dashboard to monitor your server's security.
(You can always do this later - see README_USAGE.md for instructions)

Enroll in CrowdSec Console? (y/N):
```

You have two options:

**Option A: Skip enrollment (press Enter or type `n`)**

CrowdSec will still protect your server, but you won't have access to the web
dashboard. You can enroll later at any time (see [Console Enrollment](README_USAGE.md#console-enrollment-optional)).

**Option B: Enroll now (type `y`)**

If you choose to enroll, you'll see:

```
To get your enrollment key:
  1. Sign up at https://app.crowdsec.net/signup
  2. Go to Security Engines page
  3. Copy the enrollment key from the command shown

Paste your enrollment key or the full enrollment command:
```

Paste your enrollment key (or the full command) and press Enter. After successful enrollment:

```
Enrollment request sent!

Next steps:
  1. Go to https://app.crowdsec.net
  2. Accept the enrollment request for this engine
  3. Run: sudo systemctl restart crowdsec

Press Enter to continue...
```

### Step 6: Setup Complete

```
Configuration complete! You can test your server at https://whoami.example.com
```

You'll then see the welcome screen with your server status, including CrowdSec
security status and any running containers.

## What's Next?

After completing first boot setup:

- [Usage Guide](README_USAGE.md) - Learn how to manage Caddy, Docker containers, and CrowdSec
- Test your setup by visiting `https://whoami.yourdomain.com`
- SSH in using `ssh dragon@your-server-ip` (root login is now disabled)
