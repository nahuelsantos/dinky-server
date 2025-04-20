# Dinky Server - Secure Home Server Setup

This repository contains configuration and setup scripts for Dinky, a secure self-hosted server for home use. It includes web proxying, DNS-level ad blocking, container management, and comprehensive security measures.

## Directory Structure

The repository is organized into these key directories:

```
dinky-server/
├── apis/            # API services (mail-api, etc.)
├── infrastructure/  # Core infrastructure components
│   ├── traefik/     # Reverse proxy and load balancer
│   ├── cloudflared/ # Secure tunneling to Cloudflare
│   ├── portainer/   # Docker container management
│   ├── pihole/      # Network-wide ad blocking
│   └── firewall/    # Security and firewall configuration
├── monitoring/      # Monitoring stack (LGTM)
├── services/        # Background services (mail-server, etc.)
├── sites/           # Website configurations
└── scripts/         # Utility scripts
```

## System Components

### Infrastructure Components

- **[Traefik](infrastructure/traefik/README.md)**: Routes incoming traffic to appropriate services
  - Provides HTTPS termination
  - Routes based on domain name
  - Internal dashboard available at 192.168.3.2:8080

- **[Cloudflared](infrastructure/cloudflared/README.md)**: Secure tunneling service
  - Exposes select services to the internet without opening ports
  - Uses Cloudflare's network for DDoS protection

- **[Portainer](infrastructure/portainer/README.md)**: Docker container management
  - Web UI available at 192.168.3.2:9000
  - Manages container deployments
  - Monitors container health and resource usage

- **[Pi-hole](infrastructure/pihole/README.md)**: Network-wide ad blocking
  - DNS-level ad and tracker blocking
  - Web UI available at 192.168.3.2:8081/admin
  - Acts as the network's DNS server

### Services

- **[Mail Services](services/README.mail.md)**: Self-hosted mail for contact forms
  - Includes SMTP server and HTTP API
  - Supports Gmail relay for better deliverability

### Monitoring Stack (LGTM)

- **[Monitoring Overview](monitoring/README.md)**: Comprehensive observability suite
  - Loki: Log aggregation system
  - Grafana: Visualization dashboard
  - Tempo: Distributed tracing system
  - Prometheus: Metrics collection
  - Pyroscope: Continuous profiling
  - OpenTelemetry Collector: Telemetry processing

## Setup and Deployment

### Initial Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/dinky-server.git
   cd dinky-server
   ```

2. Create and customize your `.env` file:
   ```bash
   cp .env.example .env
   nano .env  # Edit with your values
   ```

3. Start the main services:
   ```bash
   docker compose up -d
   ```

### Service-Specific Deployment

Each component has its own deployment instructions. See the relevant documentation:

- [Mail Services Deployment](services/README.mail.md)
- [Monitoring Stack Setup](monitoring/README.md)
- [Website Deployment Guide](sites/README.md)

## Security Measures

Dinky employs multiple layers of security:

- Restrictive firewall rules with UFW
- All management interfaces bind only to internal IP (192.168.3.2)
- SSH hardening with key-based authentication
- Intrusion detection and prevention with Fail2Ban

For more details, see the [Security Documentation](infrastructure/firewall/README.md).

## License

This project is licensed under the MIT License - see the LICENSE file for details.
