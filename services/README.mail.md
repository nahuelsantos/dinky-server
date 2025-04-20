# Mail Services for Dinky Server

This service provides a simple self-hosted email solution specifically designed for handling contact form submissions from your websites.

## Components

1. **Postfix Mail Server**: A lightweight SMTP server for sending emails
2. **Mail API**: A simple HTTP API that your web applications can use to send emails

## Deployment

For full deployment instructions, see the [Mail Services Deployment Guide](../DEPLOYMENT.md).

## Quick Start

### Local Development

```bash
# Set up required directories
make setup-local-mail

# Start mail services locally
make run-local-mail

# Test the API
make test-mail-api

# Test SMTP server
make test-mail-server

# View logs
make logs-mail

# Stop mail services
make stop-local-mail
```

### Production Deployment

1. Configure environment file:
   ```bash
   cp .env.mail .env.mail.prod
   nano .env.mail.prod  # Edit with your settings
   ```

2. Deploy mail services:
   ```bash
   docker-compose -f docker-compose.mail.prod.yml --env-file .env.mail.prod up -d
   ```

## API Usage

To send an email from your web applications, make a POST request to the mail API:

```
POST http://mail-api:8080/send

{
  "to": "recipient@example.com",
  "subject": "Contact Form Submission",
  "body": "Name: John Doe\nEmail: john@example.com\nMessage: Hello, I'd like to inquire about your services.",
  "html": false
}
```

### API Fields

- `to`: (Required) Email address of the recipient
- `from`: (Optional) Email address of the sender (defaults to the DEFAULT_FROM env variable)
- `subject`: (Required) Subject of the email
- `body`: (Required) Content of the email
- `html`: (Optional) Set to true if the body contains HTML content

## Example Integration

```javascript
// Example for a Node.js backend
app.post('/contact', async (req, res) => {
  try {
    const response = await fetch(process.env.MAIL_API_URL, {
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

## Gmail SMTP Relay

For improved email deliverability, it's recommended to configure Gmail SMTP relay. This is configured in your `.env.mail.prod` file.

### Why use Gmail SMTP relay?

- **Improved Deliverability**: Emails sent through Gmail are less likely to be marked as spam
- **ISP Port Blocking**: Many ISPs and cloud providers block outgoing port 25, making direct mail delivery unreliable
- **Reputation**: Gmail has a good sending reputation, which helps your emails reach inboxes

See the [Deployment Guide](../DEPLOYMENT.md) for detailed setup instructions.

## Network Configuration

- **SMTP Server**: Exposed on ports 25 and 587
- **Mail API**: Exposed via Traefik at `mail-api.dinky.local`

### DNS Configuration

Add the following to your local hosts file or DNS server:
```
127.0.0.1 mail-api.dinky.local
```

## Project Structure

```
dinky-server/
├── services/
│   ├── mail-server/        # Postfix SMTP server
│   │   └── ufw-setup.sh    # Firewall configuration script
│   └── docker-compose.mail.yml  # Combined Docker Compose file
├── apis/
│   └── mail-api/           # Go API for sending emails
```

## Maintenance

- Mail logs are stored in the `mail-logs` volume
- Sent emails are stored in the `