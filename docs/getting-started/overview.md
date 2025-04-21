# Dinky Server Overview

Dinky Server is a comprehensive self-hosted server solution designed for home and small business use. It combines multiple open-source tools into a cohesive, easy-to-deploy platform.

## What is Dinky Server?

Dinky Server provides a suite of services bundled together with Docker Compose, allowing you to:

- Host multiple websites on a single server
- Block ads and trackers network-wide with Pi-hole
- Manage your Docker containers with Portainer
- Route traffic securely with Traefik
- Send emails from your websites with a built-in mail service
- Monitor your server with a comprehensive monitoring stack
- Access your services securely from anywhere with Cloudflare Tunnels

## System Architecture

Dinky Server is organized into several interconnected components:

```
┌───────────────────┐     ┌───────────────────┐     ┌───────────────────┐
│                   │     │                   │     │                   │
│  Traefik          │◄────┤  Your Websites    │────►│  Mail Services    │
│  (Reverse Proxy)  │     │                   │     │                   │
│                   │     └───────────────────┘     └───────────────────┘
└─────────┬─────────┘                                        ▲
          │                                                  │
          │                                                  │
          │                                                  │
┌─────────▼─────────┐     ┌───────────────────┐             │
│                   │     │                   │             │
│  Cloudflared      │     │  Pi-hole          │             │
│  (Tunneling)      │     │  (Ad Blocking)    │             │
│                   │     │                   │             │
└───────────────────┘     └───────────────────┘             │
                                                            │
                          ┌───────────────────┐             │
                          │                   │             │
                          │  Portainer        │             │
                          │  (Container Mgmt) │             │
                          │                   │             │
                          └───────────────────┘             │
                                                            │
                          ┌───────────────────┐             │
                          │                   │             │
                          │  Monitoring Stack │─────────────┘
                          │  (LGTM)           │
                          │                   │
                          └───────────────────┘
```

## Key Components

### Infrastructure

- **Traefik**: Reverse proxy and load balancer, routes traffic to the appropriate service
- **Cloudflared**: Secure tunneling service, exposes services to the internet without opening ports
- **Pi-hole**: Network-wide ad and tracker blocking
- **Portainer**: Docker container management with a web interface

### Services

- **Mail Services**: Send emails from your websites, with support for Gmail SMTP relay
- **Monitoring Stack**: Comprehensive monitoring with Loki, Grafana, Tempo, and Prometheus

### Your Content

- **Websites**: Host multiple websites, each in its own container
- **APIs**: Develop and deploy your own APIs

## Getting Started

To get started with Dinky Server, follow these steps:

1. Review the [Installation Guide](installation.md)
2. Set up your [Environment Variables](environment-variables.md)
3. Deploy your first services using the [Mail Service Setup Guide](../services/mail/setup.md)
4. Explore the [Local Development Guide](../developer-guide/local-development.md) for testing

## Who is Dinky Server For?

Dinky Server is ideal for:

- Self-hosting enthusiasts who want to run their own websites and services
- Small businesses or freelancers who need email and web hosting
- Developers who want a consistent environment for development and production
- Anyone looking to reduce their reliance on third-party services

## Next Steps

- See the [Installation Guide](installation.md) to set up your own Dinky Server
- Explore the [Services Documentation](../services) to learn about each component
- Check out the [Developer Guide](../developer-guide) for local development and customization 