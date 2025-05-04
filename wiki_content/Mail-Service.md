This page provides information about the mail service in Dinky Server, including setup, configuration, and troubleshooting.

## Overview

Dinky Server includes a complete mail solution that allows you to:

- Send emails from your websites (especially useful for contact forms)
- Use your own domain for emails
- Relay through Gmail or other SMTP providers if needed

The mail service consists of two main components:

1. **Mail Server**: A Postfix-based SMTP server that handles email delivery
2. **Mail API**: A RESTful API that provides a simple interface for sending emails

## Configuration

### Environment Variables

The mail service is configured through environment variables in your `.env` file:

| Variable | Description | Default |
|----------|-------------|---------|
| `MAIL_DOMAIN` | Your mail domain | yourdomain.com |
| `MAIL_HOSTNAME` | Mail server hostname | mail.yourdomain.com |
| `DEFAULT_FROM` | Default sender address | noreply@yourdomain.com |
| `SMTP_RELAY_HOST` | SMTP relay host (optional) | smtp.gmail.com |
| `SMTP_RELAY_PORT` | SMTP relay port | 587 |
| `SMTP_RELAY_USERNAME` | SMTP relay username | |
| `SMTP_RELAY_PASSWORD` | SMTP relay password (no spaces) | |
| `USE_TLS` | Whether to use TLS for SMTP relay | yes |
| `TLS_VERIFY` | Whether to verify TLS certificates | yes |
| `ALLOWED_HOSTS` | Comma-separated list of allowed origins | yourdomain.com,api.yourdomain.com |
| `ENVIRONMENT` | Environment (production/development) | production |
| `TRAEFIK_ENTRYPOINT` | Traefik entrypoint to use for mail API | https |
| `ENABLE_TLS` | Whether to enable TLS for mail API | true |

### Relay Configuration

If you want to use Gmail as a relay (recommended for better deliverability):

1. Create a Gmail account or use an existing one
2. Generate an App Password: 
   - Go to your Google Account > Security > 2-Step Verification > App passwords
   - Select "Mail" and "Other" (custom name), then generate
3. Add these to your `.env` file:
   ```
   SMTP_RELAY_USERNAME=your-gmail-username@gmail.com
   SMTP_RELAY_PASSWORD=your-app-password  # Without spaces
   ```

**Important note about Gmail App Passwords**: The password should be entered without spaces. For example, if Google shows "XXXX XXXX XXXX XXXX", enter it as "XXXXXXXXXXXXXXXX" in your .env file.

## Using the Mail API

The mail service exposes a simple RESTful API that you can use to send emails:

### Endpoint: `POST /send`

**Request Body:**
```json
{
  "to": "recipient@example.com",
  "subject": "Hello from Dinky Server",
  "body": "This is a test email sent from Dinky Server.",
  "from": "optional-custom-sender@yourdomain.com"
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Email sent successfully"
}
```

**Response (Error):**
```json
{
  "error": "Failed to send email",
  "details": "Error details message"
}
```

### Example Usage

From JavaScript (in a website contact form):

```javascript
// Example for a Node.js backend
app.post('/contact', async (req, res) => {
  try {
    const response = await fetch('http://mail-api.local:20001/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        to: "hello@yourdomain.com",
        subject: "Contact Form Submission",
        body: `Name: ${req.body.name}\nEmail: ${req.body.email}\nMessage: ${req.body.message}`,
        html: false
      })
    });
    
    const result = await response.json();
    if (result.success) {
      res.status(200).send({ message: "Message sent successfully" });
    } else {
      res.status(500).send({ message: "Failed to send message" });
    }
  } catch (error) {
    res.status(500).send({ message: "An error occurred" });
  }
});
```

## Troubleshooting

### Common Issues

#### Mail Server or Mail API Not Starting

**Problem**: When running the installation, you see errors about the mail server or mail API not starting.

**Solution**:

1. Check if the Dockerfiles exist and are properly formatted:
   ```bash
   ls -la services/mail-server/Dockerfile
   ls -la apis/mail-api/Dockerfile
   ```

2. If they don't exist, run the initialization script to create them:
   ```bash
   sudo ./scripts/initialize.sh
   ```

3. If you encounter image reference errors like:
   ```
   pull access denied for yourregistry/dinky/mail-server, repository does not exist or may require 'docker login'
   ```

   This means the image references in the docker-compose file are incorrect. The installation script should automatically fix this, but you can manually update `services/docker-compose.yml` to use:

   ```yaml
   mail-server:
     image: alpine:3.18
     build:
       context: ./mail-server
       dockerfile: Dockerfile
   
   mail-api:
     image: node:18-alpine
     build:
       context: ../apis/mail-api
       dockerfile: Dockerfile
   ```

4. Then rebuild the services:
   ```bash
   sudo docker compose -f services/docker-compose.yml build
   sudo docker compose -f services/docker-compose.yml up -d
   ```

#### Email Not Being Sent

**Problem**: Emails are not being delivered to recipients.

**Solution**:

1. Check the mail server logs:
   ```bash
   docker logs ${PROJECT:-dinky}_mail-server
   ```

2. Verify your relay configuration:
   ```bash
   docker exec -it ${PROJECT:-dinky}_mail-server cat /etc/postfix/sasl/sasl_passwd
   ```

3. Test connectivity to the relay server:
   ```bash
   docker exec -it ${PROJECT:-dinky}_mail-server nc -zv smtp.gmail.com 587
   ```

4. If using Gmail, ensure you're using an App Password, not your regular account password.

#### CORS Issues with Mail API

**Problem**: Website contact forms getting CORS errors when trying to use the Mail API.

**Solution**:

1. Make sure your domain is included in the `ALLOWED_HOSTS` environment variable.

2. Check the mail API logs:
   ```bash
   docker logs ${PROJECT:-dinky}_mail-api
   ```

3. Verify that the CORS configuration is working by checking the response headers in your browser's Network tab.

## Maintenance

### Checking Logs

To view logs for the mail services:

```bash
# Mail server logs
docker logs ${PROJECT:-dinky}_mail-server

# Mail API logs
docker logs ${PROJECT:-dinky}_mail-api
```

### Restarting Services

If you need to restart the mail services:

```bash
docker restart ${PROJECT:-dinky}_mail-server
docker restart ${PROJECT:-dinky}_mail-api
```

Or restart everything:

```bash
docker compose -f services/docker-compose.yml restart
```

### Updating Configuration

If you change environment variables, you'll need to restart the services for the changes to take effect:

```bash
docker compose -f services/docker-compose.yml down
docker compose -f services/docker-compose.yml up -d
```

## Related Documentation

- [API Reference](API-Reference.md#mail-api)
- [Environment Variables](Environment-Variables.md#mail-service-variables)
- [Local Development](Local-Development.md#mail-services-development)

# Network Configuration

- **SMTP Server**: Exposed on ports 25 and 587 (internal access only)
- **Mail API**: Exposed via Traefik at `mail-api.local` (internal access only)

### Internal Access Configuration

The mail services are configured for internal access only, meaning:

1. The SMTP server (mail-server) binds to 127.0.0.1, making it accessible only from the local machine
2. The Mail API is configured with Traefik to be accessible only as `mail-api.local`
3. No public/external exposure via Cloudflare Tunnel

### DNS Configuration

Add the following to your local hosts file or internal DNS server:
```
127.0.0.1 mail-api.local
```

This is automatically added to the server's /etc/hosts file during installation.

# Mail Service Troubleshooting

If you're experiencing issues with the mail service, here are some steps you can take to diagnose and fix common problems:

## Testing the Mail Service

1. **Use the test.sh script to check if services are running**:
   ```bash
   sudo ./scripts/test.sh
   ```
   This will check if both mail-server and mail-api containers are running and communicating properly.

2. **For more detailed mail service tests**:
   ```bash
   sudo ./scripts/test-all-components.sh --mail
   ```
   This will perform comprehensive tests on the mail services including connectivity, configuration, and network checks.

3. **Restart the mail services**:
   ```bash
   sudo ./scripts/test.sh --restart-mail
   ```
   This will stop and restart both the mail-server and mail-api containers.

4. **Send a test email**:
   ```bash
   sudo ./scripts/send-test-email.sh your-email@example.com
   ```
   This script will send a test email to the specified address and provide immediate feedback on success or failure.

## Common Issues and Solutions

### Environment Variable Mismatch

The mail-server expects environment variables with `SMTP_RELAY_` prefix (e.g., `SMTP_RELAY_HOST`, `SMTP_RELAY_PORT`, etc.), but older versions may have used `RELAY_` prefix. To fix this:

1. Check your .env file and make sure it uses the correct variables:
   ```
   SMTP_RELAY_HOST=smtp.gmail.com
   SMTP_RELAY_PORT=587
   SMTP_RELAY_USERNAME=your-gmail-address@gmail.com
   SMTP_RELAY_PASSWORD=your-16-character-app-password
   ```

2. Check the docker-compose.yml file to ensure it passes these variables to the mail-server container.

### Cannot Connect to SMTP Relay

If your mail server cannot connect to the SMTP relay (e.g., Gmail):

1. Verify your credentials are correct in the .env file
2. For Gmail, make sure you're using an App Password (requires 2FA to be enabled on your Google account)
3. Check if your ISP or cloud provider is blocking outgoing connections to port 587

### Mail API Not Responding

If the mail-api container is running but not responding to requests:

1. Check its logs: `docker logs mail-api`
2. Verify it can connect to the mail-server: `docker exec -it mail-api ping mail-server`
3. Make sure the health check endpoint is working: `docker exec -it mail-api wget -q -O- http://localhost:20001/health`

## Debugging Tools

- **View mail server logs**: `docker logs mail-server`
- **View mail API logs**: `docker logs mail-api`
- **Enter mail server container**: `docker exec -it mail-server sh`
- **Enter mail API container**: `docker exec -it mail-api sh`
- **Test SMTP connectivity**: `docker exec -it mail-server nc -zv smtp.gmail.com 587`

## SMTP Relay Configuration

For better deliverability, configure an SMTP relay service like Gmail:

1. Go to your Google Account > Security > 2-Step Verification (enable it)
2. Go to App Passwords, create a new password for "Mail" app
3. Use these credentials in your .env file:
   ```
   SMTP_RELAY_HOST=smtp.gmail.com
   SMTP_RELAY_PORT=587
   SMTP_RELAY_USERNAME=your-gmail-address@gmail.com
   SMTP_RELAY_PASSWORD=your-16-character-app-password
   ``` 