# Dinky Server

A comprehensive self-hosted server setup with monitoring, mail services, and infrastructure management.

## 🚀 Quick Deployment

### **Option 1: Automated Deployment (Recommended)**

For production deployment on Raspberry Pi or other devices:

```bash
# Clone the repository
git clone <repository-url>
cd dinky-server

# Run the deployment script
sudo ./deploy.sh
```

The deployment script will:
- ✅ Install all dependencies (Docker, Docker Compose, etc.)
- ✅ Configure security (firewall, fail2ban, SSH hardening)
- ✅ Let you choose which components to install
- ✅ Auto-discover APIs and sites in your directories
- ✅ Set up environment variables automatically
- ✅ Deploy and start selected services
- ✅ Provide access URLs and next steps

### **Option 2: Local Development (macOS/Linux)**

For testing and development on your local machine:

```bash
# Clone the repository
git clone <repository-url>
cd dinky-server

# Start all services (no sudo required)
make dev-up

# Or start specific service groups
make dev-core        # Traefik + Pi-hole
make dev-monitoring  # Full LGTM stack
make dev-apis        # Example API + Mail API
make dev-sites       # Example site

# View status and URLs
make dev-status

# Stop everything
make dev-down
```

**Local Development Features:**
- 🚀 **No sudo required** - Uses high ports (8080, 8081, 3000+)
- 🔧 **Fresh start** - No persistent data between restarts
- 📊 **Full LGTM stack** - Complete monitoring setup
- 🌐 **Service discovery** - Auto-discovers APIs and sites
- 🎯 **Selective deployment** - Start only what you need

**Local Service URLs:**
- **Traefik Dashboard**: http://localhost:8080
- **Pi-hole Admin**: http://localhost:8081 (admin123)
- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **Example API**: http://localhost:3001
- **Example Site**: http://localhost:3002
- **Mail API**: http://localhost:3003

### **Option 3: Manual Deployment**

For advanced users or custom setups:

```bash
# 1. Copy environment variables
cp .env.example .env
# Edit .env with your actual values

# 2. Create external network
docker network create traefik_network

# 3. Start services
docker compose up -d

# 4. Set up monitoring (optional)
sudo bash monitoring/setup-monitoring.sh

# 5. Configure security (optional)
sudo bash infrastructure/firewall/master-security-setup.sh
```

## 🏗️ Architecture

### **Core Components**

| Component | Purpose | Port | Status |
|-----------|---------|------|--------|
| **Traefik** | Reverse Proxy & Load Balancer | 8080 | Recommended |
| **Pi-hole** | DNS & Ad Blocking | 8081 | Recommended |
| **Cloudflared** | Secure Tunnel (No Port Forwarding) | - | Optional |
| **Mail Server** | SMTP Relay + REST API | 3000 | Optional |

### **Monitoring Stack (LGTM)**

| Service | Purpose | Port | 
|---------|---------|------|
| **Grafana** | Visualization Dashboard | 3000 |
| **Prometheus** | Metrics Collection | 9090 |
| **Loki** | Log Aggregation | 3100 |
| **Tempo** | Distributed Tracing | 3200 |
| **Pyroscope** | Continuous Profiling | 4040 |

### **Management Tools**

| Tool | Purpose | Port |
|------|---------|------|
| **Portainer** | Docker Management UI | 9000 |

## 📁 Project Structure

```
dinky-server/
├── deploy.sh                 # 🚀 Main deployment script
├── docker-compose.yml        # Core services configuration
├── infrastructure/           # Network & security infrastructure
│   ├── traefik/              # Reverse proxy configuration
│   ├── cloudflared/          # Cloudflare tunnel setup
│   ├── pihole/               # DNS configuration
│   └── firewall/             # Security scripts
├── services/                 # Application services
│   └── mail-server/          # Mail server setup
├── monitoring/               # Observability stack
│   ├── prometheus/           # Metrics configuration
│   ├── grafana/              # Dashboard configuration
│   ├── loki/                 # Log aggregation
│   └── setup-monitoring.sh   # Monitoring setup script
├── apis/                     # 🔍 Auto-discovered API services
└── sites/                    # 🔍 Auto-discovered website services
```

## 🎯 Features

### **🔧 Easy Deployment**
- **One-command deployment** with interactive component selection
- **Auto-discovery** of APIs and sites in your directories
- **Automatic dependency installation** (Docker, security tools)
- **Environment setup** with secure password generation
- **Rollback functionality** if deployment fails

### **🔒 Security First**
- **Three-tier security levels** with progressive hardening
  - **Basic**: UFW firewall + Fail2ban + Docker security
  - **Standard**: Basic + SSH hardening + Auto-updates + Cron jobs
  - **Comprehensive**: Standard + Log monitoring + Security audit + Master validation
- **Automated security updates** and patch management
- **SSH hardening** with key-based authentication
- **Docker security** enhancements and runtime protection
- **Log monitoring** with Logwatch integration
- **Security auditing** with automated compliance checks

### **📊 Comprehensive Monitoring**
- **LGTM Stack** (Loki, Grafana, Tempo, Mimir)
- **Prometheus** metrics collection
- **Pyroscope** continuous profiling
- **Container monitoring** with cAdvisor
- **Log aggregation** from all services

### **🌐 Network Infrastructure**
- **Traefik** reverse proxy with automatic service discovery
- **Cloudflare tunnel** for secure external access (optional)
- **Pi-hole** DNS with ad-blocking capabilities
- **Internal service mesh** with Docker networks

## 🚀 Getting Started

### **Prerequisites**

- **Raspberry Pi 4** (2GB+ RAM recommended) or any Linux server
- **Ubuntu 20.04+**, **Debian 11+**, or **Raspberry Pi OS**
- **2GB+ free disk space**
- **Internet connection** for initial setup

### **Step 1: Clone Repository**

```bash
git clone <repository-url>
cd dinky-server
```

### **Step 2: Run Deployment**

```bash
sudo ./deploy.sh
```

The script will guide you through:

1. **System Requirements Check** - Validates your system
2. **Component Selection** - Choose what to install
3. **Service Discovery** - Finds APIs/sites to deploy
4. **Security Setup** - Configures firewall and security
5. **Service Deployment** - Starts selected components
6. **Final Configuration** - Provides access URLs and next steps

### **Step 3: Access Services**

After deployment, access your services at:

- **Traefik Dashboard**: `http://YOUR_IP:8080`
- **Pi-hole Admin**: `http://YOUR_IP:8081`
- **Grafana**: `http://YOUR_IP:3000`
- **Prometheus**: `http://YOUR_IP:9090`
- **Portainer**: `http://YOUR_IP:9000`

*Replace `YOUR_IP` with your server's IP address*

## 🔧 Management Commands

### **Production Service Management**
```bash
# View all services status
docker compose ps

# View logs
docker compose logs -f [service-name]

# Stop all services
docker compose down

# Update services
docker compose pull && docker compose up -d

# Restart specific service
docker compose restart [service-name]
```

### **Local Development Commands**
```bash
# Main commands
make help           # Show all available commands
make dev-up         # Start all development services
make dev-down       # Stop all services
make dev-restart    # Restart all services
make dev-status     # Show service status and health

# Selective deployment
make dev-core       # Start only Traefik + Pi-hole
make dev-monitoring # Start only monitoring stack
make dev-apis       # Start only API services
make dev-sites      # Start only site services

# Dynamic service management
make dev-list-services        # List all available APIs and sites with status
make dev-discover            # Auto-discover and deploy all new services
make dev-add-site SITE=name  # Deploy a specific site
make dev-add-api API=name    # Deploy a specific API
make dev-remove-site SITE=name # Remove a specific site

# Maintenance
make dev-logs       # Show logs from all services
make dev-logs-traefik # Show logs from specific service
make dev-clean      # Stop and remove containers/volumes
make dev-reset      # Complete environment reset
make dev-update     # Pull latest images and restart

# Development tools
make dev-shell-grafana    # Open shell in specific container
```

### **System Monitoring**
```bash
# View deployment logs
tail -f /var/log/dinky-deployment.log

# Check security status
sudo bash infrastructure/firewall/security-check.sh

# Manual security audit
sudo /opt/docker-security/docker-security-audit.sh
```

### **Backup & Restore**
```bash
# Backups are automatically created in:
ls /opt/dinky-backups/

# View deployed components
cat /opt/dinky-server/deployed-components.txt
```

## 🌍 External Access Setup

### **Option 1: Cloudflare Tunnel (Recommended)**

1. **Create Cloudflare Tunnel**:
   ```bash
   # Install cloudflared
   wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
   sudo dpkg -i cloudflared-linux-arm64.deb
   
   # Login and create tunnel
   cloudflared tunnel login
   cloudflared tunnel create dinky-server
   ```

2. **Update Configuration**:
   ```bash
   # Edit .env file
   nano .env
   # Set TUNNEL_ID=your-tunnel-id
   ```

3. **Restart Services**:
   ```bash
   docker compose restart cloudflared
   ```

### **Option 2: Port Forwarding**

Configure your router to forward these ports:
- **80** → Your server IP:80 (HTTP)
- **443** → Your server IP:443 (HTTPS)

## 🔍 Auto-Discovery

The deployment script automatically discovers services in:

- **`apis/`** directory - REST APIs, microservices
- **`sites/`** directory - Websites, web applications

Each discovered service with a `docker-compose.yml` file will be offered for deployment.

### **Example Structure**
```
apis/
├── user-api/
│   └── docker-compose.yml
└── payment-api/
    └── docker-compose.yml

sites/
├── blog/
│   └── docker-compose.yml
└── portfolio/
    └── docker-compose.yml
```

## 🚀 Adding Services Dynamically

You can add new services to your running development environment without restarting everything:

### **Adding a New Site**

1. **Create the directory structure**:
   ```bash
   mkdir -p sites/my-blog/html
   ```

2. **Create docker-compose.yml**:
   ```yaml
   services:
     my-blog:
       image: nginx:alpine
       container_name: my-blog
       restart: unless-stopped
       ports:
         - "3012:80"
       volumes:
         - ./html:/usr/share/nginx/html:ro
       networks:
         - traefik_network
       labels:
         - "traefik.enable=true"
         - "traefik.http.routers.my-blog.rule=Host(`blog.${DOMAIN_NAME}`)"
         - "traefik.http.services.my-blog.loadbalancer.server.port=80"

   networks:
     traefik_network:
       external: true
   ```

3. **Add your content** in `sites/my-blog/html/index.html`

4. **Deploy the new site**:
   ```bash
   sudo ./deploy.sh --add-site my-blog
   ```

### **Adding a New API**

1. **Create the API directory**:
   ```bash
   mkdir -p apis/my-api
   ```

2. **Create docker-compose.yml** with your API configuration

3. **Deploy the API**:
   ```bash
   sudo ./deploy.sh --add-api my-api
   ```

### **Managing Services**

```bash
# List all services with status
make dev-list-services

# Remove a site
make dev-remove-site SITE=my-blog

# View logs from specific service
make dev-logs-my-blog
```

**Key Points:**
- ✅ **No restart required** - Add services to running environment
- ✅ **Unique ports** - Each service needs a unique port (3001, 3002, 3003, etc.)
- ✅ **Automatic discovery** - Services are found automatically
- ✅ **Individual management** - Deploy, remove, or restart specific services

## 🛠️ Customization

### **Adding New Services**

1. Create service directory in `apis/` or `sites/`
2. Add `docker-compose.yml`
3. Run `sudo ./deploy.sh` to redeploy

### **Environment Variables**

Edit `.env` file to customize:
- Server IP and timezone
- Service passwords
- SMTP relay settings
- Cloudflare tunnel configuration

### **Security Configuration**

Modify security scripts in `infrastructure/firewall/`:
- `setup-firewall.sh` - UFW rules
- `setup-fail2ban.sh` - Intrusion detection
- `setup-ssh-keys.sh` - SSH hardening

## 🆘 Troubleshooting

### **Common Issues**

**Services won't start:**
```bash
# Check logs
docker compose logs [service-name]

# Check system resources
htop
df -h
```

**Network issues:**
```bash
# Recreate networks
docker network prune
docker network create traefik_network
docker compose up -d
```

**Permission issues:**
```bash
# Fix Docker permissions
sudo usermod -aG docker $USER
newgrp docker
```

### **Getting Help**

1. **Check deployment logs**: `tail -f /var/log/dinky-deployment.log`
2. **Run security audit**: `sudo bash infrastructure/firewall/security-check.sh`
3. **View service status**: `docker compose ps`
4. **Check system resources**: `htop` and `df -h`
5. **Security level validation**: `sudo bash infrastructure/firewall/master-security-setup.sh`

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**Made with ❤️ for self-hosting enthusiasts**

### Post-Deployment Service Management

After your initial deployment, you can easily add new services:

```bash
# Add a specific site
sudo ./deploy.sh --add-site my-blog

# Add a specific API
sudo ./deploy.sh --add-api user-service

# Discover and deploy all new services
sudo ./deploy.sh --discover

# List all available services
sudo ./deploy.sh --list

# Show help
sudo ./deploy.sh --help
```

## Adding New Services

### Creating a New Site

1. Create the directory structure:
```bash
mkdir -p sites/my-blog/html
```

2. Create `sites/my-blog/docker-compose.yml`:
```yaml
services:
  my-blog:
    image: nginx:alpine
    container_name: my-blog
    restart: unless-stopped
    ports:
      - "3012:80"
    volumes:
      - ./html:/usr/share/nginx/html:ro
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-blog.rule=Host(`blog.${DOMAIN_NAME}`)"
      - "traefik.http.services.my-blog.loadbalancer.server.port=80"

networks:
  traefik_network:
    external: true
```

3. Add your content to `sites/my-blog/html/index.html`

4. Deploy the site:
```bash
sudo ./deploy.sh --add-site my-blog
```

### Creating a New API

1. Create the directory structure:
```bash
mkdir -p apis/my-api
```

2. Create `apis/my-api/docker-compose.yml`:
```yaml
services:
  my-api:
    image: node:alpine
    container_name: my-api
    restart: unless-stopped
    ports:
      - "3013:3000"
    volumes:
      - ./src:/app
    working_dir: /app
    command: npm start
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-api.rule=Host(`api.${DOMAIN_NAME}`)"
      - "traefik.http.services.my-api.loadbalancer.server.port=3000"

networks:
  traefik_network:
    external: true
```

3. Add your API code to `apis/my-api/src/`

4. Deploy the API:
```bash
sudo ./deploy.sh --add-api my-api
```

### Auto-Discovery

The system automatically discovers new services in `apis/` and `sites/` directories:

```bash
# Scan and deploy all new services
sudo ./deploy.sh --discover
```

## Management Commands
