# Local Development Guide

This guide explains how to set up and test components locally before deploying them to the Dinky Server.

## Mail Services Setup

The mail services consist of a Postfix SMTP server and a Go-based mail API. You can test them locally without requiring Traefik, Cloudflared, or other production components.

### Prerequisites

- Docker and Docker Compose
- Make
- curl (for testing)
- netcat (for SMTP testing)

### Starting Mail Services Locally

To start the mail services for local testing:

```bash
make run-local-mail
```

This command:
1. Creates a Docker network if needed
2. Starts the mail server and mail API containers
3. Adds `mail-api.local` to your hosts file (requires sudo)
4. Exposes the mail API directly on port 20001

### Ports Used for Local Testing

To avoid conflicts with system services, the local setup uses alternative ports:

- **Mail API**: 20001 (http://mail-api.local:20001)
- **SMTP**: 2525 (mapped to internal port 25)
- **SMTP Submission**: 5587 (mapped to internal port 587)

### Testing the Mail Services

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

#### Testing the SMTP Server

Test the SMTP server connection:

```bash
make test-mail-server
```

You should see a greeting from the mail server.

### Stopping and Cleaning Up

To stop the services:

```bash
make stop-local-mail
```

To remove containers and volumes:

```bash
make clean-local-mail
```

## Differences from Production Setup

The local setup differs from the production environment in these ways:

1. **No Traefik**: Services are exposed directly on ports rather than through Traefik
2. **No Cloudflared**: No tunneling to Cloudflare's network
3. **Different Hostnames**: Uses `mail-api.local` instead of `mail-api.dinky.local`
4. **Alternative Ports**: Uses port 2525 for SMTP instead of 25, and 5587 instead of 587
5. **Direct Port Access**: Mail API is accessible directly on port 20001

## Integration with Web Applications

When testing your web applications locally with the mail service, use the following URL to send emails:

```
http://mail-api.local:20001/send
```

Example fetch request:

```javascript
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

## Monitoring and Debugging

To view logs:

```bash
# Mail API logs
docker logs mail-api

# Mail server logs
docker logs mail-server
```

To check sent emails, you can install a mail client like `mailx` and check the mail spool, or look at the mail server logs.

## Manual SMTP Testing

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