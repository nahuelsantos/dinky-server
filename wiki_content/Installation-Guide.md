This guide walks you through the process of installing and setting up your Dinky Server from scratch.

## System Requirements

- **Operating System**: Ubuntu 20.04 LTS or newer (recommended)
- **RAM**: 2GB minimum, 4GB+ recommended
- **CPU**: 2 cores minimum, 4+ cores recommended
- **Storage**: 20GB minimum, 100GB+ recommended
- **Network**: Static IP address recommended
- **Domain**: At least one domain name (for Traefik and web services)

## Prerequisites

Before installing Dinky Server, you need to prepare your system:

1. Install required packages:

   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y git make curl wget ufw ca-certificates gnupg-agent software-properties-common
   ```

2. Install Docker:

   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   ```

3. Install Docker Compose:

   ```bash
   sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

4. Configure firewall:

   ```bash
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow ssh
   sudo ufw allow http
   sudo ufw allow https
   sudo ufw enable
   ```

5. Create a directory for Dinky Server:

   ```bash
   sudo mkdir -p /opt/dinky-server
   sudo chown $USER:$USER /opt/dinky-server
   ```

## Step 1: Clone the Repository

```bash
git clone https://github.com/nahuelsantos/dinky-server.git /opt/dinky-server
cd /opt/dinky-server
```

## Step 2: Configure Environment Variables

1. Create your main environment file:

   ```bash
   cp .env.example .env
   ```

2. Edit the environment file with your specific settings:

   ```bash
   nano .env
   ```

   At minimum, update these variables:
   
   ```
   PROJECT=dinky
   REGISTRY=yourusername
   TAG=latest
   DOMAIN_NAME=yourdomain.com
   BASE_DOMAIN=yourdomain.com
   API_URL=api.yourdomain.com
   ALLOWED_HOSTS=yourdomain.com
   ```

3. For a complete list of available variables and their meanings, see the [Environment Variables Reference](Environment-Variables).

## Step 3: Deploy Core Infrastructure

Deploy the core infrastructure components (Traefik, Portainer, Pi-hole):

```bash
docker-compose up -d
```

This will start:
- Traefik (reverse proxy)
- Portainer (container management)
- Pi-hole (ad blocking)
- Cloudflared (if configured)

### Verifying Core Services

1. Check that containers are running:

   ```bash
   docker ps
   ```

2. Access Portainer (container management UI):

   ```
   https://portainer.yourdomain.com
   ```

   Or locally: `http://192.168.1.x:9000`

3. Access Pi-hole (ad blocking dashboard):

   ```
   https://pihole.yourdomain.com/admin
   ```

   Or locally: `http://192.168.1.x:8081/admin`

## Step 4: Deploy Mail Services

1. Copy the mail environment template:

   ```bash
   cp services/.env.mail services/.env.mail.prod
   ```

2. Edit the mail configuration:

   ```bash
   nano services/.env.mail.prod
   ```

   Update these values:
   
   ```
   MAIL_DOMAIN=yourdomain.com
   MAIL_HOSTNAME=mail.yourdomain.com
   DEFAULT_FROM=noreply@yourdomain.com
   ALLOWED_HOSTS=yourdomain.com
   ```

3. For detailed instructions, see the [Mail Service](Mail-Service) page.

4. Deploy the mail services:

   ```bash
   docker-compose -f services/docker-compose.mail.prod.yml --env-file services/.env.mail.prod up -d
   ```

## Step 5: Deploy Monitoring Stack (Optional)

1. Configure monitoring settings in your environment file or create a separate one for monitoring.

2. Deploy the monitoring stack:

   ```bash
   docker-compose -f monitoring/docker-compose.yml up -d
   ```

3. Access Grafana:

   ```
   https://grafana.yourdomain.com
   ```

   Default login: admin / (password from your .env file)

## Step 6: Deploy Your Websites

For each website you want to deploy:

1. Use the setup-site.sh script to create a new site configuration:

   ```bash
   ./scripts/setup-site.sh
   ```

   Or manually create a directory for the site:

   ```bash
   mkdir -p sites/your-site-name
   ```

2. Create an environment file:

   ```bash
   cat > sites/your-site-name/.env << EOL
   # Environment for your-site-name
   SITE_DOMAIN=your-site-domain.com
   SITE_EMAIL=hello@your-site-domain.com
   MAIL_API_URL=http://mail-api:20001/send
   EOL
   ```

3. Create a docker-compose.yml for your site:

   ```bash
   nano sites/your-site-name/docker-compose.yml
   ```

   Basic example:
   
   ```yaml
   services:
     your-site-name:
       image: nginx:alpine  # Replace with your site's image
       container_name: your-site-name
       restart: unless-stopped
       networks:
         - traefik_network
         - mail-internal
       env_file:
         - .env
       labels:
         - "traefik.enable=true"
         - "traefik.http.routers.your-site-name.rule=Host(`your-site-domain.com`)"
         - "traefik.http.routers.your-site-name.entrypoints=websecure"
         - "traefik.http.routers.your-site-name.tls=true"
         - "traefik.http.services.your-site-name.loadbalancer.server.port=80"

   networks:
     traefik_network:
       external: true
     mail-internal:
       external: true
       name: services_mail-internal
   ```

4. Deploy your site:

   ```bash
   cd sites/your-site-name
   docker-compose up -d
   ```

## Step 7: Configure DNS

For each service you want to access via a domain name:

1. Add DNS A records pointing to your server's IP address:
   
   ```
   yourdomain.com              A      your.server.ip.address
   www.yourdomain.com          A      your.server.ip.address
   mail.yourdomain.com         A      your.server.ip.address
   api.yourdomain.com          A      your.server.ip.address
   grafana.yourdomain.com      A      your.server.ip.address
   portainer.yourdomain.com    A      your.server.ip.address
   pihole.yourdomain.com       A      your.server.ip.address
   ```

2. For mail server functionality, add MX, SPF, and DKIM records (see [Mail Service](Mail-Service) documentation).

## Step 8: Secure Your Server

1. Set up automatic security updates:

   ```bash
   sudo apt install unattended-upgrades
   sudo dpkg-reconfigure -plow unattended-upgrades
   ```

2. Review firewall rules:

   ```bash
   sudo ufw status
   ```

3. Consider setting up fail2ban for SSH protection:

   ```bash
   sudo apt install fail2ban
   sudo systemctl enable fail2ban
   sudo systemctl start fail2ban
   ```

## Troubleshooting

If you encounter issues during installation:

- Check container logs: `docker logs container_name`
- Verify environment variables are correctly set
- Consult the [Troubleshooting Guide](Troubleshooting)

## Next Steps

- Review the [Production Deployment Checklist](Deployment-Guide)
- Set up [Cloudflare Tunnel](Traffic-Management#cloudflare-tunnel) for secure remote access
- Configure [Monitoring Alerts](Monitoring-Stack#configuring-alerts) 