# Mail Services

The Dinky Server Mail Services provide a self-hosted email solution specifically designed for handling contact form submissions from your websites.

## Overview

The mail services consist of two main components:

1. **Mail Server**: A Postfix-based SMTP server for sending emails
2. **Mail API**: An HTTP API that your web applications can use to send emails through the mail server

This setup allows your websites to send emails (such as contact form submissions) without relying on external services.

## Key Features

- Simple HTTP API for sending emails
- Support for Gmail SMTP relay for improved deliverability
- Automatic forwarding of incoming emails
- Docker-based deployment for easy setup and maintenance
- Integration with the Dinky Server monitoring stack

## Architecture

```
┌──────────────────┐   ┌──────────────────┐   ┌────────────────────┐
│                  │   │                  │   │                    │
│  Your Website    │──▶│  Mail API        │──▶│  Mail Server       │
│                  │   │                  │   │                    │
└──────────────────┘   └──────────────────┘   └────────────────────┘
                                                       │
                                                       ▼
                                              ┌────────────────────┐
                                              │                    │
                                              │  Gmail SMTP Relay  │
                                              │  (Recommended)     │
                                              │                    │
                                              └────────────────────┘
```

The Mail API accepts HTTP requests from your websites, processes them, and sends them to the Mail Server.
The Mail Server handles the actual sending of emails, optionally through Gmail's SMTP relay for improved deliverability.

## Setup and Configuration

### Setting Up Mail Services

1. Configure your mail environment file:

   ```bash
   cp services/.env.mail services/.env.mail.prod
   nano services/.env.mail.prod
   ```

2. Update these essential variables:

   ```
   MAIL_DOMAIN=yourdomain.com
   MAIL_HOSTNAME=mail.yourdomain.com
   MAIL_USER=admin
   MAIL_PASSWORD=your-secure-password
   DEFAULT_FROM=hi@yourdomain.com
   FORWARD_EMAIL=your-personal-email@example.com
   ```

3. Deploy the mail services:

   ```bash
   docker-compose -f services/docker-compose.mail.prod.yml --env-file services/.env.mail.prod up -d
   ```

### Using Gmail SMTP Relay

#### Why Use Gmail SMTP Relay?

There are several important benefits to using Gmail as an SMTP relay:

1. **Improved Deliverability**: Emails sent through Gmail are less likely to be marked as spam
2. **Bypass ISP Restrictions**: Many ISPs and cloud providers block outgoing port 25, making direct mail delivery unreliable
3. **Better Reputation**: Gmail has a good sending reputation, which helps your emails reach recipients' inboxes
4. **Reliable Delivery**: Gmail's infrastructure is highly reliable for email delivery

#### Prerequisites

Before setting up Gmail SMTP relay, you need:

- A Google account (preferably a Gmail account dedicated to your server)
- 2-Step Verification enabled on your Google account
- Access to your Dinky Server mail service configuration

#### Step 1: Enable 2-Step Verification

If you haven't already enabled 2-Step Verification:

1. Go to your [Google Account Security](https://myaccount.google.com/security) page
2. Scroll to the "Signing in to Google" section
3. Click on "2-Step Verification"
4. Follow the on-screen instructions to enable it

#### Step 2: Generate an App Password

1. Go to [App Passwords](https://myaccount.google.com/apppasswords) in your Google Account
2. You may need to sign in again
3. At the bottom, select "Mail" as the app
4. Select "Other (Custom name)" for the device
5. Enter "Dinky Server" or another recognizable name
6. Click "Generate"
7. Google will display a 16-character password - **copy this password immediately** as it will only be shown once

#### Step 3: Configure Dinky Server Mail Services

1. Edit your mail service environment file:

   ```bash
   nano /path/to/dinky-server/services/.env.mail.prod
   ```

2. Add or update the following SMTP relay settings:

   ```
   # Gmail SMTP Relay Configuration
   SMTP_RELAY_HOST=smtp.gmail.com
   SMTP_RELAY_PORT=587
   SMTP_RELAY_USERNAME=your-gmail-address@gmail.com
   SMTP_RELAY_PASSWORD=your-16-character-app-password
   USE_TLS=yes
   TLS_VERIFY=yes
   ```

3. Save the file and exit the editor

#### Step 4: Restart Mail Services

Restart the mail services to apply the new configuration:

```bash
cd /path/to/dinky-server
docker-compose -f services/docker-compose.mail.prod.yml --env-file services/.env.mail.prod down
docker-compose -f services/docker-compose.mail.prod.yml --env-file services/.env.mail.prod up -d
```

#### Step 5: Verify the Configuration

1. Check the mail server logs to verify that the SMTP relay is configured:

   ```bash
   docker logs mail-server
   ```

2. Look for output similar to:

   ```
   Mail server configuration:
   -------------------------
   Hostname: mail.yourdomain.com
   Domain: yourdomain.com
   Default From: noreply@yourdomain.com
   Relay: smtp.gmail.com:587
   Relay User: your-gmail-address@gmail.com
   -------------------------
   ```

3. Send a test email:

   ```bash
   docker exec mail-server echo "This is a test" | mail -s "Test Email" your-test-email@example.com
   ```

### Integrating with Your Website

To use the mail service from your website, make an HTTP POST request to the Mail API:

```javascript
fetch('https://mail-api.yourdomain.com/send', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    to: 'recipient@example.com',
    subject: 'Contact Form Submission',
    body: 'Message body from the contact form'
  })
})
.then(response => response.json())
.then(data => console.log(data))
.catch(error => console.error('Error:', error));
```

## Troubleshooting

If you encounter issues with the mail service:

### Gmail SMTP Relay Issues

- **Authentication Failures**: Verify you're using the App Password, not your regular Google account password
- **TLS/SSL Errors**: Ensure `USE_TLS=yes` is set and you're using port 587
- **Rate Limiting**: Gmail has sending limits (500 emails per day for personal accounts)

### Mail Server Issues

- Check logs: `docker logs mail-server`
- Verify connectivity: `telnet mail.yourdomain.com 25`
- Check SMTP configuration with: `docker exec mail-server postconf -n`

### Mail API Issues

- Check logs: `docker logs mail-api`
- Verify the API is accessible: `curl -I https://mail-api.yourdomain.com/health`
- Check DNS is correctly configured for the API domain

For more detailed troubleshooting, please see the [Troubleshooting guide](Troubleshooting#mail-services).

## Related Documentation

- [API Reference](API-Reference#mail-api)
- [Environment Variables](Environment-Variables#mail-service-variables)
- [Local Development](Local-Development#mail-services-development) 