# Deployment Guide

This guide will walk you through deploying your Dinky Server in a production environment.

## Prerequisites

Before deploying to production, ensure you have:

- A server with Docker and Docker Compose installed
- A domain name with DNS access
- SSL certificates (or ability to use Let's Encrypt)
- Sufficient server resources (recommended: at least 2GB RAM, 20GB storage)

## Preparing for Deployment

### Domain Configuration

1. Set up DNS records for your domain:
   - A record: `yourdomain.com` → Your server's IP
   - A record: `*.yourdomain.com` → Your server's IP (for subdomains)
   - MX record: `yourdomain.com` → `mail.yourdomain.com` (priority 10)
   - TXT record: `yourdomain.com` → `v=spf1 mx ~all` (for SPF)
   - DKIM and DMARC records (optional but recommended)

### Environment Setup

1. Copy and configure the environment file:
   ```bash
   cp .env.example .env.prod
   ```

2. Edit the production environment variables:
   ```bash
   # Domain configuration
   DOMAIN=yourdomain.com
   MAIL_DOMAIN=yourdomain.com
   MAIL_HOSTNAME=mail.yourdomain.com
   DEFAULT_FROM=hi@yourdomain.com
   
   # Set strong passwords
   MAIL_ADMIN_PASSWORD=strong-unique-password
   GRAFANA_PASSWORD=strong-unique-password
   PORTAINER_PASSWORD=strong-unique-password
   
   # Configure Cloudflared (if using)
   CLOUDFLARED_TOKEN=your-cloudflare-tunnel-token
   ```

## Deployment Process

### Basic Infrastructure Deployment

```bash
./scripts/deploy-prod.sh
```

This script will:
1. Set up Traefik as a reverse proxy
2. Configure SSL with Let's Encrypt
3. Deploy Pi-hole for ad blocking
4. Set up Portainer for container management

### Mail Service Deployment

```bash
./scripts/deploy-mail-prod.sh
```

### Monitoring Stack Deployment

```bash
./scripts/deploy-monitoring-prod.sh
```

## Post-Deployment Verification

### Verifying Services

Check that all services are running:
```bash
docker ps
```

### Testing Email Functionality

Send a test email:
```bash
curl -X POST https://mail-api.yourdomain.com/api/v1/send \
  -H "Content-Type: application/json" \
  -d '{
    "to": "your-email@example.com",
    "subject": "Test Email",
    "text": "This is a test email from your Dinky Server."
  }'
```

### Security Checks

1. Verify SSL certificates are valid:
   ```bash
   curl -vI https://yourdomain.com
   ```

2. Check for open ports:
   ```bash
   nmap -p 1-1000 yourdomain.com
   ```

3. Ensure authentication is required for all admin interfaces

## Maintenance

### Backups

Set up regular backups for:
- Mail data: `/var/lib/docker/volumes/dinky_mail_data`
- Configuration files
- Databases

### Updates

To update your Dinky Server:

```bash
git pull
./scripts/deploy-prod.sh
```

## Troubleshooting

For common deployment issues and their solutions, refer to the [Troubleshooting](Troubleshooting) page. 