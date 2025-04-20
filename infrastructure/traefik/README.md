# Traefik Reverse Proxy

This directory contains configuration files for Traefik, the reverse proxy and load balancer used in the Dinky Server setup.

## Overview

Traefik serves as the entry point for all HTTP/HTTPS traffic to your services. It handles:

- Automatic SSL certificate generation via Let's Encrypt
- Routing requests to the appropriate service
- HTTP to HTTPS redirection
- Access control and rate limiting
- Dashboard for monitoring

## Directory Structure

- `traefik.yml` - Main Traefik configuration
- `config/` - Dynamic configuration
  - `middlewares.yml` - HTTP middleware configurations
  - `tls.yml` - TLS certificate configuration
- `data/` - Persistent data
  - `acme.json` - Let's Encrypt certificates (generated automatically)
- `docker-compose.yml` - Docker Compose file for Traefik

## Setup Instructions

### Quick Start

Deploy Traefik using the Makefile from the root directory:

```bash
make deploy-traefik
```

### Manual Deployment

If you prefer to deploy manually:

1. Create the external network:
   ```bash
   docker network create web
   ```

2. Create the required directories:
   ```bash
   mkdir -p ./data
   touch ./data/acme.json
   chmod 600 ./data/acme.json
   ```

3. Start Traefik:
   ```bash
   docker-compose up -d
   ```

## Configuration

### Main Configuration (traefik.yml)

The `traefik.yml` file contains the static configuration, including:

- EntryPoints (ports, TLS settings)
- API and dashboard settings
- Certificate resolvers
- Provider configurations

### Dynamic Configuration

The `config/` directory contains dynamic configuration files:

- `middlewares.yml`: Defines HTTP middlewares like:
  - Security headers
  - Rate limiting
  - Compression
  - Authentication
  - IP whitelisting

- `tls.yml`: TLS options and configurations

## Creating Routes for Services

To add a new service to Traefik, use Docker labels in your service's Docker Compose file:

```yaml
services:
  my-service:
    # ... service config ...
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-service.rule=Host(`service.example.com`)"
      - "traefik.http.routers.my-service.entrypoints=websecure"
      - "traefik.http.routers.my-service.tls.certresolver=letsencrypt"
      - "traefik.http.services.my-service.loadbalancer.server.port=8080"
    networks:
      - web
      - default

networks:
  web:
    external: true
```

## Accessing the Dashboard

The Traefik dashboard is available at `https://your-server-ip:8080/dashboard/` and is secured with the credentials specified in your configuration.

Default restrictions limit dashboard access to:
- Local access only (127.0.0.1)
- Specific IP addresses you've configured
- Basic authentication (if configured)

## Customization

### Custom Certificates

If you need to use your own certificates:

1. Place your certificates in `./data/certs/`
2. Update the `tls.yml` file to reference your certificates
3. Update your router configuration to use the custom certificate

### Advanced Middlewares

Common middleware configurations included:

- **Security Headers**: Adds security-related HTTP headers
- **Rate Limiting**: Prevents abuse by limiting request rates
- **IP Filtering**: Restricts access based on source IP address
- **Compression**: Compresses HTTP responses
- **Basic Auth**: Simple authentication for services

## Troubleshooting

### Checking Logs

View Traefik logs for debugging:

```bash
docker logs -f traefik
```

### Common Issues

- **Certificate Generation Failures**: Check that `acme.json` has the correct permissions (600)
- **Routing Issues**: Ensure your network configurations match and containers are on the `web` network
- **Dashboard Access Problems**: Verify IP restrictions and authentication credentials 