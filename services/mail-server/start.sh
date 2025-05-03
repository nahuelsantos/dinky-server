#!/bin/sh
set -e

# Process environment variables in configuration files
echo "Configuring mail server with domain: ${MAIL_DOMAIN:-dinky.local}"
MAIL_HOSTNAME=${MAIL_HOSTNAME:-mail.dinky.local}
MAIL_DOMAIN=${MAIL_DOMAIN:-dinky.local}
DEFAULT_FROM=${DEFAULT_FROM:-noreply@$MAIL_DOMAIN}

# Create mail log directory
mkdir -p /var/log
touch /var/log/mail.log

# Enable detailed SMTP logs
postconf -e "debug_peer_level = 2"
postconf -e "debug_peer_list = mail-api.local,mail-api"
postconf -e "smtpd_debug_unsafe = yes"

# Use postconf to set basic mail configuration
postconf -e "myhostname = $MAIL_HOSTNAME"
postconf -e "mydomain = $MAIL_DOMAIN"
postconf -e "myorigin = $MAIL_DOMAIN"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = all"

# Ensure database directory exists
mkdir -p /etc/postfix/databases

# Configure relay host if specified
if [ ! -z "$SMTP_RELAY_HOST" ]; then
  echo "Configuring relay host: $SMTP_RELAY_HOST:$SMTP_RELAY_PORT"
  
  # Use postconf to set configuration values directly
  postconf -e "relayhost = [$SMTP_RELAY_HOST]:$SMTP_RELAY_PORT"
  postconf -e "smtp_sasl_auth_enable = yes"
  postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl/sasl_passwd"
  postconf -e "smtp_sasl_security_options = noanonymous"
  postconf -e "smtp_tls_security_level = encrypt"
  postconf -e "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
  
  # Create sasl_passwd file if credentials are provided
  if [ ! -z "$SMTP_RELAY_USERNAME" ] && [ ! -z "$SMTP_RELAY_PASSWORD" ]; then
    echo "Configuring relay authentication for user: $SMTP_RELAY_USERNAME"
    # Format for direct lookup - much simpler and more reliable
    echo "[$SMTP_RELAY_HOST]:$SMTP_RELAY_PORT $SMTP_RELAY_USERNAME:$SMTP_RELAY_PASSWORD" > /etc/postfix/sasl/sasl_passwd
    chmod 600 /etc/postfix/sasl/sasl_passwd
    postmap /etc/postfix/sasl/sasl_passwd
    echo "SMTP relay authentication configured"
  else
    echo "WARNING: SMTP_RELAY_HOST specified but SMTP_RELAY_USERNAME and SMTP_RELAY_PASSWORD are missing"
    echo "Relay will attempt without authentication, which may fail"
  fi
  
  echo "SMTP relay configured to use $SMTP_RELAY_HOST:$SMTP_RELAY_PORT"
  echo "Make sure your Gmail account has 'Less secure app access' enabled or App Passwords configured."
else
  echo "No SMTP relay configured - using direct delivery"
  echo "WARNING: Direct mail delivery is often blocked by ISPs and cloud providers."
  echo "Consider setting up Gmail SMTP relay for better deliverability."
fi

# Create aliases if they don't exist
if [ ! -f /etc/aliases ]; then
  echo "Creating aliases file..."
  echo "postmaster: root" > /etc/aliases
  echo "root: postmaster" >> /etc/aliases
fi

# Create mail directory if it doesn't exist
mkdir -p /var/spool/mail

# Configure submission service in master.cf
echo "Configuring submission service on port 587..."
if ! grep -q "^submission" /etc/postfix/master.cf; then
  cat >> /etc/postfix/master.cf << EOF
submission inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF
  echo "Submission service configured"
else
  echo "Submission service already configured"
fi

# Show final configuration
echo "Mail server configuration:"
echo "-------------------------"
echo "Hostname: $MAIL_HOSTNAME"
echo "Domain: $MAIL_DOMAIN"
echo "Default From: ${DEFAULT_FROM}"
if [ ! -z "$SMTP_RELAY_HOST" ]; then
  echo "Relay: $SMTP_RELAY_HOST:$SMTP_RELAY_PORT"
  echo "Relay User: $SMTP_RELAY_USERNAME"
fi
echo "-------------------------"

# Start Postfix in the foreground
echo "Starting Postfix..."
/usr/sbin/postfix start

# Print Postfix version
postconf mail_version

# Keep container running
echo "Mail server started. Tailing logs..."
tail -f /var/log/mail.log 2>/dev/null || tail -f /dev/null 