# Local Development

This guide covers setting up and working with Dinky Server in a local development environment.

## Prerequisites

- Docker and Docker Compose installed
- Git installed
- At least 2GB of available RAM
- Basic knowledge of Docker and web development

## Initial Setup

### Clone the Repository

```bash
git clone https://github.com/nahuelsantos/dinky-server.git
cd dinky-server
```

### Configure Environment

Copy the example environment file:

```bash
cp .env.example .env
```

For local development, you can use the default settings or customize as needed.

### Start the Development Environment

```bash
./scripts/deploy-local.sh
```

This script sets up:
- Traefik for routing
- Portainer for container management
- Pi-hole for ad blocking

## Services Development

### Mail Service Development

Start the mail service in development mode:

```bash
./scripts/deploy-mail-local.sh
```

This will start:
- Mail server on port 25 (SMTP) and 143 (IMAP)
- Mail API on port 8025
- Web mail client accessible at http://localhost:8025

#### Testing Mail Functionality

```bash
# Send a test email
curl -X POST http://localhost:8025/api/v1/send \
  -H "Content-Type: application/json" \
  -d '{
    "to": "test@example.com",
    "subject": "Test Email",
    "text": "This is a test email."
  }'
```

### Monitoring Stack Development

Start the monitoring stack:

```bash
./scripts/deploy-monitoring-local.sh
```

Access points:
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

## API Development

### Running API in Development Mode

```bash
cd api
npm install
npm run dev
```

This starts the API with hot-reloading at http://localhost:3000.

## Web Development

If you're developing web applications to be served by Dinky Server:

1. Create your web application in the `sites` directory
2. Configure the routing in `services/docker-compose.traefik.yml`
3. Update your local `/etc/hosts` file to point your development domain to localhost

Example `/etc/hosts` entry:
```
127.0.0.1 mysite.local
```

## Database Development

For local database development:

```bash
docker-compose -f services/docker-compose.db.yml up -d
```

This starts:
- PostgreSQL on port 5432
- MongoDB on port 27017

## Working with Logs

View logs from specific services:

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f mail-server
```

## Troubleshooting

### Common Development Issues

- **Port conflicts**: Check if other applications are using the same ports
- **Container not starting**: Check logs with `docker-compose logs [service_name]`
- **Network issues**: Verify Docker networks with `docker network ls`

### Restarting Services

```bash
# Restart a specific service
docker-compose -f services/docker-compose.mail.yml restart mail-api

# Restart all services
./scripts/deploy-local.sh
```

## Best Practices

- Use volume mounts for development to see changes in real-time
- Commit changes to your `.env` file only if they're general configuration changes
- Use feature branches for development
- Write tests for API endpoints
- Document code changes and new features 