#!/bin/sh
set -e

# Process environment variables in configuration files
echo "Configuring mail server with domain: ${MAIL_DOMAIN:-dinky.local}"
MAIL_HOSTNAME=${MAIL_HOSTNAME:-mail.dinky.local}
MAIL_DOMAIN=${MAIL_DOMAIN:-dinky.local}
DEFAULT_FROM=${DEFAULT_FROM:-noreply@$MAIL_DOMAIN}

# Update main.cf with environment variables
sed -i "s/\${MAIL_HOSTNAME}/$MAIL_HOSTNAME/g" /etc/postfix/main.cf
sed -i "s/\${MAIL_DOMAIN}/$MAIL_DOMAIN/g" /etc/postfix/main.cf

# Ensure database directory exists
mkdir -p /etc/postfix/databases

# Configure relay host if specified
if [ ! -z "$SMTP_RELAY_HOST" ]; then
  echo "Configuring relay host: $SMTP_RELAY_HOST:$SMTP_RELAY_PORT"
  
  # Uncomment relay configuration
  sed -i 's/# relayhost/relayhost/g' /etc/postfix/main.cf
  sed -i 's/# smtp_sasl_auth_enable/smtp_sasl_auth_enable/g' /etc/postfix/main.cf
  sed -i 's/# smtp_sasl_password_maps/smtp_sasl_password_maps/g' /etc/postfix/main.cf
  sed -i 's/# smtp_sasl_security_options/smtp_sasl_security_options/g' /etc/postfix/main.cf
  sed -i 's/# smtp_tls_note_starttls_offer/smtp_tls_note_starttls_offer/g' /etc/postfix/main.cf
  
  # Update relay host and port
  sed -i "s/\${RELAY_HOST}/$SMTP_RELAY_HOST/g" /etc/postfix/main.cf
  sed -i "s/\${RELAY_PORT}/$SMTP_RELAY_PORT/g" /etc/postfix/main.cf
  
  # Create sasl_passwd file if credentials are provided
  if [ ! -z "$SMTP_RELAY_USERNAME" ] && [ ! -z "$SMTP_RELAY_PASSWORD" ]; then
    echo "Configuring relay authentication for user: $SMTP_RELAY_USERNAME"
    # Format for regexp lookup
    echo "/^.*\[$SMTP_RELAY_HOST\]:$SMTP_RELAY_PORT/ $SMTP_RELAY_USERNAME:$SMTP_RELAY_PASSWORD" > /etc/postfix/sasl/sasl_passwd
    chmod 600 /etc/postfix/sasl/sasl_passwd
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

# Make sure log file exists
touch /var/log/mail.log

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