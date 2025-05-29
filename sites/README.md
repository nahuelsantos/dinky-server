# Sites Directory

This directory contains website and web application services that will be automatically discovered and deployed by the Dinky Server deployment script.

## How It Works

The deployment script (`deploy.sh`) automatically scans this directory for:
- Subdirectories containing `docker-compose.yml` or `docker-compose.yaml` files
- Each discovered site is offered for deployment during the setup process

## Example Structure

```
sites/
├── blog/
│   ├── docker-compose.yml
│   ├── .env (optional)
│   └── content/ (your blog content)
├── portfolio/
│   ├── docker-compose.yml
│   └── public/
├── company-website/
│   ├── docker-compose.yaml
│   ├── Dockerfile
│   └── src/
└── documentation/
    ├── docker-compose.yml
    └── docs/
```

## Requirements

Each site service should:
1. Have a `docker-compose.yml` file in its root directory
2. Use the `traefik_network` for Traefik integration (if needed)
3. Include appropriate labels for Traefik routing (if using reverse proxy)
4. Expose services on unique ports to avoid conflicts

## Example docker-compose.yml

```yaml
version: '3.8'

services:
  my-website:
    image: nginx:alpine
    container_name: my-website
    restart: unless-stopped
    ports:
      - "3010:80"
    volumes:
      - ./public:/usr/share/nginx/html:ro
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-website.rule=Host(`example.com`)"
      - "traefik.http.services.my-website.loadbalancer.server.port=80"

networks:
  traefik_network:
    external: true
```

## Common Site Types

### Static Sites
```yaml
services:
  static-site:
    image: nginx:alpine
    volumes:
      - ./dist:/usr/share/nginx/html:ro
```

### Node.js Applications
```yaml
services:
  node-app:
    image: node:18-alpine
    working_dir: /app
    volumes:
      - ./:/app
    command: npm start
```

### WordPress Sites
```yaml
services:
  wordpress:
    image: wordpress:latest
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: password
  
  db:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: password
      MYSQL_ROOT_PASSWORD: rootpassword
```

## Deployment

Sites in this directory are automatically discovered when you run:

```bash
sudo ./deploy.sh
```

The script will:
1. Scan this directory recursively
2. Find all docker-compose files
3. List discovered sites
4. Ask if you want to deploy them
5. Deploy selected services with proper network configuration

## Domain Configuration

For external access, configure your domains to point to your server:

### Option 1: Cloudflare Tunnel (Recommended)
- No port forwarding required
- Automatic SSL certificates
- DDoS protection included

### Option 2: Traditional DNS + Port Forwarding
- Point your domain A record to your public IP
- Forward ports 80 and 443 to your server
- Configure SSL certificates (Let's Encrypt recommended)

## Environment Variables

If your site needs environment variables:
1. Create a `.env` file in the site directory, or
2. The deployment script will copy the main `.env` file if needed

## SSL/TLS Configuration

When using Traefik with external domains:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.my-site.rule=Host(`example.com`)"
  - "traefik.http.routers.my-site.entrypoints=websecure"
  - "traefik.http.routers.my-site.tls.certresolver=letsencrypt"
```

## Notes

- Each site should use unique ports to avoid conflicts
- Sites are deployed in the order they're discovered
- Failed deployments don't stop the overall process
- You can redeploy individual sites by running the deployment script again
- Consider using a CDN for better performance and caching 