# APIs Directory

This directory contains API services that are **automatically discovered** and can be deployed by the Dinky Server deployment system.

## 🚀 Unified Architecture

Dinky Server uses a **single unified script** for all operations:

**`dinky.sh`** - Complete system setup and service deployment

## How Auto-Discovery Works

The `dinky.sh` script automatically scans this directory for:
- Subdirectories containing `docker-compose.yml` or `docker-compose.yaml` files
- Each discovered service can be deployed individually or as part of a full deployment

## 🎯 Deployment Options

### **Full Setup (New Server)**
```bash
sudo ./dinky.sh
# Choose option 1: Full Setup (System + Services)
```

### **Deploy Services Only**
```bash
sudo ./dinky.sh
# Choose option 3: Deploy Services Only
```

### **Individual API Deployment**
```bash
sudo ./dinky.sh
# Choose option 4: Add Individual Service → API
```

### **Discover New Services**
```bash
sudo ./dinky.sh
# Choose option 6: Discover New Services
```

### **List All Services**
```bash
sudo ./dinky.sh
# Choose option 7: List All Services
```

## Example Structure

```
apis/
├── user-api/
│   ├── docker-compose.yml
│   ├── .env (optional)
│   ├── Dockerfile
│   └── src/ (your API code)
├── payment-api/
│   ├── docker-compose.yml
│   ├── config/
│   └── app/
├── notification-service/
│   ├── docker-compose.yaml
│   ├── Dockerfile
│   └── handlers/
└── example-api/              # Included example
    ├── docker-compose.yml
    ├── main.go
    └── README.md
```

## Requirements for Auto-Discovery

Each API service should:

1. **Have a docker-compose file** in its root directory (`docker-compose.yml` or `docker-compose.yaml`)
2. **Use unique ports** to avoid conflicts (recommended: 3005+ for new APIs)
3. **Include `traefik_network`** for reverse proxy integration (if needed)
4. **Proper Traefik labels** for routing (if using external access)

## Example docker-compose.yml

### **Basic API Setup**
```yaml
services:
  my-api:
    image: my-api:latest
    container_name: my-api
    restart: unless-stopped
    ports:
      - "3005:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
    networks:
      - traefik_network

networks:
  traefik_network:
    external: true
```

### **API with Traefik Integration**
```yaml
services:
  my-api:
    image: my-api:latest
    container_name: my-api
    restart: unless-stopped
    ports:
      - "3005:3000"
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-api.rule=Host(`api.${DOMAIN_NAME}`)"
      - "traefik.http.services.my-api.loadbalancer.server.port=3000"
      - "traefik.http.routers.my-api.tls=true"
    environment:
      - NODE_ENV=production

networks:
  traefik_network:
    external: true
```

### **API with Database**
```yaml
services:
  my-api:
    image: my-api:latest
    container_name: my-api
    restart: unless-stopped
    ports:
      - "3005:3000"
    depends_on:
      - my-api-db
    environment:
      - DATABASE_URL=postgresql://user:pass@my-api-db:5432/myapi
    networks:
      - traefik_network
      - my-api-network

  my-api-db:
    image: postgres:15-alpine
    container_name: my-api-db
    restart: unless-stopped
    environment:
      - POSTGRES_DB=myapi
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - my-api-data:/var/lib/postgresql/data
    networks:
      - my-api-network

volumes:
  my-api-data:

networks:
  traefik_network:
    external: true
  my-api-network:
    driver: bridge
```

## 🔧 Environment Variables

The deployment script handles environment variables automatically:

### **Automatic Environment Copy**
If your API uses environment variables (`${VARIABLE_NAME}` in docker-compose.yml), the deployment script will:
1. Check for a local `.env` file in the API directory
2. If not found, copy the main `.env` file from the root

### **API-Specific Environment**
Create a `.env` file in your API directory for service-specific variables:

```bash
# apis/my-api/.env
DATABASE_URL=postgresql://localhost:5432/myapi
API_KEY=your-secret-key
LOG_LEVEL=debug
```

### **Using Root Environment**
Your API can use variables from the root `.env` file:
- `SERVER_IP` - Server IP address
- `DOMAIN_NAME` - Domain for routing
- `TZ` - Timezone setting
- Custom variables you add

## 🎮 Usage Examples

### **Adding a New API**

1. **Create API directory**:
```bash
mkdir -p apis/my-new-api
cd apis/my-new-api
```

2. **Create docker-compose.yml**:
```yaml
services:
  my-new-api:
    image: node:18-alpine
    container_name: my-new-api
    restart: unless-stopped
    ports:
      - "3005:3000"
    working_dir: /app
    volumes:
      - ./src:/app
    command: npm start
    networks:
      - traefik_network
networks:
  traefik_network:
    external: true
```

3. **Deploy the API**:
```bash
sudo ./dinky.sh
# Choose option 4: Add Individual Service → API
```

### **Managing Existing APIs**

```bash
# List all APIs with status
sudo ./dinky.sh
# Choose option 7: List All Services

# Deploy only new APIs
sudo ./dinky.sh
# Choose option 6: Discover New Services

# Check API logs
docker compose logs -f my-api

# Restart specific API
docker compose restart my-api
```

## 🔍 Port Management

### **Current Port Allocations**

**Core Infrastructure:**
- `80` - Traefik HTTP (internal)
- `443` - Traefik HTTPS (internal) 
- `53` - Pi-hole DNS (TCP/UDP)
- `25, 587` - Mail SMTP
- `8080` - Traefik Dashboard
- `8081` - Pi-hole Admin
- `9000` - Portainer

**LGTM Monitoring Stack:**
- `3000` - Grafana
- `3100` - Loki
- `3200` - Tempo
- `4040` - Pyroscope
- `4317` - OTEL Collector (OTLP gRPC) - **Use this for apps**
- `4318` - OTEL Collector (OTLP HTTP) - **Use this for apps**
- `4316` - Tempo OTLP (external) - **Direct access, use otel-collector instead**
- `8082` - cAdvisor
- `8888` - OTEL Collector metrics
- `9090` - Prometheus
- `9100` - Node Exporter

**Example Services:**
- `3001` - Argus (LGTM Stack Validator)
- `3002` - Dinky Dashboard (Advanced observability dashboard)  
- `3003` - Example API (Simple REST API)
- `3004` - Example Site (Simple static site)

### **Recommended Port Ranges**
- **3005-3099**: Custom APIs
- **3100+**: Reserved for monitoring services

### **Port Conflict Resolution**
If you get port conflicts:
1. Check existing services: `docker compose ps`
2. Update your API's port mapping
3. Redeploy: `sudo ./dinky.sh
# Choose option 4: Add Individual Service → API`

## 🚨 Troubleshooting

### **API Not Discovered**
```bash
# Check if docker-compose.yml exists
ls apis/my-api/docker-compose.yml

# Validate docker-compose syntax
cd apis/my-api && docker compose config
```

### **Deployment Fails**
```bash
# Check deployment logs
tail -f /var/log/dinky.log

# Check API-specific logs
cd apis/my-api && docker compose logs
```

### **Network Issues**
```bash
# Verify traefik_network exists
docker network ls | grep traefik

# Recreate if missing
docker network create traefik_network
```

## 📊 Monitoring Integration

APIs are automatically integrated with the monitoring stack:

### **OpenTelemetry Support**
If your API supports OpenTelemetry, add these environment variables:
```yaml
environment:
  - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
  - OTEL_SERVICE_NAME=my-api
  - OTEL_RESOURCE_ATTRIBUTES=service.version=1.0.0
```

### **Prometheus Metrics**
For Prometheus metrics collection, expose metrics endpoint:
```yaml
labels:
  - "prometheus.io/scrape=true"
  - "prometheus.io/port=3000"
  - "prometheus.io/path=/metrics"
```

## 🔗 Integration with Main Services

### **Database Access**
APIs can connect to shared databases or create their own:

```yaml
# Connect to shared PostgreSQL
environment:
  - DATABASE_URL=postgresql://user:pass@postgres:5432/shared_db

# Or create dedicated database
services:
  api-db:
    image: postgres:15-alpine
    # ... database configuration
```

### **Service Discovery**
APIs can communicate with each other using container names:
```yaml
environment:
  - USER_API_URL=http://user-api:3000
  - PAYMENT_API_URL=http://payment-api:3000
```

## 📄 Example API Templates

Check the `example-api/` directory for:
- Go API with OpenTelemetry integration
- Monitoring and metrics endpoints
- Proper Traefik configuration
- Environment variable usage examples

## 🎯 Example API References

### **Simple Example API** (port 3003)
The included `example-api` provides a basic REST API demonstration:
- `GET /health` - Health check endpoint
- `GET /hello` - Hello world endpoint  
- `GET /users` - Sample users list


### **LGTM Stack Testing** (external tool)
For LGTM stack testing, use **Argus**: https://github.com/nahuelsantos/argus

```bash
docker run -p 3001:3001 ghcr.io/nahuelsantos/argus:v0.0.1
```
# Generate test metrics
curl http://localhost:3001/generate-metrics

# Generate test logs
curl http://localhost:3001/generate-logs
```

## 🎯 Best Practices

1. **Use semantic versioning** for your API images
2. **Include health checks** in your docker-compose
3. **Set proper restart policies** (`unless-stopped`)
4. **Use dedicated networks** for database connections
5. **Include logging configuration** for centralized logs
6. **Document your API** in the service directory README

## Notes

- **Port uniqueness**: Each API must use unique ports to avoid conflicts
- **Automatic discovery**: New APIs are found on every deployment scan
- **Individual management**: APIs can be deployed, updated, or removed independently
- **Environment inheritance**: APIs inherit environment variables from the main `.env` file
- **Network integration**: All APIs join the `traefik_network` for reverse proxy access 

# APIs Guide

This guide covers the APIs available in Dinky Server and how to add your own.

## Overview

Dinky Server provides several example APIs to demonstrate different patterns and use cases:

- **Example API** - Simple REST API example
- **User Service** - User management API example

## LGTM Stack Testing
For more information, visit: https://github.com/nahuelsantos/argus

## Example API

The Example API demonstrates basic REST API patterns and can be used as a template for building your own APIs.

### Endpoints

- `GET /` - API information
- `GET /health` - Health check
- `GET /api/users` - List users
- `POST /api/users` - Create user

### Usage

```bash
# Check API health
curl http://localhost:3003/health

# List users
curl http://localhost:3003/api/users
```

## User Service

The User Service provides user management functionality.

### Endpoints

- `GET /` - Service information
- `GET /health` - Health check
- `GET /users` - List all users
- `GET /users/:id` - Get user by ID
- `POST /users` - Create new user
- `PUT /users/:id` - Update user
- `DELETE /users/:id` - Delete user

### Usage

```bash
# Create a user
curl -X POST http://localhost:3005/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'

# Get all users
curl http://localhost:3005/users
```

## Development

### Adding New APIs

1. Create a new directory under `apis/`
2. Add your API code
3. Create a `docker-compose.yml` file
4. Update the main `docker-compose.yml` to include your API
5. Add documentation to this guide

### Best Practices

- Use proper HTTP status codes
- Implement health checks
- Add proper error handling
- Use structured logging
- Implement rate limiting for production
- Add authentication/authorization as needed

## API Structure

Each API should follow this structure:

```
apis/my-api/
├── docker-compose.yml    # Service definition
├── Dockerfile           # Custom image (if needed)
├── src/                 # Source code
├── README.md           # API documentation
└── .env               # Environment variables (auto-copied)
```

## Docker Compose Template

Here's a basic template for API services:

```yaml
services:
  my-api:
    build: .
    container_name: my-api
    restart: unless-stopped
    ports:
      - "3005:3000"  # External:Internal
    environment:
      - NODE_ENV=production
      - API_PORT=3000
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-api.rule=Host(`api.${DOMAIN_NAME}`)"
      - "traefik.http.services.my-api.loadbalancer.server.port=3000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  traefik_network:
    external: true
```

## Monitoring Integration

APIs are automatically integrated with the monitoring stack:

### OpenTelemetry Support

If your API supports OpenTelemetry, add these environment variables:

```yaml
environment:
  - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
  - OTEL_SERVICE_NAME=my-api
  - OTEL_RESOURCE_ATTRIBUTES=service.version=1.0.0
```

### Prometheus Metrics

For Prometheus metrics collection, expose metrics endpoint:

```yaml
labels:
  - "prometheus.io/scrape=true"
  - "prometheus.io/port=3000"
  - "prometheus.io/path=/metrics"
```

## Integration with Main Services

### Database Access

APIs can connect to shared databases or create their own:

```yaml
# Connect to shared PostgreSQL
environment:
  - DATABASE_URL=postgresql://user:pass@postgres:5432/shared_db

# Or create dedicated database
services:
  api-db:
    image: postgres:15-alpine
    # ... database configuration
```

### Service Discovery

APIs can communicate with each other using container names:

```yaml
environment:
  - USER_API_URL=http://user-api:3000
  - PAYMENT_API_URL=http://payment-api:3000
```

## Port Management

**Recommended Port Ranges:**
- **3001-3099**: APIs
- **8003-8099**: Sites
- **Avoid**: 3000 (Grafana), 8080 (Traefik), 8081 (Pi-hole), 9000 (Portainer)

## Deployment

APIs are automatically discovered and can be deployed using:

```bash
sudo ./dinky.sh
# Choose option 6: "Discover New Services"
```

Or deploy individually:

```bash
cd apis/my-api
docker compose up -d
```

## Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure unique external ports
2. **Network issues**: Verify `traefik_network` exists
3. **Environment variables**: Check `.env` file is copied
4. **Health checks**: Implement proper health endpoints

### Debugging Commands

```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f my-api

# Test connectivity
docker exec -it my-api curl localhost:3000/health

# Check network
docker network ls | grep traefik
```

## Security Considerations

- Use non-root users in containers
- Implement proper authentication
- Validate all inputs
- Use HTTPS in production
- Keep dependencies updated
- Implement rate limiting
- Use secrets management for sensitive data

## Performance Tips

- Use multi-stage Docker builds
- Implement caching strategies
- Use connection pooling for databases
- Monitor resource usage
- Implement graceful shutdowns
- Use health checks for load balancing 