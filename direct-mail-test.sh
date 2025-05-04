#!/bin/bash
set -e

# Check if an email address was provided
if [ $# -eq 0 ]; then
    echo "Error: Please provide an email address as an argument."
    echo "Usage: $0 your-email@example.com"
    exit 1
fi

EMAIL_ADDRESS=$1
echo "Sending test email to: $EMAIL_ADDRESS"

# Create and send test email directly from the mail-server container
echo "Creating test email in mail-server container..."
docker exec -i mail-server sh -c "cat > /tmp/test-email.txt << EOF
From: noreply@dinky.local
To: $EMAIL_ADDRESS
Subject: Test Email from Dinky Server

This is a test email sent directly from the mail-server container.
The time is now $(date).

If you're receiving this, your mail server is working correctly!
EOF"

echo "Sending email with sendmail..."
docker exec -i mail-server sh -c "cat /tmp/test-email.txt | sendmail -v -t"

echo "Email sent! Please check the mail server logs:"
docker logs mail-server | tail -20 