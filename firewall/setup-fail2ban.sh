#!/bin/bash
# Script to install and configure Fail2Ban for Dinky server

echo "Installing Fail2Ban..."
sudo apt update
sudo apt install -y fail2ban

# Create a custom configuration
echo "Configuring Fail2Ban..."
sudo tee /etc/fail2ban/jail.local > /dev/null << EOF
[DEFAULT]
# Ban hosts for 1 hour (3600 seconds)
bantime = 3600
# Find matches in the last 10 minutes (600 seconds)
findtime = 600
# Ban after 5 failures
maxretry = 5
# Email to send notifications to (uncomment and change if desired)
# destemail = your@email.com
# sendername = Fail2Ban
# mta = mail
# action = %(action_mwl)s

# SSH jail
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 14400  # Ban for 4 hours

# HTTP auth jail (for Traefik, if applicable)
[traefik-auth]
enabled = true
port = http,https
filter = traefik-auth
logpath = /var/log/traefik/access.log
maxretry = 5
EOF

# Create custom filter for Traefik
sudo mkdir -p /etc/fail2ban/filter.d
sudo tee /etc/fail2ban/filter.d/traefik-auth.conf > /dev/null << EOF
[Definition]
failregex = ^.*\"(GET|POST|HEAD).*\" 401 .*$
ignoreregex =
EOF

# Ensure Traefik logs to a file that Fail2Ban can monitor
echo "Note: Make sure Traefik is configured to log to /var/log/traefik/access.log"
echo "If it's not, edit the logpath in /etc/fail2ban/jail.local"

# Restart Fail2Ban to apply settings
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban

echo "Fail2Ban installation and configuration complete."
echo "Current status:"
sudo systemctl status fail2ban --no-pager
echo ""
echo "Active jails:"
sudo fail2ban-client status 