# Installation Guide

This guide will walk you through the process of installing and setting up your Dinky Server environment.

## Prerequisites

Before you begin, ensure you have the following:

- A Linux, macOS, or Windows system with:
  - Docker and Docker Compose installed
  - Git installed
  - At least 2GB of RAM and 10GB of storage space
- Domain name (for production deployments)
- Basic knowledge of command-line operations

## Quick Installation

### Clone the Repository

```bash
git clone https://github.com/nahuelsantos/dinky-server.git
cd dinky-server
```

### Set Up Environment Variables

Copy the example environment file and edit it according to your needs:

```bash
cp .env.example .env
```

Edit the `.env` file to configure your settings:

```bash
# Use your favorite text editor
nano .env
```

Key configurations to update:
- Domain names
- Email addresses
- Service-specific settings

### Deploy the Basic Stack

```bash
docker-compose up -d
```

This will:
1. Build necessary Docker images
2. Create required networks
3. Start the core services

## Post-Installation

After installation, you can access:

- Traefik Dashboard: http://localhost:8080
- Portainer: http://localhost:9000
- Pi-hole: http://localhost:8081/admin

## Next Steps

After installation:
1. [Set up local development](Local-Development)
2. [Configure mail services](Mail-Service)
3. [Set up monitoring](Monitoring-Stack)

## Troubleshooting

If you encounter issues during installation:

- Check Docker status: `docker ps`
- View service logs: `docker-compose logs [service_name]`
- Ensure ports aren't already in use
- Verify environment variables are set correctly

For more detailed troubleshooting, see the [Troubleshooting](Troubleshooting) page. 