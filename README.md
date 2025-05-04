[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com/)
[![Platforms](https://img.shields.io/badge/Platforms-Linux%20%7C%20Raspberry%20Pi-green.svg)](#hardware-requirements)
[![Documentation](https://img.shields.io/badge/Wiki-Documentation-informational)](https://github.com/nahuelsantos/dinky-server/wiki)
[![Maintenance](https://img.shields.io/badge/Maintained-Yes-success.svg)](https://github.com/nahuelsantos/dinky-server/commits/main)

# Dinky Server - Secure Home Server Setup

A comprehensive self-hosted server solution for home and small business use.

## What is Dinky Server?

Dinky Server is a complete self-hosted solution that combines multiple open-source tools to provide:

- Website and web application hosting
- Email sending and receiving with your own domain
- Network-wide ad blocking
- Docker container management
- Traffic routing with automatic SSL
- Server monitoring and alerting
- Secure remote access from anywhere

## Features

- **Ultra Secure**: Firewall, fail2ban, SSH hardening, and other security best practices
- **Containerized**: All services run in Docker containers managed by Portainer
- **Easy Domain Management**: Auto-configured Cloudflare tunnels for your domains
- **Ad-Blocking**: Network-wide ad and malware blocking with Pi-hole
- **Mail Services**: Complete mail solution for websites to use in contact forms
- **Monitoring Stack**: Full observability with Grafana, Prometheus, Loki, Tempo, and more
- **Modular Installation**: Install only the components you need
- **Multi-Architecture Support**: Works on Raspberry Pi, x86, ARM, and more
- **Configurable IP**: Easy to adapt to different network setups

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/nahuelsantos/dinky-server.git
   cd dinky-server
   ```

2. Initialize the environment:
   ```bash
   sudo ./scripts/initialize.sh
   ```

3. Configure your environment:
   ```bash
   cp .env.example .env
   # Edit .env file with your settings
   ```

4. Run the installation script:
   ```bash
   sudo ./scripts/install.sh
   ```

5. Test your installation:
   ```bash
   sudo ./scripts/test.sh
   ```

## Using Make Commands

Dinky Server provides convenient make commands for common tasks:

```bash
# Initialize the environment
make setup

# Install the server
make install

# Test the installation
make test

# Comprehensive testing
make test-all

# Mail service management
make mail-start
make mail-stop
make mail-restart
make mail-logs
```

For a full list of available commands, run:

```bash
make help
```

## Installation Options

The installation script allows you to selectively install components:

- **Security**: Firewall, fail2ban, SSH hardening, and more
- **Core Infrastructure**: Traefik, Cloudflared, Pi-hole, Portainer
- **Mail Services**: Mail server and API for sending emails
- **Websites**: nahuelsantos.com, loopingbyte.com, and configurable for other sites
- **Monitoring Stack**: Prometheus, Grafana, Loki, Tempo, and more

You can run the installer in different modes:

```bash
# Interactive mode (recommended for first-time users)
sudo ./scripts/install.sh

# Non-interactive mode (uses saved configuration)
sudo ./scripts/install.sh --auto

# Display help
sudo ./scripts/install.sh --help
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

### Monitoring Stack

- **Prometheus**: Metrics collection and storage
- **Loki**: Log aggregation system
- **Grafana**: Visualization and dashboards
- **Tempo**: Distributed tracing
- **Pyroscope**: Continuous profiling
- **OpenTelemetry Collector**: Telemetry processing

### Websites

- **nahuelsantos.com**: Personal website
- **loopingbyte.com**: Business website
- **Custom Sites**: Easy to add your own websites

## Documentation

All documentation is available in our [GitHub Wiki](https://github.com/nahuelsantos/dinky-server/wiki):

- **Getting Started**
  - [System Overview](wiki_content/System-Overview.md)
  - [Installation Guide](wiki_content/Installation-Guide.md)
  - [Environment Variables](wiki_content/Environment-Variables.md)
  - [System Dependencies](wiki_content/System-Dependencies.md)

- **Services**
  - [Mail Service](wiki_content/Mail-Service.md)
  - [Traffic Management](wiki_content/Traffic-Management.md)
  - [Monitoring Stack](wiki_content/Monitoring-Stack.md)

- **Development & Deployment**
  - [Local Development](wiki_content/Local-Development.md)
  - [Deployment Guide](wiki_content/Deployment-Guide.md)
  - [Troubleshooting](wiki_content/Troubleshooting.md)

## Directory Structure

```
dinky-server/
├── apis/            # API services (mail-api, etc.)
├── infrastructure/  # Core infrastructure components
│   ├── traefik/     # Reverse proxy configuration
│   ├── cloudflared/ # Secure tunneling
│   ├── pihole/      # Ad blocking
│   └── firewall/    # Security configuration
├── monitoring/      # Monitoring stack
├── services/        # Background services (mail-server, etc.)
├── sites/           # Website configurations
├── scripts/         # Utility scripts
├── wiki_content/    # Documentation files
├── install.sh       # Main installation script
├── initialize.sh    # Initialization script
├── test.sh          # Testing script
└── docker-compose.yml # Core services configuration
```

## Hardware Requirements

- **Minimum**: Raspberry Pi 4 (4GB RAM) or equivalent
- **Recommended**: Raspberry Pi 4 (8GB RAM) or any x86 system with 4+ cores and 8GB+ RAM
- **Storage**: 32GB+ SD card or SSD
- **Network**: Wired Ethernet connection recommended

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
