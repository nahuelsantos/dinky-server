# Dinky Server - Secure Home Server Setup

A complete self-hosted server solution for home and small business use.

## What is Dinky Server?

Dinky Server is a comprehensive self-hosted solution that combines multiple open-source tools to provide:

- Website and web application hosting
- Email sending and receiving with your own domain
- Network-wide ad blocking
- Docker container management
- Traffic routing with automatic SSL
- Server monitoring and alerting
- Secure remote access from anywhere

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/nahuelsantos/dinky-server.git
   cd dinky-server
   ```

2. Configure your environment:
   ```bash
   cp .env.example .env
   # Edit .env file with your settings
   ```

3. For local development:
   ```bash
   ./scripts/deploy-local.sh
   ```

4. For production deployment:
   ```bash
   ./scripts/deploy-prod.sh
   ```

## System Components

### Core Infrastructure

- **Traefik**: Reverse proxy and SSL termination
- **Cloudflared**: Secure tunneling for remote access
- **Pi-hole**: Network-wide ad blocking
- **Portainer**: Docker container management

### Key Services

- **Mail Server**: Complete email solution with SMTP, IMAP, and webmail
- **Mail API**: RESTful API for sending emails programmatically
- **Monitoring Stack**: Prometheus, Grafana, and Node Exporter

## Documentation

All documentation is located in the [`docs/`](docs/) directory:

- **Getting Started**
  - [Installation Guide](docs/getting-started/installation.md)
  - [System Overview](docs/getting-started/overview.md)
  - [Environment Variables](docs/getting-started/environment-variables.md)

- **Services**
  - [Mail Service Setup](docs/services/mail/setup.md)
  - [Gmail SMTP Relay](docs/services/mail/gmail-relay.md)
  - [Mail API Reference](docs/services/mail/api-reference.md)
  - [Monitoring Stack](docs/services/monitoring/overview.md)

- **Development & Deployment**
  - [Local Development](docs/developer-guide/local-development.md)
  - [Production Deployment](docs/deployment/production.md)
  - [Deployment Checklist](docs/deployment/checklist.md)
  - [Troubleshooting](docs/admin-guide/troubleshooting.md)

## Directory Structure

```
dinky-server/
├── apis/            # API services (mail-api, etc.)
├── docs/            # Documentation
├── infrastructure/  # Core infrastructure components
├── monitoring/      # Monitoring stack
├── services/        # Background services (mail-server, etc.)
├── sites/           # Website configurations
└── scripts/         # Utility scripts
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
