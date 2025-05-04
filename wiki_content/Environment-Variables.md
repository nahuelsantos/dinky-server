This document provides a comprehensive list of all environment variables used in Dinky Server, organized by service.

## Core Variables

These variables are used across multiple services or affect the entire system.

| Variable | Description | Default Value | Required |
|----------|-------------|---------------|----------|
| `PROJECT` | Name of the project for Docker images | `dinky` | Yes |
| `REGISTRY` | Docker registry for images | `yourregistry` | Yes |
| `TAG` | Version tag for Docker images | `latest` | Yes |
| `DOMAIN_NAME` | Primary domain for the server | - | Yes |
| `BASE_DOMAIN` | Base domain for subdomain services | - | Yes |
| `SERVER_IP` | Server IP address | `127.0.0.1` | Yes |
| `TZ` | Timezone | `UTC` | Yes |

## Domain Configuration

Variables that affect domain and hostname settings.

| Variable | Description | Default Value | Required |
|----------|-------------|---------------|----------|
| `ALLOWED_HOSTS` | Comma-separated list of allowed domains | `yourdomain.com,api.yourdomain.com` | Yes |
| `API_URL` | Domain for API services | `api.yourdomain.com` | Yes |

## Mail Service Variables

Variables specific to the mail services.

| Variable | Description | Default Value | Required |
|----------|-------------|---------------|----------|
| `MAIL_DOMAIN` | Domain used for email addresses | `yourdomain.com` | Yes |
| `MAIL_HOSTNAME` | FQDN for the mail server | `mail.yourdomain.com` | Yes |
| `MAIL_USER` | Admin username for mail server | `admin` | Yes |
| `MAIL_PASSWORD` | Admin password for mail server | - | Yes |
| `DEFAULT_FROM` | Default sender address | `hi@yourdomain.com` | Yes |
| `FORWARD_EMAIL` | Address to forward incoming emails to | - | No |
| `MAIL_SECURE` | Use SSL/TLS for mail connections | `false` | No |
| `MAIL_PORT` | SMTP port for mail server | `25` | No |

### Gmail SMTP Relay Configuration

| Variable | Description | Default Value | Required for Gmail Relay |
|----------|-------------|---------------|--------------------------|
| `SMTP_RELAY_HOST` | SMTP relay hostname | `smtp.gmail.com` | Yes |
| `SMTP_RELAY_PORT` | SMTP relay port | `587` | Yes |
| `SMTP_RELAY_USERNAME` | Gmail username | `your-gmail-username@gmail.com` | Yes |
| `SMTP_RELAY_PASSWORD` | Gmail app password (no spaces) | - | Yes |
| `USE_TLS` | Enable TLS for SMTP relay | `yes` | Yes |
| `TLS_VERIFY` | Verify TLS certificates | `yes` | Yes |

## Cloudflared Variables

Variables for Cloudflare Tunnel.

| Variable | Description | Default Value | Required |
|----------|-------------|---------------|----------|
| `TUNNEL_ID` | Cloudflare Tunnel ID | - | Yes |
| `TUNNEL_TOKEN` | Cloudflare Tunnel token | - | Yes |

## Pi-hole Variables

| Variable | Description | Default Value | Required |
|----------|-------------|---------------|----------|
| `PIHOLE_PASSWORD` | Admin password for Pi-hole | - | Yes |

## Grafana Variables

| Variable | Description | Default Value | Required |
|----------|-------------|---------------|----------|
| `GRAFANA_PASSWORD` | Admin password for Grafana | - | Yes |

## Website-Specific Variables

These variables are typically set in each website's environment.

| Variable | Description | Default Value | Required |
|----------|-------------|---------------|----------|
| `SITE_DOMAIN` | Domain for the website | - | Yes |
| `SITE_EMAIL` | Contact email for the website | - | Yes |
| `MAIL_API_URL` | URL for the mail API | `http://mail-api:20001/send` | Yes |

## Environment File Location

Dinky Server uses a single environment file:

| File | Purpose | Location |
|------|---------|----------|
| `.env` | Main environment file | `/path/to/dinky-server/.env` |
| `.env.example` | Template for main environment | `/path/to/dinky-server/.env.example` |

## Managing Environment Variables

### Creating Environment Files

Copy the example file to create your environment file:

```bash
# Main environment file
cp .env.example .env
```

### Updating Variables

Edit the file directly:

```bash
nano .env
```

Or use the environment manager script:

```bash
./scripts/environment-manager.sh update-env main DOMAIN_NAME=yourdomain.com
```

### Listing Environment Variables

```bash
./scripts/environment-manager.sh list-env
```

## Security Considerations

When working with environment variables:

1. **Never commit environment files with sensitive values to version control**
2. **Use strong, unique passwords for all services**
3. **Restrict access to environment files on your server**
4. **Consider using a secrets management solution for production**

## Important Note About Gmail App Passwords

When using Gmail for SMTP relay, make sure to:

1. Enable 2-Step Verification on your Google account
2. Create an App Password specifically for Dinky Server
3. Copy the password without spaces when pasting it into the `.env` file

Example:
```
# This is wrong (with spaces)
SMTP_RELAY_PASSWORD=XXXX XXXX XXXX XXXX

# This is correct (no spaces)
SMTP_RELAY_PASSWORD=XXXXXXXXXXXXXXXX
```

## Example .env File

```
# Project Configuration
PROJECT=dinky
REGISTRY=yourregistry
TAG=latest

# Domain Configuration
DOMAIN_NAME=yourdomain.com
MAIL_DOMAIN=yourdomain.com
BASE_DOMAIN=yourdomain.com
API_URL=api.yourdomain.com
ALLOWED_HOSTS=yourdomain.com,api.yourdomain.com

# Mail Server Configuration
DEFAULT_FROM=hi@yourdomain.com
FORWARD_EMAIL=your-personal-email@example.com
MAIL_HOSTNAME=mail.yourdomain.com

# SMTP Relay Configuration (Gmail)
SMTP_RELAY_HOST=smtp.gmail.com
SMTP_RELAY_PORT=587
SMTP_RELAY_USERNAME=your-gmail-username@gmail.com
SMTP_RELAY_PASSWORD=your-gmail-app-password
USE_TLS=yes
TLS_VERIFY=yes

# Cloudflared settings
TUNNEL_ID=your-tunnel-id-here
TUNNEL_TOKEN=your-tunnel-token-here

# Pihole settings
PIHOLE_PASSWORD=your-pihole-password

# Grafana settings
GRAFANA_PASSWORD=your-grafana-password
``` 