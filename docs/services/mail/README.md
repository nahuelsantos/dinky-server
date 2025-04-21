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

## Documentation

- [Setup and Configuration](setup.md): Detailed instructions for setting up and configuring mail services
- [Using Gmail SMTP Relay](gmail-relay.md): How to configure Gmail SMTP relay for better email deliverability
- [Troubleshooting Mail Issues](troubleshooting.md): Common problems and their solutions

## Quick Links

- [Local Development](../../developer-guide/local-development.md#mail-services): How to develop and test with mail services locally
- [Environment Variables](../../getting-started/environment-variables.md#mail-service-variables): List of all mail-related environment variables
- [API Reference](../../developer-guide/api-reference.md#mail-api): Detailed information about the Mail API endpoints

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