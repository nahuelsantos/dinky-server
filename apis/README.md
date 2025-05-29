# APIs Directory

This directory contains API services that are **automatically discovered** and can be deployed by the Dinky Server deployment system.

## 🚀 New Two-Script Architecture

Dinky Server now uses a **two-script system** for efficient deployment:

1. **`setup.sh`** - System preparation (run once)
2. **`deploy.sh`** - Service deployment and management

## How Auto-Discovery Works

The `deploy.sh` script automatically scans this directory for:
- Subdirectories containing `docker-compose.yml` or `docker-compose.yaml` files
- Each discovered service can be deployed individually or as part of a full deployment

## 🎯 Deployment Options

### **Full Deployment with Discovery**
```bash
sudo ./deploy.sh
# Will discover and offer to deploy all APIs
```

### **Individual API Deployment**
```bash
sudo ./deploy.sh --add-api my-api
# Deploy specific API by name
```

### **Discovery Only**
```bash
sudo ./deploy.sh --discover
# Find and deploy only new/stopped APIs
```

### **List All APIs**
```bash
sudo ./deploy.sh --list
# Show all APIs with running status
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
2. **Use unique ports** to avoid conflicts (recommended: 3001+)
3. **Include `traefik_network`** for reverse proxy integration (if needed)
4. **Proper Traefik labels** for routing (if using external access)

## Example docker-compose.yml

### **Basic API Setup**
```yaml
version: '3.8'

services:
  my-api:
    image: my-api:latest
    container_name: my-api
    restart: unless-stopped
    ports:
      - "3001:3000"
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
version: '3.8'

services:
  my-api:
    image: my-api:latest
    container_name: my-api
    restart: unless-stopped
    ports:
      - "3001:3000"
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
version: '3.8'
services:
  my-new-api:
    image: node:18-alpine
    container_name: my-new-api
    restart: unless-stopped
    ports:
      - "3010:3000"
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
sudo ./deploy.sh --add-api my-new-api
```

### **Managing Existing APIs**

```bash
# List all APIs with status
sudo ./deploy.sh --list

# Deploy only new APIs
sudo ./deploy.sh --discover

# Check API logs
docker compose logs -f my-api

# Restart specific API
docker compose restart my-api
```

## 🔍 Port Management

### **Recommended Port Ranges**
- **3001-3099**: Custom APIs
- **3100+**: Reserved for monitoring services

### **Port Conflict Resolution**
If you get port conflicts:
1. Check existing services: `docker compose ps`
2. Update your API's port mapping
3. Redeploy: `sudo ./deploy.sh --add-api your-api`

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
tail -f /var/log/dinky-deployment.log

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