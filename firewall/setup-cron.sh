#!/bin/bash
# Setup cron jobs for security maintenance

# Make all scripts executable
chmod +x "$(dirname "$0")/security-check.sh"
chmod +x "$(dirname "$0")/setup-firewall.sh"

# Run security check daily at 2 AM
CRON_JOB="0 2 * * * $(readlink -f "$(dirname "$0")/security-check.sh") > /dev/null 2>&1"

# Check if cron job already exists to avoid duplicates
if ! (crontab -l 2>/dev/null | grep -q "security-check.sh"); then
  (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
  echo "Cron job added to run security check daily at 2 AM"
else
  echo "Security check cron job already exists"
fi

# Run firewall setup to ensure rules are applied
"$(dirname "$0")/setup-firewall.sh"

echo "Security automation setup complete!" 