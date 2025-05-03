This guide explains how to set up and test Dinky Server components locally before deploying them to your production server.

## Prerequisites

Before you begin, make sure you have:

- Docker and Docker Compose installed
- Git installed
- Make installed
- curl, wget, and netcat for testing

## Development Environment Setup

1. Clone the Dinky Server repository:
   ```bash
   git clone https://github.com/yourusername/dinky-server.git
   cd dinky-server
   ```

2. Create a copy of the example environment file:
   ```bash
   cp .env.example .env
   ```

3. Edit the environment file with your development settings:
   ```bash
   nano .env
   ```

## Mail Services Development

### Setting Up Mail Services Locally

The local mail setup consists of the same components as the production environment:
- A Postfix SMTP server
- A Go-based mail API

To start the mail services for local testing:

```bash
make run-local-mail
```

This command:
1. Creates a Docker network if needed
2. Starts the mail server and mail API containers
3. Adds `mail-api.local` to your hosts file (requires sudo)
4. Exposes the mail API directly on port 20001

### Local Mail Service Ports

To avoid conflicts with system services, the local setup uses alternative ports:

- **Mail API**: 20001 (http://mail-api.local:20001)
- **SMTP**: 2525 (mapped to internal port 25)
- **SMTP Submission**: 5587 (mapped to internal port 587)

### Testing Mail Services Locally

#### Testing the Mail API

Test the mail API with a sample request:

```bash
make test-mail-api
```

Or use the test script with custom parameters:

```bash
# Format: ./tools/test-mail-api.sh [recipient] [subject] [message]
./tools/test-mail-api.sh your-email@example.com "Custom Subject" "Custom message body"
```

#### Testing the SMTP Server Connection

Test the SMTP server connection:

```bash
make test-mail-server
```

You should see a greeting from the mail server.

#### Manual SMTP Testing

You can test the SMTP server manually using the `nc` (netcat) command:

```bash
nc localhost 2525
```

This allows you to interact directly with the SMTP server. Here's a sample SMTP conversation:

```
HELO example.com
MAIL FROM:<sender@example.com>
RCPT TO:<recipient@example.com>
DATA
Subject: Test Email

This is a test email.
.
QUIT
```

### Stopping Mail Services

To stop the services:

```bash
make stop-local-mail
```

To remove containers and volumes (clean up):

```bash
make clean-local-mail
```

### Viewing Mail Logs

To monitor logs in real-time:

```bash
make logs-mail
```

Or view the logs for specific containers:

```bash
# Mail API logs
docker logs ${PROJECT:-dinky}_mail-api

# Mail server logs
docker logs ${PROJECT:-dinky}_mail-server
```

## Integrating with Local Web Applications

When developing web applications that need to send emails, you can configure them to use the local mail API.

### API Endpoint

The local mail API is available at:

```
http://mail-api.local:20001/send
```

### Example Integration (JavaScript)

```javascript
// Example fetch request
fetch('http://mail-api.local:20001/send', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    to: 'recipient@example.com',
    subject: 'Test from local app',
    body: 'This is a test email from my local application'
  })
})
.then(response => response.json())
.then(data => console.log(data))
.catch(error => console.error('Error:', error));
```

### Environment Variable for Local Development

For consistency with production, set up your local web app with an environment variable:

```
MAIL_API_URL=http://mail-api.local:20001/send
```

## Developing Other Services

### Monitoring Stack

To run the monitoring stack locally:

```bash
make run-local-monitoring
```

This will start Grafana, Prometheus, Loki, and other monitoring components.

Access the local Grafana dashboard at:

```
http://localhost:3000
```

Default login: admin / admin

### Adding a New Website

To set up a new website for local development:

```bash
make setup-site SITE=your-site-name
```

This creates a basic structure in `sites/your-site-name/` with:
- A basic docker-compose.yml file
- A .env.local file with development settings
- Integration with the mail service network

## Common Development Tasks

### Rebuilding Services

If you make changes to the code, rebuild the services:

```bash
make rebuild-mail
```

### Testing Changes

Before committing changes, run the test suite:

```bash
make test
```

### Generating Documentation

To generate or update documentation:

```bash
make docs
```

## Differences from Production

The local development environment differs from production in several ways:

1. **No Traefik**: Services are exposed directly on ports rather than through Traefik
2. **No Cloudflared**: No tunneling to Cloudflare's network
3. **Different Hostnames**: Uses `mail-api.local` instead of `mail-api.dinky.local`
4. **Alternative Ports**: Uses port 2525 for SMTP instead of 25, and 5587 instead of 587
5. **Direct Port Access**: Mail API is accessible directly on port 20001
6. **No SSL/TLS**: Local connections use HTTP, not HTTPS

## Troubleshooting

If you encounter issues during local development, check the relevant troubleshooting guides:
- [Mail Services Troubleshooting](Troubleshooting#mail-services)
- [General Troubleshooting](Troubleshooting) 