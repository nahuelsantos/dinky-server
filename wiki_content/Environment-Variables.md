This document provides a comprehensive list of all environment variables used in Dinky Server, organized by service.

## Core Variables

These variables are used across multiple services or affect the entire system.

| Variable | Description | Default Value | Required |
|----------|-------------|---------------|----------|
| `PROJECT` | Name of the project for Docker images | `dinky` | Yes |
| `REGISTRY` | Docker registry for images | `nahuelsantos` | Yes |
| `TAG` | Version tag for Docker images | `latest` | Yes |
| `DOMAIN_NAME` | Primary domain for the server | - | Yes |
| `BASE_DOMAIN` | Base domain for subdomain services | - | Yes |

## Domain Configuration

Variables that affect domain and hostname settings.

| Variable | Description | Default Value | Required |
|----------|-------------|---------------|----------|
| `ALLOWED_HOSTS` | Comma-separated list of allowed domains | - | Yes |
| `API_URL` | Domain for API services | `api.yourdomain.com` | Yes |

## Mail Service Variables

Variables specific to the mail services.

| Variable | Description | Default Value | Required |
|----------|-------------|---------------|----------|
| `MAIL_DOMAIN` | Domain used for email addresses | - | Yes |
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
| `SMTP_RELAY_USERNAME` | Gmail username | - | Yes |
| `SMTP_RELAY_PASSWORD` | Gmail app password | - | Yes |
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

These variables are typically set in each website's .env.prod file.

| Variable | Description | Default Value | Required |
|----------|-------------|---------------|----------|
| `SITE_DOMAIN` | Domain for the website | - | Yes |
| `SITE_EMAIL` | Contact email for the website | - | Yes |
| `MAIL_API_URL` | URL for the mail API | `http://mail-api:20001/send` | Yes |

## Environment File Locations

Dinky Server uses multiple environment files in different locations:

| File | Purpose | Location |
|------|---------|----------|
| `.env` | Main environment file | `/path/to/dinky-server/.env` |
| `.env.example` | Template for main environment | `/path/to/dinky-server/.env.example` |
| `.env.mail.prod` | Production mail settings | `/path/to/dinky-server/services/.env.mail.prod` |
| `.env.mail` | Template for mail settings | `/path/to/dinky-server/services/.env.mail` |
| `.env.prod` | Website-specific settings | `/path/to/dinky-server/sites/[site-name]/.env.prod` |

## Managing Environment Variables

### Creating Environment Files

Copy example files to create your environment files:

```bash
# Main environment file
cp .env.example .env

# Mail service environment file
cp services/.env.mail services/.env.mail.prod
```

### Updating Variables

Edit the files directly:

```bash
nano .env
nano services/.env.mail.prod
```

Or use the environment manager script:

```bash
./scripts/environment-manager.sh update-env main DOMAIN_NAME=yourdomain.com
./scripts/environment-manager.sh update-env mail MAIL_DOMAIN=yourdomain.com
```

### Listing Environment Files

```bash
./scripts/environment-manager.sh list-env
```

## Security Considerations

When working with environment variables:

1. **Never commit environment files with sensitive values to version control**
2. **Use strong, unique passwords for all services**
3. **Restrict access to environment files on your server**
4. **Consider using a secrets management solution for production**

## Examples

### Minimal .env File

```
PROJECT=dinky
REGISTRY=nahuelsantos
TAG=latest
DOMAIN_NAME=example.com
MAIL_DOMAIN=example.com
BASE_DOMAIN=example.com
API_URL=api.example.com
ALLOWED_HOSTS=example.com
```

### Mail Service Example

```
MAIL_DOMAIN=example.com
MAIL_HOSTNAME=mail.example.com
MAIL_USER=admin
MAIL_PASSWORD=secure-password-here
DEFAULT_FROM=hi@example.com
FORWARD_EMAIL=your-personal-email@gmail.com

# Gmail SMTP Relay
SMTP_RELAY_HOST=smtp.gmail.com
SMTP_RELAY_PORT=587
SMTP_RELAY_USERNAME=your-gmail@gmail.com
SMTP_RELAY_PASSWORD=your-app-password
USE_TLS=yes
TLS_VERIFY=yes
``` 