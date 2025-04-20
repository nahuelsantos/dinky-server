#!/bin/bash
# Test script for mail API

# Ensure the tools directory exists
mkdir -p $(dirname "$0")

# Default recipient email (override with first arg)
RECIPIENT=${1:-"test@example.com"}

# Default subject (override with second arg)
SUBJECT=${2:-"Test Email from Local Environment"}

# Default message (override with third arg)
MESSAGE=${3:-"This is a test email sent from the local development environment at $(date)"}

echo "Sending test email to: $RECIPIENT"
echo "Subject: $SUBJECT"
echo "Message: $MESSAGE"

# Send test email using curl
curl -X POST http://mail-api.local:20001/send \
  -H "Content-Type: application/json" \
  -d "{
    \"to\": \"$RECIPIENT\",
    \"subject\": \"$SUBJECT\",
    \"body\": \"$MESSAGE\",
    \"html\": false
  }"

echo ""
echo "Request sent. Check the mail-server logs for delivery status:"
echo "docker logs mail-server"
echo ""
echo "Note: In the local environment, SMTP is available at:"
echo "- localhost:2525 (standard SMTP)"
echo "- localhost:5587 (submission port)"