# Dinky Server

A complete self-hosted server solution for home and small business use.

## Overview

Dinky Server is a comprehensive self-hosted solution that combines multiple open-source tools to provide:

- Website and web application hosting
- Email sending and receiving
- Ad blocking
- Container management
- Traffic routing and SSL termination
- Server monitoring
- Secure remote access

## Documentation

**All documentation has moved to our [GitHub Wiki](https://github.com/nahuelsantos/dinky-server/wiki).**

Please visit our Wiki for complete documentation on:

- [Installation Guide](https://github.com/nahuelsantos/dinky-server/wiki/Installation-Guide)
- [Local Development](https://github.com/nahuelsantos/dinky-server/wiki/Local-Development)
- [Deployment Guide](https://github.com/nahuelsantos/dinky-server/wiki/Deployment-Guide)
- [Mail Service](https://github.com/nahuelsantos/dinky-server/wiki/Mail-Service)
- [Troubleshooting](https://github.com/nahuelsantos/dinky-server/wiki/Troubleshooting)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/nahuelsantos/dinky-server.git
cd dinky-server

# Configure environment
cp .env.example .env
# Edit .env file with your settings

# Start the server locally
./scripts/deploy-local.sh
```

## Features

- **Traefik**: Reverse proxy and SSL termination
- **Cloudflared**: Secure tunneling for remote access
- **Pi-hole**: Network-wide ad blocking
- **Portainer**: Docker container management
- **Mail Server**: Complete email solution with web interface
- **Monitoring Stack**: Prometheus, Grafana, and Node Exporter
- **API**: RESTful API for service management

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 