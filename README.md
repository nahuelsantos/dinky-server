# Dinky Server - Secure Home Server Setup

This repository contains configuration and setup scripts for Dinky, a secure self-hosted server for home use. It includes web proxying, DNS-level ad blocking, container management, and comprehensive security measures.

## Architecture Overview

Dinky server is built on a modular architecture using Docker containers:

- **Traefik**: Reverse proxy and SSL termination
- **Cloudflared**: Secure tunneling to Cloudflare's network
- **Pi-hole**: Network-wide ad blocking DNS server
- **Portainer**: Docker container management UI

The system is secured with multiple layers of protection including firewall rules, intrusion detection, automatic updates, and secure access controls.

## System Components

### Network Infrastructure

- **Traefik**: Routes incoming traffic to appropriate services
  - Provides HTTPS termination
  - Routes based on domain name
  - Internal dashboard available at 192.168.3.2:8080

- **Cloudflared**: Secure tunneling service
  - Exposes select services to the internet without opening ports
  - Uses Cloudflare's network for DDoS protection
  - Configured to handle domains in `cloudflared/config.yml`

### Management Tools

- **Portainer**: Docker container management
  - Web UI available at 192.168.3.2:9000
  - Manages container deployments
  - Monitors container health and resource usage

### Network Services

- **Pi-hole**: Network-wide ad blocking
  - DNS-level ad and tracker blocking
  - Web UI available at 192.168.3.2:8081/admin
  - Acts as the network's DNS server

## Security Measures

Dinky includes a comprehensive security framework that can be set up using the master script:
```bash
sudo bash firewall/master-security-setup.sh
```

### Firewall Protection (UFW)

- Default-deny incoming connections
- Restrict administrative interfaces to local network
- Rate-limit SSH connections to prevent brute force attacks
- Allow necessary service ports (DNS, HTTP, HTTPS)

### Intrusion Prevention (Fail2Ban)

- Monitors for brute force login attempts
- Automatically bans suspicious IP addresses
- Protects SSH and web authentication endpoints

### Access Security

- SSH hardening with key-based authentication
- Strong cipher configurations
- Root login disabled
- Login attempt limitations

### Docker Security

- Limited container capabilities (principle of least privilege)
- Docker daemon security configuration
- Docker socket access controls
- Container resource limitations

### Automated Monitoring

- Regular security checks run daily
- System health monitoring
- Log analysis with Logwatch
- Docker container activity tracking

### Automatic Updates

- Automatic security updates for the system
- Scheduled Docker image updates
- Regular cleanup of unused resources

## Installation and Setup

### Prerequisites

Before proceeding with installation, ensure you have:
- A Debian/Ubuntu based system
- Internet connectivity
- SSH access to the server

### Basic System Setup

1. Install basic tools:
```bash
sudo apt install neovim git zsh
```

2. Install Powerlevel10k (optional but recommended):
```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
```
Open ~/.zshrc, find the line that sets ZSH_THEME, and change its value to "powerlevel10k/powerlevel10k".

3. Set up shell environment (optional but recommended):
```bash
# Make zsh the default shell
sudo chsh -s "$(command -v zsh)" "${USER}"

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Add plugins for better experience
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting

# Edit .zshrc and set: plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
```

4. Install Docker:
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER # Log out and back in after this
sudo apt install -y libffi-dev libssl-dev python3-pip
```

5. Set up the firewall:
```bash
sudo apt install ufw
sudo bash firewall/setup-firewall.sh
```

6. Create Docker network:
```bash
docker network create traefik_network
```

### Service Deployment

1. Configure environment variables:
   - Edit the `.env` file to set your credentials and configuration
   - Ensure `PIHOLE_PASSWORD` is set to a secure value

2. Set up Cloudflared:
   - Configure `cloudflared/config.yml` with your domains and routes

3. Launch the system:
```bash
docker compose up -d
```

## Administration and Maintenance

### Security Maintenance

- Run security checks: `sudo bash firewall/security-check.sh`
- Update system and containers: `sudo system-update`
- View security logs: `cat /var/log/security-check.log`

### DNS Administration

- Access Pi-hole admin interface at http://192.168.3.2:8081/admin
- Configure client devices to use 192.168.3.2 as their DNS server
- Customize blocklists in Pi-hole admin interface

### Container Management

- Access Portainer at http://192.168.3.2:9000
- Monitor container health and resource usage
- Update container images and configurations

## Troubleshooting

### DNS Issues

If DNS resolution fails:
- Check if Pi-hole container is running
- Verify Pi-hole configuration
- Docker uses external DNS (1.1.1.1 and 8.8.8.8) to avoid dependency cycles

### Docker Startup Problems

If Docker services won't start:
- Check `/etc/docker/daemon.json` configuration
- Ensure there's no conflicting userns-remap settings
- Verify Docker DNS settings are properly configured

## License

This project is licensed under the MIT License - see the LICENSE file for details.
