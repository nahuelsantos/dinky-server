# Mail Service

Dinky Server includes a complete mail solution for sending and receiving emails using your own domain.

## Mail Service Components

The mail service consists of:

1. **Mail Server** - Based on Docker Mail Server, handling SMTP, IMAP, and spam filtering
2. **Mail API** - RESTful API for sending emails programmatically
3. **Web Mail Client** - Web-based email client for accessing your emails

## Setup Instructions

### Environment Configuration

In your `.env` file, configure the following mail-related variables:

```
# Mail configuration
MAIL_DOMAIN=yourdomain.com
MAIL_HOSTNAME=mail.yourdomain.com
DEFAULT_FROM=hi@yourdomain.com

# For Gmail SMTP relay (recommended for better deliverability)
GMAIL_USERNAME=your.gmail@gmail.com
GMAIL_APP_PASSWORD=your-app-password
```

### Gmail SMTP Relay Configuration (Recommended)

For better email deliverability, configure Gmail as an SMTP relay:

1. Enable 2-Step Verification on your Gmail account:
   - Go to your Google Account settings
   - Navigate to Security
   - Enable 2-Step Verification

2. Create an App Password:
   - Go to your Google Account settings
   - Navigate to Security > App passwords
   - Select "Mail" and "Other" (Custom name: "Dinky Server")
   - Copy the generated password and use it as GMAIL_APP_PASSWORD

### Deployment

Deploy the mail services:

```bash
docker-compose -f services/docker-compose.mail.prod.yml up -d
```

## Usage

### Sending Emails via API

```bash
curl -X POST http://localhost:8025/api/v1/send \
  -H "Content-Type: application/json" \
  -d '{
    "to": "recipient@example.com",
    "subject": "Test Email",
    "text": "This is a test email."
  }'
```

### Accessing Webmail

Access the webmail client at: `http://mail.yourdomain.com` (production) or `http://localhost:8025` (development)

Default login:
- Username: `admin@yourdomain.com`
- Password: See your `.env` file (MAIL_ADMIN_PASSWORD)

## Adding Email Accounts

1. Log in to the admin interface
2. Navigate to "Accounts"
3. Click "Add Account"
4. Fill in the required information

## Troubleshooting

### Common Issues

- **Emails not being delivered**: Check spam filtering, DKIM configuration, and SPF records
- **Unable to send emails**: Verify SMTP settings and port configurations
- **Authentication failed**: Check username and password in environment variables

### Checking Mail Logs

```bash
docker-compose -f services/docker-compose.mail.prod.yml logs mail-server
```

## Advanced Configuration

For advanced configuration options, including:
- Custom spam filtering rules
- DKIM configuration
- Mail forwarding

See the [Docker Mail Server documentation](https://docker-mailserver.github.io/docker-mailserver/latest/). 