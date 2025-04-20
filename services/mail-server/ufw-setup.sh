#!/bin/bash
# This script sets up UFW rules for the mail server

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Allow SMTP ports
echo "Adding UFW rules for mail server..."
ufw allow 25/tcp comment 'SMTP'
ufw allow 587/tcp comment 'SMTP submission'

# Allow HTTP for mail API (if not already allowed)
ufw allow 80/tcp comment 'HTTP for mail API' 2>/dev/null || true

echo "UFW rules added. Current status:"
ufw status verbose

echo "Mail server ports are now open" 