#!/bin/bash
# Script to install and configure Fail2Ban for Dinky server

echo "Installing Fail2Ban..."
sudo apt update
sudo apt install -y fail2ban

# First check where SSH logs are actually stored
echo "Detecting SSH log location..."
SSH_LOG_LOCATION=""
POSSIBLE_PATHS=(
  "/var/log/auth.log"
  "/var/log/secure"
  "/var/log/sshd.log"
)

for path in "${POSSIBLE_PATHS[@]}"; do
  if [ -f "$path" ]; then
    if grep -q "sshd" "$path" 2>/dev/null; then
      SSH_LOG_LOCATION="$path"
      echo "Found SSH logs at: $SSH_LOG_LOCATION"
      break
    fi
  fi
done

if [ -z "$SSH_LOG_LOCATION" ]; then
  echo "Could not find SSH log file. Checking systemd journal..."
  if journalctl -u ssh -n 1 &>/dev/null || journalctl -u sshd -n 1 &>/dev/null; then
    SSH_LOG_LOCATION="systemd"
    echo "Using systemd journal for SSH logs"
  else
    echo "WARNING: Could not detect SSH log location. Using default."
    SSH_LOG_LOCATION="/var/log/auth.log"
  fi
fi

# Create a custom configuration
echo "Configuring Fail2Ban..."

# Configure SSH jail based on log location
if [ "$SSH_LOG_LOCATION" == "systemd" ]; then
  SSH_CONFIG="
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
backend = systemd
maxretry = 3
bantime = 14400  # Ban for 4 hours
"
else 
  SSH_CONFIG="
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = $SSH_LOG_LOCATION
maxretry = 3
bantime = 14400  # Ban for 4 hours
"
fi

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
$SSH_CONFIG

# HTTP auth jail (for Traefik, if applicable)
[traefik-auth]
enabled = false
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

# Check if Traefik log directory exists
if [ ! -d "/var/log/traefik" ]; then
  echo "Creating Traefik log directory..."
  sudo mkdir -p /var/log/traefik
  sudo chmod 755 /var/log/traefik
fi

# Ensure Traefik logs to a file that Fail2Ban can monitor
echo "Note: Make sure Traefik is configured to log to /var/log/traefik/access.log"
echo "If it's not, edit the logpath in /etc/fail2ban/jail.local"
echo "Setting Traefik auth jail to disabled until log file exists."

# Restart Fail2Ban to apply settings
echo "Restarting Fail2Ban..."
sudo systemctl restart fail2ban
sleep 2  # Give it a moment to start

# Make sure it's enabled at boot
sudo systemctl enable fail2ban

echo "Checking Fail2Ban status..."
FAIL2BAN_STATUS=$(sudo systemctl is-active fail2ban)

if [ "$FAIL2BAN_STATUS" == "active" ]; then
  echo "Fail2Ban installation and configuration complete."
  echo "Current status:"
  sudo systemctl status fail2ban --no-pager
  echo ""
  echo "Active jails:"
  sudo fail2ban-client status
else
  echo "WARNING: Fail2Ban service is not running. Attempting to fix..."
  
  # Additional troubleshooting
  echo "Checking for error details..."
  sudo journalctl -u fail2ban -n 20 --no-pager
  
  echo "Setting fail2ban to use systemd backend for all jails as fallback..."
  sudo tee -a /etc/fail2ban/jail.local > /dev/null << EOF

# Global backend setting
backend = systemd
EOF
  
  # Try restarting again
  sudo systemctl restart fail2ban
  sleep 2
  
  if [ "$(sudo systemctl is-active fail2ban)" == "active" ]; then
    echo "Fix applied. Fail2Ban is now running."
  else
    echo "ERROR: Fail2Ban still not running. Manual intervention required."
    echo "You can proceed with the rest of the security setup and fix Fail2Ban later."
    exit 1
  fi
fi 