# Production Deployment Checklist

Use this checklist to ensure a smooth and secure deployment of your Dinky Server in production.

## Pre-Deployment Planning

- [ ] Determine your domain(s) configuration
- [ ] Plan your server hardware resources (CPU, RAM, storage)
- [ ] Choose your hosting provider
- [ ] Set up Cloudflare account (if using Cloudflare Tunnels)
- [ ] Identify which services you'll need
- [ ] Create a Gmail account for SMTP relay (recommended)

## Server Setup

- [ ] Provision a server with Ubuntu 20.04 or newer
- [ ] Set a strong root password
- [ ] Create a non-root user with sudo access
- [ ] Update the system:
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```
- [ ] Install required packages:
  ```bash
  sudo apt install -y git make curl wget ufw ca-certificates gnupg-agent software-properties-common
  ```
- [ ] Install Docker and Docker Compose:
  ```bash
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  ```
- [ ] Configure UFW firewall:
  ```bash
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw allow http
  sudo ufw allow https
  sudo ufw enable
  ```

## Dinky Server Installation

- [ ] Clone the repository:
  ```bash
  git clone https://github.com/yourusername/dinky-server.git /opt/dinky-server
  cd /opt/dinky-server
  ```

- [ ] Create and configure environment files:
  ```bash
  cp .env.example .env
  nano .env  # Edit with your values
  ```

- [ ] Configure mail service:
  ```bash
  cp services/.env.mail services/.env.mail.prod
  nano services/.env.mail.prod  # Edit with your values
  ```

- [ ] Deploy core services:
  ```bash
  docker-compose up -d
  ```

## Mail Service Deployment

- [ ] Check that no other mail service is running:
  ```bash
  sudo netstat -tulpn | grep :25
  # If needed, stop and disable the service
  sudo systemctl stop exim4
  sudo systemctl disable exim4
  ```

- [ ] Configure Gmail SMTP relay:
  - [ ] Enable 2-Step Verification on your Google account
  - [ ] Create an App Password
  - [ ] Update the SMTP relay settings in services/.env.mail.prod

- [ ] Deploy mail services:
  ```bash
  docker-compose -f services/docker-compose.mail.prod.yml --env-file services/.env.mail.prod up -d
  ```

- [ ] Verify services are running:
  ```bash
  docker ps | grep mail
  ```

- [ ] Test email functionality:
  ```bash
  docker exec mail-server echo "This is a test" | mail -s "Test Email" your-test-email@example.com
  ```

## Website Deployment

For each website you want to deploy:

- [ ] Create site directory and configuration:
  ```bash
  mkdir -p /opt/dinky-server/sites/your-site-name
  ```

- [ ] Create environment file:
  ```bash
  cat > /opt/dinky-server/sites/your-site-name/.env.prod << EOL
  # Production Environment for your-site-name
  SITE_DOMAIN=your-domain.com
  SITE_EMAIL=hello@your-domain.com
  MAIL_API_URL=http://mail-api:20001/send
  EOL
  ```

- [ ] Create docker-compose.yml:
  ```bash
  nano /opt/dinky-server/sites/your-site-name/docker-compose.yml
  ```

- [ ] Deploy the website:
  ```bash
  cd /opt/dinky-server/sites/your-site-name
  docker-compose up -d
  ```

## Monitoring Setup

- [ ] Configure monitoring environment variables:
  ```bash
  nano monitoring/.env.monitoring
  ```

- [ ] Deploy monitoring stack:
  ```bash
  docker-compose -f monitoring/docker-compose.yml --env-file monitoring/.env.monitoring up -d
  ```

- [ ] Verify Grafana is accessible:
  ```bash
  curl -I http://localhost:3000
  ```

## DNS Configuration

- [ ] Configure A/AAAA records for your domain(s)
- [ ] Set up CNAME records for any subdomains
- [ ] Configure MX records if using the mail server for receiving email

## SSL Certificates

If not using Cloudflare Tunnels:

- [ ] Install Certbot:
  ```bash
  sudo apt install -y certbot
  ```

- [ ] Obtain SSL certificates:
  ```bash
  sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com
  ```

- [ ] Set up auto-renewal:
  ```bash
  sudo systemctl status certbot.timer
  ```

## Security Checks

- [ ] Verify firewall is active:
  ```bash
  sudo ufw status
  ```

- [ ] Check for exposed ports:
  ```bash
  sudo netstat -tulpn
  ```

- [ ] Ensure SSH is properly secured:
  ```bash
  sudo nano /etc/ssh/sshd_config
  ```
  
  Recommended settings:
  ```
  PermitRootLogin no
  PasswordAuthentication no
  PubkeyAuthentication yes
  ```

- [ ] Set up fail2ban (optional):
  ```bash
  sudo apt install -y fail2ban
  sudo systemctl enable fail2ban
  sudo systemctl start fail2ban
  ```

## Final Verification

- [ ] Test all websites from a browser
- [ ] Test contact forms on all websites
- [ ] Verify emails are being delivered
- [ ] Check Grafana dashboards
- [ ] Verify Pi-hole is blocking ads
- [ ] Ensure Traefik is routing traffic correctly

## Backup Configuration

- [ ] Set up automated backups of:
  - [ ] Docker volumes (especially mail data)
  - [ ] Environment files
  - [ ] Configuration files
  - [ ] SSL certificates

- [ ] Test backup restoration

## Documentation

- [ ] Document your specific deployment configuration
- [ ] Record any custom settings or modifications
- [ ] Create recovery procedures
- [ ] Document regular maintenance tasks

## Maintenance Plan

- [ ] Schedule regular updates
- [ ] Set up monitoring alerts
- [ ] Create a maintenance calendar
- [ ] Document escalation procedures

## Troubleshooting Resources

If you encounter issues during deployment, refer to:

- [Mail Services Troubleshooting](../services/mail/troubleshooting.md)
- [General Troubleshooting](../admin-guide/troubleshooting.md)

For additional help, check the GitHub repository issues or contact the maintainers. 