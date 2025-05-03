# Installation Guide

This guide walks you through the process of installing Dinky Server on your hardware.

## Prerequisites

Before you begin, make sure you have:

- A Raspberry Pi 4 (4GB+ RAM) or any compatible Linux system
- A wired network connection (recommended)
- A microSD card (32GB+ recommended) or SSD
- Basic knowledge of Linux terminal commands
- SSH access to your server

## Hardware Recommendations

- **CPU**: 4+ cores recommended
- **RAM**: 4GB minimum, 8GB+ recommended
- **Storage**: 32GB+ with good read/write speeds
- **Network**: Wired Ethernet connection

## Operating System

Dinky Server is designed to work on Raspberry Pi OS (Debian-based) or any Debian/Ubuntu based distribution. We recommend:

- Raspberry Pi OS 64-bit (for Raspberry Pi 4)
- Ubuntu Server 22.04 LTS or newer (for other hardware)

## Installation Steps

### 1. Prepare Your System

Update your system and install Git:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y git curl
```

### 2. Clone the Repository

```bash
git clone https://github.com/nahuelsantos/dinky-server.git
cd dinky-server
```

### 3. Initialize the Environment

The initialization script will create necessary directories and set proper permissions:

```bash
sudo ./initialize.sh
```

### 4. Configure Your Environment

Copy the example environment file and edit it with your settings:

```bash
cp .env.example .env
nano .env
```

Key settings to update:

- `DOMAIN_NAME`: Your primary domain name
- `MAIL_DOMAIN`: Domain for your mail server
- `TUNNEL_ID` and `TUNNEL_TOKEN`: Your Cloudflare tunnel credentials
- `PIHOLE_PASSWORD`: Password for Pi-hole admin interface
- `GRAFANA_PASSWORD`: Password for Grafana admin interface

### 5. Run the Installation Script

The installation script provides an interactive menu to select which components you want to install:

```bash
sudo ./install.sh
```

Follow the prompts to configure your installation. You can choose to install:

- Security components (firewall, fail2ban, etc.)
- Core infrastructure (Traefik, Cloudflared, Pi-hole, Portainer)
- Mail services
- Websites (nahuelsantos.com, loopingbyte.com)
- Monitoring stack

### 6. Test Your Installation

After installation completes, run the test script to verify everything is working correctly:

```bash
sudo ./test.sh
```

This script will check all installed components and report any issues.

## Non-Interactive Installation

For automated deployments, you can use the `--auto` flag:

```bash
sudo ./install.sh --auto
```

This will use either a previously saved configuration or the default settings.

## Accessing Your Services

After installation, you can access your services at:

- **Portainer**: http://your-server-ip:9000
- **Traefik Dashboard**: http://your-server-ip:20000
- **Pi-hole Admin**: http://your-server-ip:19999
- **Grafana**: http://your-server-ip:3000

## Security Considerations

- The installation script sets up basic security measures
- SSH keys are highly recommended instead of password authentication
- Consider setting up automatic security updates
- Review the firewall rules to ensure they meet your needs

## Troubleshooting

If you encounter issues during installation:

1. Check the logs in the terminal for error messages
2. Verify that all required ports are available
3. Ensure Docker is running correctly with `sudo systemctl status docker`
4. Check service status with `docker ps`
5. Review individual service logs with `docker logs <container-name>`

For more detailed troubleshooting, see the [Troubleshooting](./Troubleshooting) wiki page.

## Next Steps

After installation, you may want to:

- [Configure mail services](./Mail-Service)
- [Set up additional websites](./Traffic-Management)
- [Customize monitoring dashboards](./Monitoring-Stack)
- [Enable automatic backups](./Backup-and-Recovery)

## Updating Dinky Server

To update your installation to the latest version:

1. Stop all services:
   ```bash
   docker compose down
   ```

2. Pull the latest changes:
   ```bash
   git pull
   ```

3. Reinitialize the environment:
   ```bash
   sudo ./initialize.sh
   ```

4. Run the installation script again:
   ```bash
   sudo ./install.sh
   ```

This will update all components while preserving your configuration. 