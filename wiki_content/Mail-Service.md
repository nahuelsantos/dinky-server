# Mail Service

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

The mail service is configured through environment variables in your `.env` file and `services/.env.mail` file:

| Variable | Description | Default |
|----------|-------------|---------|
| `MAIL_DOMAIN` | Your mail domain | nahuelsantos.com |
| `MAIL_HOSTNAME` | Mail server hostname | mail.nahuelsantos.com |
| `DEFAULT_FROM` | Default sender address | noreply@nahuelsantos.com |
| `SMTP_RELAY_HOST` | SMTP relay host (optional) | smtp.gmail.com |
| `SMTP_RELAY_PORT` | SMTP relay port | 587 |
| `SMTP_RELAY_USERNAME` | SMTP relay username | |
| `SMTP_RELAY_PASSWORD` | SMTP relay password | |
| `USE_TLS` | Whether to use TLS for SMTP relay | yes |
| `TLS_VERIFY` | Whether to verify TLS certificates | yes |
| `ALLOWED_HOSTS` | Comma-separated list of allowed origins | nahuelsantos.com,loopingbyte.com |
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
   SMTP_RELAY_PASSWORD=your-app-password
   ```

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
   sudo ./initialize.sh
   ```

3. If you encounter image reference errors like:
   ```
   pull access denied for nahuelsantos/dinky/mail-server, repository does not exist or may require 'docker login'
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

- [API Reference](API-Reference#mail-api)
- [Environment Variables](Environment-Variables#mail-service-variables)
- [Local Development](Local-Development#mail-services-development)

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