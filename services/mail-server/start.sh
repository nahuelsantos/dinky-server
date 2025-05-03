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

# Make sure we're using the btree format which is better supported in Alpine
sed -i 's/hash:/btree:/g' /etc/postfix/main.cf

# Configure relay host if specified
if [ ! -z "$RELAY_HOST" ]; then
  echo "Configuring relay host: $RELAY_HOST:$RELAY_PORT"
  
  # Uncomment relay configuration
  sed -i 's/# relayhost/relayhost/g' /etc/postfix/main.cf
  sed -i 's/# smtp_sasl_auth_enable/smtp_sasl_auth_enable/g' /etc/postfix/main.cf
  sed -i 's/# smtp_sasl_password_maps/smtp_sasl_password_maps/g' /etc/postfix/main.cf
  sed -i 's/# smtp_sasl_security_options/smtp_sasl_security_options/g' /etc/postfix/main.cf
  sed -i 's/# smtp_tls_note_starttls_offer/smtp_tls_note_starttls_offer/g' /etc/postfix/main.cf
  
  # Update relay host and port
  sed -i "s/\${RELAY_HOST}/$RELAY_HOST/g" /etc/postfix/main.cf
  sed -i "s/\${RELAY_PORT}/$RELAY_PORT/g" /etc/postfix/main.cf
  
  # Create sasl_passwd file if credentials are provided
  if [ ! -z "$RELAY_USER" ] && [ ! -z "$RELAY_PASSWORD" ]; then
    echo "Configuring relay authentication for user: $RELAY_USER"
    echo "[$RELAY_HOST]:$RELAY_PORT $RELAY_USER:$RELAY_PASSWORD" > /etc/postfix/sasl/sasl_passwd
    chmod 600 /etc/postfix/sasl/sasl_passwd
    
    # Use btree format instead of hash (better supported in Alpine)
    sed -i 's/hash:/btree:/g' /etc/postfix/main.cf
    
    # Create the database
    echo "Creating SASL password database with btree format..."
    postmap btree:/etc/postfix/sasl/sasl_passwd || { 
      echo "Error: postmap failed to create database"; 
      echo "Trying with different format...";
      postmap lmdb:/etc/postfix/sasl/sasl_passwd || {
        echo "Error: postmap failed again. Using text format.";
        sed -i 's/btree:/text:/g' /etc/postfix/main.cf
      }
    }
    
    echo "SMTP relay authentication configured"
  else
    echo "WARNING: RELAY_HOST specified but RELAY_USER and RELAY_PASSWORD are missing"
    echo "Relay will attempt without authentication, which may fail"
  fi
  
  echo "SMTP relay configured to use $RELAY_HOST:$RELAY_PORT"
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

# Create aliases database with btree format
echo "Creating aliases database with btree format..."
postalias btree:/etc/aliases || {
  echo "Warning: postalias with btree failed, trying text format...";
  postalias text:/etc/aliases || echo "Warning: postalias failed, but continuing...";
}

# Create mail directory if it doesn't exist
mkdir -p /var/spool/mail

# Make sure log file exists
touch /var/log/mail.log

# Show final configuration
echo "Mail server configuration:"
echo "-------------------------"
echo "Hostname: $MAIL_HOSTNAME"
echo "Domain: $MAIL_DOMAIN"
echo "Default From: ${DEFAULT_FROM}"
if [ ! -z "$RELAY_HOST" ]; then
  echo "Relay: $RELAY_HOST:$RELAY_PORT"
  echo "Relay User: $RELAY_USER"
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