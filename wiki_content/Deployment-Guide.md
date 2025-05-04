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
   cp .env.example .env
   ```

2. Edit the environment variables:
   ```bash
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
   SERVER_IP=your-server-ip
   TZ=UTC

   # Mail Server Configuration
   MAIL_USER=admin
   MAIL_PASSWORD=your-secure-mail-password
   DEFAULT_FROM=hi@yourdomain.com
   FORWARD_EMAIL=your-personal-email@example.com
   MAIL_HOSTNAME=mail.yourdomain.com
   MAIL_SECURE=false
   MAIL_PORT=25

   # SMTP Relay Configuration (Gmail)
   SMTP_RELAY_HOST=smtp.gmail.com
   SMTP_RELAY_PORT=587
   SMTP_RELAY_USERNAME=your-gmail-username@gmail.com
   SMTP_RELAY_PASSWORD=your-gmail-app-password-without-spaces
   USE_TLS=yes
   TLS_VERIFY=yes

   # Pi-hole settings
   PIHOLE_PASSWORD=your-pihole-password

   # Grafana settings
   GRAFANA_PASSWORD=your-grafana-password

   # Cloudflared settings (if using)
   TUNNEL_ID=your-cloudflare-tunnel-id
   TUNNEL_TOKEN=your-cloudflare-tunnel-token
   ```

   > **Important Note About Gmail App Passwords**: When using a Gmail app password, you must enter it without spaces. For example, if Google shows "XXXX XXXX XXXX XXXX", enter it as "XXXXXXXXXXXXXXXX" in your .env file.

## Deployment Process

### Installation Script

The easiest way to deploy is to use the installation script:

```bash
sudo ./scripts/install.sh
```

This will guide you through the installation process interactively. You can also use non-interactive mode:

```bash
sudo ./scripts/install.sh --auto
```

### Manual Deployment

If you prefer to deploy manually:

```bash
# Deploy core services
docker compose up -d

# Restart mail services if needed
docker compose restart mail-server mail-api
```

## Post-Deployment Verification

### Verifying Services

Check that all services are running:
```bash
docker ps
```

You can also use the test script:
```bash
sudo ./scripts/test.sh
```

For a more comprehensive test:
```bash
sudo ./scripts/test-all-components.sh
```

### Testing Email Functionality

Send a test email:
```bash
sudo ./scripts/send-test-email.sh your-email@example.com
```

### Security Checks

1. Verify SSL certificates are valid:
   ```bash
   curl -vI https://yourdomain.com
   ```

2. Check for open ports:
   ```bash
   sudo nmap -p 1-1000 localhost
   ```

3. Ensure authentication is required for all admin interfaces

## Maintenance

### Backups

Set up regular backups for Docker volumes:
```bash
# Example backup script
docker run --rm -v dinky_mail-data:/source -v /backup:/backup alpine tar -czf /backup/mail-data-$(date +%Y%m%d).tar.gz -C /source ./
```

### Updates

To update your Dinky Server:

```bash
git pull
make install
```

## Troubleshooting

For common deployment issues and their solutions, refer to the [Troubleshooting](Troubleshooting.md) page. 