# Dinky Server Security & Firewall

This directory contains scripts and configurations for securing your Dinky server. These security measures include firewall configuration, SSH hardening, intrusion prevention, and more.

## Security Features

### Network Security
- **Restrictive Firewall Rules**: Only necessary ports are opened
- **Management Interface Restrictions**: Admin interfaces only bind to internal IP (192.168.3.2)
- **SSH Hardening**: Secure SSH configuration with key-based authentication
- **Intrusion Prevention**: Fail2Ban configuration to block malicious IPs

### Container Security
- **Docker Daemon Hardening**: Security settings for Docker
- **Resource Limits**: Container resource limitations
- **Non-root Containers**: Services run as non-root where possible
- **Read-only Filesystems**: Used where appropriate

### Monitoring & Auditing
- **Automated Security Checks**: Regular security audits
- **Container Audit**: Docker container monitoring
- **Log Monitoring**: Continuous log analysis

## Setup Instructions

### Initial Firewall Setup

Run the master security setup script:

```bash
sudo ./master-security-setup.sh
```

This script will:
1. Configure UFW firewall rules
2. Set up Fail2Ban for intrusion prevention
3. Harden SSH configuration
4. Set up automated security updates
5. Configure basic logging and monitoring

### Docker Security Setup

To secure the Docker daemon:

```bash
sudo ./setup-docker-security.sh
```

### Periodic Security Checks

Run the security check script periodically:

```bash
./security-check.sh
```

## Firewall Rules

| Port | Protocol | Source | Description |
|------|----------|--------|-------------|
| 22   | TCP      | Limited IPs | SSH (rate-limited by Fail2Ban) |
| 53   | TCP/UDP  | Internal network | DNS (Pi-hole) |
| 80   | TCP      | Local only | HTTP (redirected to HTTPS) |
| 443  | TCP      | All | HTTPS (Traefik) |
| 8080 | TCP      | 192.168.3.2 only | Traefik dashboard |
| 9000 | TCP      | 192.168.3.2 only | Portainer UI |
| 8081 | TCP      | 192.168.3.2 only | Pi-hole Admin |
| 3000 | TCP      | 192.168.3.2 only | Grafana |
| 9090 | TCP      | 192.168.3.2 only | Prometheus |

## SSH Key Setup

To set up SSH keys for secure access:

1. Generate a new SSH key pair (on your local machine):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/dinky_ed25519
   ```

2. Copy the public key to the server:
   ```bash
   ssh-copy-id -i ~/.ssh/dinky_ed25519 user@dinky-server
   ```

3. Run the SSH hardening script:
   ```bash
   sudo ./setup-ssh-keys.sh
   ```

## Log Monitoring

Logs are monitored using Logwatch and sent to the administrator email. Configure Logwatch:

```bash
sudo ./setup-logwatch.sh
```

## Automatic Updates

Security updates are installed automatically. Configure auto-updates:

```bash
sudo ./setup-auto-updates.sh
```

## Custom Security Configuration

To customize the security settings, edit the appropriate configuration files before running the setup scripts. 