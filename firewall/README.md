# Server Security Setup

This directory contains scripts for securing your Dinky server with a comprehensive security setup.

## Files Overview

### Base Security:
- `setup-firewall.sh`: Configures the UFW firewall rules
- `security-check.sh`: Performs regular security audits
- `setup-cron.sh`: Sets up automated security checks

### Additional Security Measures:
- `setup-fail2ban.sh`: Installs and configures Fail2Ban for intrusion prevention
- `setup-ssh-keys.sh`: Secures SSH by enforcing key-based authentication
- `setup-docker-security.sh`: Enhances Docker security with best practices
- `setup-logwatch.sh`: Sets up log monitoring with Logwatch
- `setup-auto-updates.sh`: Configures automatic security updates

### Master Script:
- `master-security-setup.sh`: A comprehensive script that installs and configures all security measures

## Quick Setup

For a complete security installation, run:

```bash
sudo bash firewall/master-security-setup.sh
```

This will guide you through the installation of all security components.

## Individual Components

If you prefer to install components individually:

### Basic Firewall Setup

```bash
sudo bash firewall/setup-firewall.sh
```

This will:
- Block all incoming connections by default
- Allow outgoing connections by default
- Restrict administrative services to local network only
- Allow Pi-hole DNS service from local network only
- Allow HTTP/HTTPS traffic for external requests
- Rate limit SSH connections to prevent brute force attacks

### Intrusion Prevention with Fail2Ban

```bash
sudo bash firewall/setup-fail2ban.sh
```

This will:
- Install and configure Fail2Ban
- Set up SSH protection against brute force attacks
- Configure web server authentication protection

### Secure SSH Access

**WARNING**: Before running this script, ensure you have set up SSH key-based authentication!

```bash
sudo bash firewall/setup-ssh-keys.sh
```

This will:
- Disable password authentication for SSH
- Disable root login
- Use only strong ciphers and algorithms
- Limit login attempts

### Docker Security Enhancements

```bash
sudo bash firewall/setup-docker-security.sh
```

This will:
- Set up a Docker socket proxy for safer container access
- Configure Docker daemon security settings
- Provide a Docker security audit tool

### Log Monitoring

```bash
sudo bash firewall/setup-logwatch.sh
```

This will:
- Install and configure Logwatch
- Set up daily log analysis and reporting
- Add Docker-specific log monitoring

### Automatic Updates

```bash
sudo bash firewall/setup-auto-updates.sh
```

This will:
- Configure automatic security updates
- Set up Docker image update checks
- Create a system update utility

## Security Checks

### Automated Daily Security Checks

Once set up, security checks run automatically at 2 AM daily.
Results are logged to `/var/log/security-check.log`

### Manual Security Audit

You can manually run a security check at any time:

```bash
sudo bash firewall/security-check.sh
```

## Docker Security Audit

After installing the Docker security enhancements:

```bash
sudo /opt/docker-security/docker-security-audit.sh
```

## Manual System Update

To update your entire system including Docker images:

```bash
sudo system-update
```

## Customizing Rules

If you add new services or need to modify access rules, edit the appropriate script and run it again to apply changes. 