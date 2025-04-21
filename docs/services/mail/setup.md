# Mail Services Setup and Configuration

This guide provides detailed instructions for setting up and configuring the mail services on your Dinky Server.

## Prerequisites

Before setting up the mail services, ensure you have:

- A running Dinky Server installation
- Admin access to your server
- Docker and Docker Compose installed
- Basic understanding of SMTP and email concepts

## Setup Process

### Step 1: Configure Environment Variables

1. Create a production environment file for mail services:

   ```bash
   # From the Dinky Server root directory
   cp services/.env.mail services/.env.mail.prod
   ```

2. Edit the file with your settings:

   ```bash
   nano services/.env.mail.prod
   ```

3. Update the following key variables:

   ```
   # Mail Server Configuration
   MAIL_DOMAIN=yourdomain.com
   MAIL_HOSTNAME=mail.yourdomain.com
   
   # Default From Address
   DEFAULT_FROM=noreply@yourdomain.com
   
   # Allowed Host Domains (for CORS)
   ALLOWED_HOSTS=yourdomain.com,otherdomain.com
   
   # Mail User Credentials (for internal authentication)
   MAIL_USER=admin
   MAIL_PASSWORD=your-secure-password
   
   # Forwarding Address (optional)
   FORWARD_EMAIL=your-personal-email@example.com
   ```

### Step 2: Deploy the Mail Services

1. Deploy using Docker Compose:

   ```bash
   cd /path/to/dinky-server
   docker-compose -f services/docker-compose.mail.prod.yml --env-file services/.env.mail.prod up -d
   ```

2. Verify that the services are running:

   ```bash
   docker ps | grep mail
   ```

   You should see both `mail-server` and `mail-api` containers running.

### Step 3: Verify Mail Server Configuration

1. Check the mail server logs:

   ```bash
   docker logs mail-server
   ```

2. Look for configuration information similar to:

   ```
   Mail server configuration:
   -------------------------
   Hostname: mail.yourdomain.com
   Domain: yourdomain.com
   Default From: noreply@yourdomain.com
   -------------------------
   ```

3. Test sending an email:

   ```bash
   docker exec mail-server echo "This is a test" | mail -s "Test Email" your-test-email@example.com
   ```

4. Check if the email was sent:

   ```bash
   docker exec mail-server mailq
   ```

   If the queue is empty, the email was sent successfully.

## Integrating with Your Websites

### Step 1: Update Website Environment Variables

For each website that will use the mail service:

1. Create or update the site's environment file:

   ```bash
   mkdir -p /path/to/dinky-server/sites/your-site-name
   nano /path/to/dinky-server/sites/your-site-name/.env.prod
   ```

2. Add the Mail API URL:

   ```
   # Mail API configuration
   MAIL_API_URL=http://mail-api:20001/send
   ```

### Step 2: Update Docker Compose Configuration

Edit your site's `docker-compose.yml` to include:

```yaml
services:
  your-site-name:
    # Existing configuration...
    networks:
      - default
      - traefik_network
      - mail-internal
    env_file:
      - .env.prod

networks:
  # Existing networks...
  mail-internal:
    external: true
    name: services_mail-internal
```

### Step 3: Update Your Contact Form Code

In your website's backend code, use the Mail API to send emails:

```javascript
// Example for a Node.js backend
app.post('/contact', async (req, res) => {
  try {
    const response = await fetch(process.env.MAIL_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        to: "contact@yourdomain.com",
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

### Step 4: Test the Integration

Send a test email from your website container:

```bash
docker exec your-site-container curl -X POST http://mail-api:20001/send \
  -H "Content-Type: application/json" \
  -d '{"to":"your-email@example.com","subject":"Test","body":"Test from your site"}'
```

## Mail API Reference

### Endpoints

- `POST /send`: Send an email
- `GET /health`: Check API health

### Send Email Request Format

```json
{
  "to": "recipient@example.com",  // Required
  "from": "sender@yourdomain.com", // Optional, defaults to DEFAULT_FROM
  "subject": "Email Subject",     // Required
  "body": "Email content",        // Required
  "html": false                   // Optional, set to true for HTML content
}
```

### Response Format

Success:
```json
{
  "success": true,
  "message": "Email sent successfully"
}
```

Error:
```json
{
  "success": false,
  "message": "Error details"
}
```

## Next Steps

- [Configure Gmail SMTP Relay](gmail-relay.md) (Recommended)
- Read the [Local Development Guide](../../developer-guide/local-development.md) for testing locally
- Check the [Troubleshooting Guide](troubleshooting.md) if you encounter issues 