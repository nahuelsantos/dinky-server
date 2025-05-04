#!/bin/bash
set -e

# Wait for Dovecot to be available
echo "Waiting for dovecot to be available..."
while ! nc -z localhost 143; do
  sleep 1
done
echo "Dovecot is available"

# Configure Postfix main.cf with environment variables
postconf -e "myhostname = ${MAIL_HOSTNAME}"
postconf -e "mydomain = ${MAIL_DOMAIN}"
postconf -e "myorigin = \$mydomain"

# Setup SMTP relay with Gmail credentials if they exist
if [ -n "${RELAY_HOST}" ] && [ -n "${RELAY_USERNAME}" ] && [ -n "${RELAY_PASSWORD}" ]; then
  echo "Configuring SMTP relay using ${RELAY_HOST}:${RELAY_PORT}"
  
  # Create the sasl_passwd file with credentials
  mkdir -p /etc/postfix
  echo "[${RELAY_HOST}]:${RELAY_PORT} ${RELAY_USERNAME}:${RELAY_PASSWORD}" > /etc/postfix/sasl_passwd
  
  # Generate hash database
  postmap /etc/postfix/sasl_passwd
  
  # Secure the credentials files
  chmod 600 /etc/postfix/sasl_passwd
  chmod 600 /etc/postfix/sasl_passwd.lmdb
  
  echo "SMTP relay configuration completed"
else
  echo "SMTP relay not configured - missing required environment variables"
fi

# Start Postfix
echo "Starting Postfix..."
service postfix start

# Start Dovecot
echo "Starting Dovecot..."
service dovecot start

# Keep the container running
echo "Mail server is running..."
tail -f /var/log/mail.log 