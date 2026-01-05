#!/bin/bash

# this file gets placed into "/etc/profile.d" and runs on every login

# functions ********************************************************************
# ******************************************************************************

NORMAL=$'\e[0m'
YELLOW=$'\e[33m'
CYAN=$'\e[36m'
BLUE=$'\e[34m'
RED=$'\e[31m'
MAGENTA=$'\e[35m'
GREEN=$'\e[32m'

function showBanner() {
  echo "${GREEN}――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――${NORMAL}"
  echo "🐲 DRAGON SERVER: ${CYAN}https://github.com/frosthaven/dragon-server"
  echo "${GREEN}――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――${NORMAL}"
  echo ""
}

function showSecurityStatus() {
  echo "${GREEN}Security Status:${NORMAL}"
  
  # Check if CrowdSec is running
  if systemctl is-active --quiet crowdsec; then
    crowdsec_status="${GREEN}running${NORMAL}"
  else
    crowdsec_status="${RED}stopped${NORMAL}"
  fi
  
  # Check if firewall bouncer is running
  if systemctl is-active --quiet crowdsec-firewall-bouncer; then
    bouncer_status="${GREEN}running${NORMAL}"
  else
    bouncer_status="${RED}stopped${NORMAL}"
  fi
  
  # Get blocked IP count
  blocked_count=$(sudo cscli decisions list -o raw 2>/dev/null | tail -n +2 | wc -l || echo "0")
  
  echo "  CrowdSec Engine     $crowdsec_status"
  echo "  Firewall Bouncer    $bouncer_status"
  echo "  Blocked IPs         ${YELLOW}$blocked_count${NORMAL}"
  echo ""
}

function showWelcomeScreen() {
  cd /var/www/containers || exit
  showBanner

  echo "${MAGENTA}$(lsb_release -a 2>/dev/null)${NORMAL}"
  echo ""
  echo "${MAGENTA}Caddy version $(caddy version)${NORMAL}"
  echo "${MAGENTA}$(docker --version)${NORMAL}"
  echo ""
  
  showSecurityStatus
  
  echo "Caddy Server Files    ${YELLOW}/var/www/_caddy/${NORMAL}"
  echo "Hosted Containers     ${YELLOW}/var/www/containers${NORMAL}"
  echo "Hosted Static Files   ${YELLOW}/var/www/static${NORMAL}"
  echo ""
  echo "${BLUE}$(sudo docker ps)${NORMAL}"
  echo ""
}

function configureCrowdSec() {
  echo ""
  echo "${GREEN}――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――${NORMAL}"
  echo "${GREEN}CrowdSec Security Setup${NORMAL}"
  echo "${GREEN}――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――${NORMAL}"
  echo ""
  
  # Initialize CrowdSec (register bouncer, start services)
  echo "Initializing CrowdSec security engine..."
  sudo /usr/local/bin/crowdsec-first-boot.sh
  
  echo ""
  echo "CrowdSec is now protecting your server with:"
  echo "  - SSH brute force protection"
  echo "  - HTTP/Caddy attack detection"
  echo "  - Crowd-sourced threat intelligence"
  echo ""
  
  # Ask about console enrollment
  echo "Would you like to enroll in the CrowdSec Console?"
  echo "The console provides a web dashboard to monitor your server's security."
  echo "(You can always do this later - see README_USAGE.md for instructions)"
  echo ""
  echo -n "Enroll in CrowdSec Console? (y/N): "
  read -r enroll_choice
  
  if [[ "$enroll_choice" =~ ^[Yy]$ ]]; then
    echo ""
    echo "To get your enrollment key:"
    echo "  1. Sign up at ${CYAN}https://app.crowdsec.net/signup${NORMAL}"
    echo "  2. Go to Security Engines page"
    echo "  3. Copy the enrollment key from the command shown"
    echo ""
    echo "Paste your enrollment key or the full enrollment command:"
    read -r enrollment_key
    
    # Strip "sudo cscli console enroll " prefix if user pasted the full command
    enrollment_key="${enrollment_key#sudo cscli console enroll }"
    
    if [ -n "$enrollment_key" ]; then
      echo "Enrolling with CrowdSec Console..."
      if sudo cscli console enroll "$enrollment_key"; then
        echo ""
        echo "${GREEN}Enrollment request sent!${NORMAL}"
        echo ""
        echo "Next steps:"
        echo "  1. Go to ${CYAN}https://app.crowdsec.net${NORMAL}"
        echo "  2. Accept the enrollment request for this engine"
        echo "  3. Run: ${YELLOW}sudo systemctl restart crowdsec${NORMAL}"
        echo ""
        echo "Press Enter to continue..."
        read -r
      else
        echo ""
        echo "${RED}Enrollment failed. You can try again later with:${NORMAL}"
        echo "  ${YELLOW}sudo cscli console enroll <YOUR_ENROLLMENT_KEY>${NORMAL}"
        echo ""
        echo "Press Enter to continue..."
        read -r
      fi
    else
      echo ""
      echo "Skipping console enrollment. You can enroll later with:"
      echo "  ${YELLOW}sudo cscli console enroll <YOUR_ENROLLMENT_KEY>${NORMAL}"
      echo ""
    fi
  else
    echo ""
    echo "Skipping console enrollment. You can enroll later with:"
    echo "  ${YELLOW}sudo cscli console enroll <YOUR_ENROLLMENT_KEY>${NORMAL}"
    echo ""
  fi
}

function configureServer() {
  showBanner

  echo "Welcome to your dragon-server instance! Please complete the following steps to get started."
  echo ""
  echo "Enter the base domain name (e.g. example.com):"
  read -r base_domain
  echo "Enter the server administrator email address:"
  read -r admin_email

  if [ -z "$base_domain" ] || [ -z "$admin_email" ]; then
    clear
    configureServer
  fi

  # replace all example email and domain name placeholders with the user's input
  sed -i "s/example@example.com/$admin_email/g" /var/www/_caddy/Caddyfile
  sed -i "s/example.com/$base_domain/g" /var/www/_caddy/Caddyfile
  sed -i "s/example.com/$base_domain/g" /var/www/containers/whoami/docker-compose.yml

  # start the whoami container
  cd /var/www/containers/whoami && docker compose up -d

  # get the public IP address
  public_ip=$(curl -s ifconfig.me)

  echo ""
  echo "Add the following DNS records to your domain registrar:"
  {
    echo -e "${BLUE}Domain Name\tType\tValue${NORMAL}"
    echo -e "$base_domain\tA\t$public_ip"
    echo -e "whoami.$base_domain\tCNAME\t$base_domain"
    echo -e "static.$base_domain\tCNAME\t$base_domain"
  } | column -s $'\t' -t
  echo ""
  echo "Press Enter when done..."
  read -r

  # restart Caddy
  systemctl restart caddy

  # Configure dragon user (copy SSH keys, optional password, disable root login)
  sudo /usr/local/bin/dragon-user-setup.sh

  # Configure CrowdSec security
  configureCrowdSec

  # create a file to indicate that the script has been run
  touch /startup_configured

  clear
  echo "Configuration complete! You can test your server at ${CYAN}https://whoami.$base_domain${NORMAL}"
  echo ""
  showWelcomeScreen
}

# main *************************************************************************
# ******************************************************************************

if [ -f /startup_configured ]; then
  clear
  showWelcomeScreen
else
  clear
  configureServer
fi
