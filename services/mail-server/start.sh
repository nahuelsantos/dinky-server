#!/bin/bash
set -e

echo "=== Starting Mail Server Configuration ==="

# Default values for environment variables
MAIL_HOSTNAME=${MAIL_HOSTNAME:-mail.dinky.local}
MAIL_DOMAIN=${MAIL_DOMAIN:-dinky.local}
DEFAULT_FROM=${DEFAULT_FROM:-noreply@dinky.local}
SMTP_RELAY_HOST=${SMTP_RELAY_HOST:-smtp.gmail.com}
SMTP_RELAY_PORT=${SMTP_RELAY_PORT:-587}
SMTP_RELAY_USERNAME=${SMTP_RELAY_USERNAME:-your-gmail-username@gmail.com}
SMTP_RELAY_PASSWORD=${SMTP_RELAY_PASSWORD:-your-gmail-app-password}
USE_TLS=${USE_TLS:-yes}
TLS_VERIFY=${TLS_VERIFY:-yes}

echo "Mail server configuration:"
echo "-------------------------"
echo "Hostname: $MAIL_HOSTNAME"
echo "Domain: $MAIL_DOMAIN"
echo "Default From: $DEFAULT_FROM"
echo "Relay: $SMTP_RELAY_HOST:$SMTP_RELAY_PORT"
echo "Relay User: $SMTP_RELAY_USERNAME"
echo "-------------------------"

# Create and touch necessary log files
mkdir -p /var/log
touch /var/log/mail.log

# Process template files
echo "Setting up configuration files..."
cat /etc/postfix/main.cf.template | \
  sed "s|\${MAIL_HOSTNAME}|$MAIL_HOSTNAME|g" | \
  sed "s|\${MAIL_DOMAIN}|$MAIL_DOMAIN|g" | \
  sed "s|\${SMTP_RELAY_HOST}|$SMTP_RELAY_HOST|g" | \
  sed "s|\${SMTP_RELAY_PORT}|$SMTP_RELAY_PORT|g" \
  > /etc/postfix/main.cf

# Configure SMTP relay authentication
echo "Setting up SMTP relay authentication..."
mkdir -p /etc/postfix/sasl
echo "[$SMTP_RELAY_HOST]:$SMTP_RELAY_PORT $SMTP_RELAY_USERNAME:$SMTP_RELAY_PASSWORD" > /etc/postfix/sasl/sasl_passwd
chmod 600 /etc/postfix/sasl/sasl_passwd
postmap hash:/etc/postfix/sasl/sasl_passwd

# Update postfix configuration to ensure it uses the hash map correctly
postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl/sasl_passwd"

# Configure submission service in master.cf for port 587
echo "Configuring submission service..."
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
fi

# Start Postfix
echo "Starting Postfix mail server..."
postfix start

# Wait a moment for Postfix to start
sleep 2

# Show running processes
echo "Postfix processes:"
ps aux | grep postfix

echo "Mail server ready. Logs will be displayed below:"
tail -f /var/log/mail.log 2>/dev/null || tail -f /dev/null 