#!/bin/bash
set -e

echo "Testing direct SMTP communication from mail-api to mail-server:"

# Run the test directly inside the mail-api container
docker exec -it mail-api sh -c '
set -ex

# Set variables
SMTP_HOST="mail-server"
SMTP_PORT="25"
FROM="test@dinky.local"
TO="test@example.com"
SUBJECT="Test email from direct test"
BODY="This is a test email body sent at $(date)"

# Simple netcat SMTP conversation with detailed logging
(
  sleep 1
  echo "EHLO mail-api.local"
  sleep 1
  echo "MAIL FROM: <$FROM>"
  sleep 1
  echo "RCPT TO: <$TO>"
  sleep 1
  echo "DATA"
  sleep 1
  echo "From: $FROM"
  echo "To: $TO"
  echo "Subject: $SUBJECT"
  echo
  echo "$BODY"
  echo "."
  sleep 1
  echo "QUIT"
) | nc -v -w 10 $SMTP_HOST $SMTP_PORT
'

echo "Test completed." 