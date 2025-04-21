# Mail Services Troubleshooting

This guide provides solutions for common issues you might encounter with the Dinky Server mail services.

## Common Issues

### Mail Server Won't Start

**Symptoms:**
- Docker container exits immediately after starting
- `docker ps` doesn't show the mail-server container

**Possible Causes and Solutions:**

1. **Port Conflict:**
   ```bash
   # Check for services using port 25
   sudo netstat -tulpn | grep :25
   ```
   
   If another service (like Exim4 or Postfix) is using port 25:
   ```bash
   # Stop and disable the conflicting service
   sudo systemctl stop exim4
   sudo systemctl disable exim4
   # OR for Postfix
   sudo systemctl stop postfix
   sudo systemctl disable postfix
   ```

2. **Configuration Error:**
   Check the mail server logs for errors:
   ```bash
   docker logs mail-server
   ```

3. **Volume Permission Issues:**
   ```bash
   # Fix permissions on mail data volumes
   sudo chown -R 1000:1000 /path/to/dinky-server/services/mail-server/data
   sudo chown -R 1000:1000 /path/to/dinky-server/services/mail-server/logs
   ```

### Mail API Connection Issues

**Symptoms:**
- Websites can't connect to the mail API
- "Connection refused" errors

**Possible Causes and Solutions:**

1. **Network Configuration:**
   Make sure your website container is properly connected to the mail-internal network:
   ```bash
   docker network inspect services_mail-internal
   ```
   
   Check that your website's docker-compose.yml includes:
   ```yaml
   networks:
     - mail-internal
   ```

2. **Mail API Not Running:**
   ```bash
   # Check if the mail API is running
   docker ps | grep mail-api
   
   # If not, start it
   docker-compose -f services/docker-compose.mail.prod.yml --env-file services/.env.mail.prod up -d mail-api
   ```

3. **Wrong Mail API URL:**
   Verify that your website's environment file has the correct URL:
   ```
   MAIL_API_URL=http://mail-api:20001/send
   ```

### Emails Not Being Sent

**Symptoms:**
- No errors, but emails aren't delivered
- Mail API returns success but emails don't arrive

**Possible Causes and Solutions:**

1. **SMTP Relay Issues:**
   Check if emails are stuck in the mail queue:
   ```bash
   docker exec mail-server mailq
   ```
   
   Check the mail server logs for SMTP relay errors:
   ```bash
   docker logs mail-server | grep error
   ```

2. **Gmail SMTP Relay Authentication:**
   Verify your Gmail SMTP relay configuration:
   ```bash
   docker exec mail-server grep -A 10 "relayhost" /etc/postfix/main.cf
   ```
   
   Make sure you're using an App Password, not your regular Google password.

3. **Gmail Rate Limiting:**
   Gmail limits sending to 500 emails per day for personal accounts. Check if you've exceeded this limit.

4. **DNS Resolution Issues:**
   Check if your container can resolve DNS:
   ```bash
   docker exec mail-server nslookup smtp.gmail.com
   ```

### SSL/TLS Issues

**Symptoms:**
- Errors mentioning SSL, TLS, or certificate validation
- "Connection refused" when trying to connect to Gmail SMTP

**Possible Causes and Solutions:**

1. **Missing Certificates:**
   ```bash
   # Check if certificates are available
   docker exec mail-server ls -la /etc/ssl/certs
   
   # Update certificates if needed
   docker exec mail-server update-ca-certificates
   ```

2. **TLS Configuration:**
   Make sure your .env.mail.prod file has:
   ```
   USE_TLS=yes
   TLS_VERIFY=yes
   ```

3. **Port Configuration:**
   Gmail SMTP relay requires port 587 with STARTTLS, not port 465 with SSL.

### Mail API Returns 500 Errors

**Symptoms:**
- HTTP 500 errors when calling the mail API
- Error messages in mail-api logs

**Possible Causes and Solutions:**

1. **Invalid Email Format:**
   Ensure that the "to" and "from" email addresses are valid.

2. **Missing Required Fields:**
   The API requires "to", "subject", and "body" fields.

3. **CORS Issues:**
   Make sure your domain is listed in the ALLOWED_HOSTS environment variable.

4. **Authentication Problems:**
   Check if the mail API can authenticate with the mail server:
   ```bash
   docker logs mail-api | grep auth
   ```

## Diagnostic Commands

### Check Mail Server Status

```bash
# Check if the container is running
docker ps | grep mail-server

# Check mail server logs
docker logs mail-server

# Check mail queue
docker exec mail-server mailq

# Test sending a simple email
docker exec mail-server echo "Test message" | mail -s "Test" your-email@example.com

# Check SMTP relay configuration
docker exec mail-server postconf -n | grep relay
```

### Test Mail API

```bash
# Check if the container is running
docker ps | grep mail-api

# Check mail API logs
docker logs mail-api

# Test the health endpoint
curl http://localhost:20001/health  # If exposing port locally
# OR from another container
docker exec another-container curl -s http://mail-api:20001/health

# Test sending an email
curl -X POST http://localhost:20001/send \
  -H "Content-Type: application/json" \
  -d '{"to":"your-email@example.com","subject":"Test","body":"Test message"}'
```

### Network Configuration

```bash
# List all Docker networks
docker network ls

# Inspect the mail-internal network
docker network inspect services_mail-internal

# Check connections to the mail server
docker exec mail-server netstat -tulpn

# Test connectivity from another container
docker exec website-container ping mail-api
docker exec website-container ping mail-server
```

## Collecting Information for Support

If you need to ask for help or report an issue, gather this information:

1. **Configuration:**
   ```bash
   # Mail server configuration (redact passwords)
   cat services/.env.mail.prod | grep -v PASSWORD
   
   # Mail server Postfix configuration
   docker exec mail-server postconf -n
   ```

2. **Logs:**
   ```bash
   # Last 100 lines of mail server logs
   docker logs --tail 100 mail-server
   
   # Last 100 lines of mail API logs
   docker logs --tail 100 mail-api
   ```

3. **Status Information:**
   ```bash
   # Container status
   docker ps -a | grep mail
   
   # Mail queue status
   docker exec mail-server mailq
   ```

## Frequently Asked Questions

### Why use Gmail SMTP relay instead of direct delivery?

Most residential ISPs and cloud providers block outgoing port 25, which is used for direct mail delivery. Gmail SMTP relay provides a reliable way to send emails and improves deliverability.

### How can I check if my emails are being marked as spam?

Send test emails to addresses with different providers (Gmail, Outlook, Yahoo, etc.) and check if they arrive in spam folders. You can also use services like [mail-tester.com](https://www.mail-tester.com/) to check your email's spam score.

### How many emails can I send per day?

With a personal Gmail account, you're limited to 500 emails per day. Google Workspace accounts have higher limits depending on your plan.

### Can I use another SMTP relay provider instead of Gmail?

Yes, you can use any SMTP relay service that supports authentication. Update the relay configuration in your .env.mail.prod file accordingly.

## Next Steps

- Check the [Gmail SMTP Relay Guide](gmail-relay.md) for detailed setup instructions
- Review the [Mail Service Setup Guide](setup.md) for configuration options
- Consider [upgrading to a Google Workspace account](https://workspace.google.com/) for higher sending limits 