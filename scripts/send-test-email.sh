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

echo "Checking required tools in mail-api container..."
docker exec -it mail-api which wget > /dev/null || { 
  echo "Installing wget in mail-api container..."
  docker exec -it mail-api apk add --no-cache wget
}

echo "Sending test email via mail-api..."
RESULT=$(docker exec -it mail-api sh -c 'wget -q -O- --post-data="{\"to\":\"'"${EMAIL_ADDRESS}"'\",\"subject\":\"Dinky Server Test Email\",\"body\":\"This is a test email sent from your Dinky Server on '"$(date)"'. If you received this, your mail system is working properly!\"}" --header="Content-Type: application/json" http://localhost:20001/send')

if echo "$RESULT" | grep -q "success"; then
    echo "Email sent successfully!"
    echo "Please check your inbox (and spam folder) at $EMAIL_ADDRESS"
else
    echo "Error sending email. Response: $RESULT"
    echo
    echo "Checking mail logs for issues..."
    echo "Mail-API logs:"
    docker logs mail-api | tail -10
    echo
    echo "Mail-Server logs:"
    docker logs mail-server | tail -10
    echo
    echo "Mail queue status:"
    docker exec -it mail-server mailq
fi

echo
echo "If you continue to have issues, check:"
echo "1. Gmail app password is correct in your .env file"
echo "2. Gmail account has 'Less secure app access' enabled or App Passwords configured."
echo "3. Mail queue with 'docker exec -it mail-server mailq'"
echo "4. Mail logs with 'docker logs mail-server' and 'docker logs mail-api'" 