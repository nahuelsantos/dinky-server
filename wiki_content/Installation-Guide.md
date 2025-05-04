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

### 1. Run the Initialization Script

First, run the initialization script to prepare your environment:

```bash
sudo ./scripts/initialize.sh
```

This script will:
- Ensure required packages are installed
- Set up Docker if not already installed
- Create necessary directories
- Configure initial settings

### 2. Configure Your Environment

Copy the example environment file and customize it:

```bash
cp .env.example .env
```

Edit the `.env` file with your information:
```bash
# Set your domain information
DOMAIN_NAME=yourdomain.com
MAIL_DOMAIN=yourdomain.com
MAIL_HOSTNAME=mail.yourdomain.com

# Configure passwords
PIHOLE_PASSWORD=choose-a-secure-password
GRAFANA_PASSWORD=choose-a-secure-password

# For Gmail SMTP relay (recommended)
SMTP_RELAY_USERNAME=your-gmail-account@gmail.com
SMTP_RELAY_PASSWORD=your-app-password-without-spaces
```

> **Important note about Gmail App Passwords**: When using a Gmail app password, you must enter it without spaces. For example, if Google shows "XXXX XXXX XXXX XXXX", enter it as "XXXXXXXXXXXXXXXX" in your .env file.

### 3. Run the Installation Script

Next, run the main installation script:

```bash
sudo ./scripts/install.sh
```

This script will guide you through the installation process interactively.

### 4. Test Your Installation

After installation completes, run the test script to verify everything is working correctly:

```bash
sudo ./scripts/test.sh
```

This script will check all installed components and report any issues.

For more comprehensive testing, you can use:

```bash
sudo ./scripts/test-all-components.sh
```

This script includes more detailed tests and has options for testing specific components:

```bash
# Test only mail services
sudo ./scripts/test-all-components.sh --mail --verbose

# Test core infrastructure with extra details
sudo ./scripts/test-all-components.sh --core --verbose

# See all available options
sudo ./scripts/test-all-components.sh --help
```

## Non-Interactive Installation

For automated deployments, you can use the `--auto` flag:

```bash
sudo ./scripts/install.sh --auto
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

For more detailed troubleshooting, see the [Troubleshooting](Troubleshooting.md) wiki page.

## Next Steps

After installation, you may want to:

- [Configure mail services](Mail-Service.md)
- [Set up additional websites](Traffic-Management.md)
- [Customize monitoring dashboards](Monitoring-Stack.md)
- [Enable automatic backups](Backup-and-Recovery.md)

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
   sudo ./scripts/initialize.sh
   ```

4. Run the installation script again:
   ```bash
   sudo ./scripts/install.sh
   ```

This will update all components while preserving your configuration. 