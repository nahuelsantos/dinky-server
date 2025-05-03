Dinky Server provides comprehensive traffic management capabilities through several key components. This page covers how traffic is routed, secured, and optimized in your Dinky Server installation.

## Traefik Reverse Proxy

Traefik serves as the main entry point for all traffic to your Dinky Server services, providing:

- Automatic SSL certificate management
- Traffic routing to the appropriate service
- Load balancing
- HTTP to HTTPS redirection
- Access control and authentication

### Accessing Traefik Dashboard

The Traefik dashboard is available at:

```
https://traefik.yourdomain.com
```

You'll need to authenticate with the credentials specified in your `.env` file under `TRAEFIK_DASHBOARD_USER` and `TRAEFIK_DASHBOARD_PASSWORD`.

### Adding a New Route

To add a new service behind Traefik:

1. Add the following labels to your service in the docker-compose file:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myservice.rule=Host(`myservice.yourdomain.com`)"
  - "traefik.http.routers.myservice.entrypoints=websecure"
  - "traefik.http.routers.myservice.tls.certresolver=letsencrypt"
```

2. Update your DNS to point `myservice.yourdomain.com` to your server's IP address
3. Restart the service or run `docker compose up -d`

## Cloudflare Tunnel

Cloudflare Tunnel provides secure remote access to your Dinky Server without opening ports on your router:

- End-to-end encrypted tunnels
- No need to expose your home IP address
- DDoS protection through Cloudflare
- Access controls via Cloudflare Zero Trust

### Setting Up Cloudflare Tunnel

1. Configure your Cloudflare credentials in the `.env` file
2. Start the cloudflared service:
   ```bash
   docker compose -f infrastructure/docker-compose.cloudflared.yml up -d
   ```
3. Configure services to route through the tunnel in `cloudflared/config.yml`

### Managing Access

Configure access policies through the Cloudflare Zero Trust dashboard to control who can access your services.

## Ad Blocking

Dinky Server includes Pi-hole for network-wide ad blocking:

- DNS-level ad blocking
- Blocks tracking domains
- Reduces bandwidth usage
- Improves browsing speed

### Pi-hole Administration

Access the Pi-hole admin interface at:

```
https://pihole.yourdomain.com
```

The password is specified in your `.env` file under `PIHOLE_ADMIN_PASSWORD`.

### Customizing Block Lists

1. Log in to the Pi-hole admin interface
2. Navigate to "Adlists"
3. Add additional block lists or whitelist specific domains as needed

## Configuration Files

Key configuration files for traffic management:

- `infrastructure/traefik/traefik.yml`: Main Traefik configuration
- `infrastructure/traefik/dynamic/`: Dynamic Traefik configurations
- `infrastructure/cloudflared/config.yml`: Cloudflare Tunnel configuration
- `infrastructure/pihole/custom.list`: Custom DNS entries for Pi-hole

## Troubleshooting

### SSL Certificate Issues

If you're having trouble with SSL certificates:

1. Check Traefik logs:
   ```bash
   docker logs dinky_traefik
   ```

2. Verify that your DNS is correctly configured
3. Ensure port 80 and 443 are open and forwarding to your server

### Connectivity Issues

If services are not accessible:

1. Check if Traefik is correctly routing to your service:
   - Review Traefik dashboard for the router
   - Verify service labels are correct

2. For Cloudflare Tunnel issues:
   - Check cloudflared logs:
     ```bash
     docker logs dinky_cloudflared
     ```
   - Verify tunnel is connected in the Cloudflare Zero Trust dashboard

## Related Documentation

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Troubleshooting Guide](Troubleshooting#traffic-management) 