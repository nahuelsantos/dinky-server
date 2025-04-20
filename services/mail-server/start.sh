#!/bin/sh
set -e

# Create aliases if they don't exist
if [ ! -f /etc/aliases ]; then
  echo "Creating aliases file..."
  echo "postmaster: root" > /etc/aliases
  newaliases || echo "Warning: newaliases command failed, but continuing..."
fi

# Create mail directory if it doesn't exist
mkdir -p /var/spool/mail

# Make sure log file exists
touch /var/log/mail.log

# Start Postfix in the foreground
echo "Starting Postfix..."
/usr/sbin/postfix start

# Print Postfix version
postconf mail_version

# Keep container running
echo "Mail server started. Tailing logs..."
tail -f /var/log/mail.log 2>/dev/null || tail -f /dev/null 