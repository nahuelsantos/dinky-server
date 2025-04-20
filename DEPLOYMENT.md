# Mail Services Deployment Guide

This guide explains how to deploy the mail services to your Dinky server and integrate them with your websites.

## Deployment Steps

### 1. Prepare Environment Files

1. Copy the template environment file:
   ```bash
   cp services/.env.mail services/.env.mail.prod
   ```

2. Edit production settings in `.env.mail.prod`:
   ```bash
   nano services/.env.mail.prod
   ```
   
   Update these values for your environment:
   - `MAIL_DOMAIN`: Your domain (e.g., `nahuelsantos.com`)
   - `DEFAULT_FROM`: The default sender address (e.g., `hi@nahuelsantos.com`)
   - `ALLOWED_HOSTS`: Your website domains (e.g., `loopingbyte.com,nahuelsantos.com`)

3. **Recommended: Configure Gmail SMTP Relay**:
   This is **strongly recommended** for emails sent from a residential IP, especially 
   if they're going to forward to Gmail:

   To set up Gmail as your SMTP relay:
   - Go to https://myaccount.google.com/security
   - Enable 2-Step Verification if not already enabled
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and "Other (Custom name)" - enter "Dinky Server"
   - Copy the 16-character password

   Then in your `services/.env.mail.prod` file, uncomment and update:
   ```
   RELAY_HOST=smtp.gmail.com
   RELAY_PORT=587
   RELAY_USER=your-rely-user@gmail.com
   RELAY_PASSWORD=your-16-character-app-password
   ```

### 2. Deploy to Dinky

1. Copy the files to your Dinky server:
   ```bash
   # First, clone the repository if you haven't already
   git clone https://github.com/yourusername/dinky-server.git /opt/dinky-server
   
   # Or pull the latest changes if the repository already exists
   cd /opt/dinky-server && git pull
   ```

2. Start the mail services on your Dinky server:
   ```bash
   cd /opt/dinky-server
   docker-compose -f services/docker-compose.mail.prod.yml --env-file services/.env.mail.prod up -d
   ```

### 3. Verify Services are Running

Check that both services are running:

```bash
docker ps | grep mail
```

You should see both `mail-server` and `mail-api` containers running.

### 4. Verify SMTP Relay Configuration

Check if your SMTP relay is properly configured:

```bash
docker logs mail-server
```

Look for the following lines:
```
Mail server configuration:
-------------------------
Hostname: mail.dinky.local
Domain: nahuelsantos.com
Default From: hi@nahuelsantos.com
Relay: smtp.gmail.com:587
Relay User: nahuelsantos@gmail.com
-------------------------
```

Test sending an email:

```bash
docker exec mail-server echo "This is a test" | mail -s "Test Email" your-test-email@example.com
```

Check the mail queue to see if it was sent:

```bash
docker exec mail-server mailq
```

If the queue is empty, the email was sent successfully.

### 5. Update Your Website Configurations

For each of your websites, set up to use the mail service:

1. Create a website directory in the sites folder if it doesn't exist:
   ```bash
   mkdir -p /opt/dinky-server/sites/your-site-name
   ```

2. Create an environment file for the site:
   ```bash
   cat > /opt/dinky-server/sites/your-site-name/.env.prod << EOL
   # Production Environment for your-site-name
   
   # Site-specific settings
   SITE_DOMAIN=your-domain.com
   SITE_EMAIL=hello@your-domain.com
   
   # Mail API configuration
   MAIL_API_URL=http://mail-api:8080/send
   EOL
   ```

3. Update your site's docker-compose.yml to include:
   - The mail-internal network
   - The environment file

   Example:
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

4. Deploy your updated website configuration:
   ```bash
   cd /opt/dinky-server/sites/your-site-name
   docker-compose up -d
   ```

### 6. Update Your Contact Form Code

Modify your contact form handlers to use the MAIL_API_URL environment variable:

```javascript
// Example for a Node.js backend
app.post('/contact', async (req, res) => {
  try {
    const response = await fetch(process.env.MAIL_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        to: "hello@loopingbyte.com", // Or hi@nahuelsantos.com
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

### 7. Test the Integration

Send a test email from each website container:

```bash
docker exec your-site-container curl -X POST http://mail-api:8080/send \
  -H "Content-Type: application/json" \
  -d '{"to":"your-email@example.com","subject":"Test","body":"Test from your site"}'
```

## Troubleshooting

1. **Cannot connect to mail-api**:
   - Verify the containers are running: `docker ps | grep mail`
   - Check that your website is connected to the mail-internal network: `docker network inspect services_mail-internal`
   - Verify the API is responding: `docker exec mail-api wget -qO- http://localhost:8080/health`

2. **Emails not being sent**:
   - Check mail-server logs: `docker logs mail-server`
   - Test connectivity: `docker exec mail-api ping -c 1 mail-server`
   - Check mail queue: `docker exec mail-server mailq`

3. **Gmail SMTP Relay Issues**:
   - Make sure your App Password is correct
   - Check if Google has blocked the connection (check your Gmail account for security alerts)
   - Verify TLS is working: `docker exec mail-server openssl s_client -starttls smtp -connect smtp.gmail.com:587`

## Maintaining Local Development

The local development environment continues to work as before:

```bash
make run-local-mail  # Start services locally
make test-mail-api   # Test the mail API
```

The production configuration doesn't affect your local setup. 