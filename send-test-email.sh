#!/bin/bash
#
# Dinky Server - Send Test Email Script
# This script sends a test email through the mail-api service

# Check if running with sudo/as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo or as root"
    echo "Please run: sudo $0"
    exit 1
fi

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
TO_EMAIL=""

# Process command line arguments
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage: $0 <email-address>${NC}"
    echo "Please provide an email address to send the test email to."
    exit 1
else
    TO_EMAIL="$1"
fi

echo -e "${YELLOW}Sending test email to: ${TO_EMAIL}${NC}"

# Check if mail-api container is running
if ! docker ps | grep -q mail-api; then
    echo -e "${RED}Error: mail-api container is not running${NC}"
    echo "Please start it with: sudo docker compose up -d mail-api mail-server"
    exit 1
fi

# Install required tools in mail-api container if needed
echo "Checking required tools in mail-api container..."
if ! docker exec -i mail-api which wget >/dev/null 2>&1; then
    echo "Installing wget in mail-api container..."
    docker exec -i mail-api sh -c "apk add --no-cache wget" >/dev/null 2>&1 || {
        echo -e "${RED}Failed to install wget. Email sending may fail.${NC}";
    }
fi

if ! docker exec -i mail-api which curl >/dev/null 2>&1; then
    echo "Installing curl in mail-api container..."
    docker exec -i mail-api sh -c "apk add --no-cache curl" >/dev/null 2>&1 || {
        echo -e "${YELLOW}Failed to install curl. Will try with wget instead.${NC}";
    }
fi

# Send test email using wget inside the mail-api container (fallback to curl if available)
echo "Sending test email via mail-api..."
RESULT=$(docker exec -i mail-api sh -c 'wget -q -O- --post-data="{\"to\":\"'"${TO_EMAIL}"'\",\"subject\":\"Dinky Server Test Email\",\"body\":\"This is a test email sent from your Dinky Server on '"$(date)"'. If you received this, your mail system is working properly!\"}" --header="Content-Type: application/json" http://localhost:20001/send || curl -s -X POST -H "Content-Type: application/json" -d "{\"to\":\"'"${TO_EMAIL}"'\",\"subject\":\"Dinky Server Test Email\",\"body\":\"This is a test email sent from your Dinky Server on '"$(date)"'. If you received this, your mail system is working properly!\"}" http://localhost:20001/send')

# Check result
if echo "$RESULT" | grep -q "success"; then
    echo -e "${GREEN}Email sent successfully!${NC}"
    echo "Please check your inbox (and spam folder) at ${TO_EMAIL}"
    echo "If you don't receive the email, check your mail server logs:"
    echo "  sudo docker logs mail-server"
    echo "  sudo docker logs mail-api"
else
    echo -e "${RED}Failed to send email${NC}"
    echo "Error response: $RESULT"
    echo "Checking mail-api logs..."
    docker logs mail-api | tail -20
    echo "Checking mail-server logs..."
    docker logs mail-server | tail -20
fi 