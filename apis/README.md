# APIs Directory

This directory contains API services that will be automatically discovered and deployed by the Dinky Server deployment script.

## How It Works

The deployment script (`deploy.sh`) automatically scans this directory for:
- Subdirectories containing `docker-compose.yml` or `docker-compose.yaml` files
- Each discovered service is offered for deployment during the setup process

## Example Structure

```
apis/
├── user-api/
│   ├── docker-compose.yml
│   ├── .env (optional)
│   └── src/ (your API code)
├── payment-api/
│   ├── docker-compose.yml
│   └── config/
└── notification-service/
    ├── docker-compose.yaml
    └── Dockerfile
```

## Requirements

Each API service should:
1. Have a `docker-compose.yml` file in its root directory
2. Use the `traefik_network` for Traefik integration (if needed)
3. Include appropriate labels for Traefik routing (if using reverse proxy)
4. Expose services on unique ports to avoid conflicts

## Example docker-compose.yml

```yaml
version: '3.8'

services:
  my-api:
    image: my-api:latest
    container_name: my-api
    restart: unless-stopped
    ports:
      - "3001:3000"
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-api.rule=Host(`api.example.com`)"
      - "traefik.http.services.my-api.loadbalancer.server.port=3000"
    environment:
      - NODE_ENV=production

networks:
  traefik_network:
    external: true
```

## Deployment

APIs in this directory are automatically discovered when you run:

```bash
sudo ./deploy.sh
```

The script will:
1. Scan this directory recursively
2. Find all docker-compose files
3. List discovered APIs
4. Ask if you want to deploy them
5. Deploy selected services with proper network configuration

## Environment Variables

If your API needs environment variables:
1. Create a `.env` file in the API directory, or
2. The deployment script will copy the main `.env` file if needed

## Notes

- Each API should use unique ports to avoid conflicts
- Services are deployed in the order they're discovered
- Failed deployments don't stop the overall process
- You can redeploy individual APIs by running the deployment script again 