# Server Security Setup

This directory contains scripts for securing your Dinky server with UFW (Uncomplicated Firewall).

## Files Overview

- `setup-firewall.sh`: Configures the UFW firewall rules
- `security-check.sh`: Performs regular security audits
- `setup-cron.sh`: Sets up automated security checks

## Initial Setup

Run this command to set up the firewall and automated security checks:

```bash
sudo bash firewall/setup-cron.sh
```

This will:
1. Configure the firewall rules
2. Schedule daily security checks
3. Make all scripts executable

## Firewall Rules

The firewall is configured with these key principles:
- Block all incoming connections by default
- Allow outgoing connections by default
- Restrict administrative services (SSH, Portainer, Traefik dashboard) to local network only
- Allow Pi-hole DNS service from local network only
- Allow HTTP/HTTPS traffic for Traefik to handle external requests
- Rate limit SSH connections to prevent brute force attacks

## Security Checks

The automated security check will:
- Verify firewall status
- Check for failed SSH login attempts
- Monitor for unusual open ports
- Check Docker container status
- Monitor disk usage
- Check for available system updates

Results are logged to `/var/log/security-check.log`

## Manual Security Audit

You can manually run a security check at any time:

```bash
sudo bash firewall/security-check.sh
```

## Customizing Rules

If you add new services or need to modify access rules, edit the `setup-firewall.sh` script and run it again to apply changes. 