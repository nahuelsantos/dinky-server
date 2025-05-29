# Dinky Server

A comprehensive self-hosted server setup with monitoring, mail services, and infrastructure management.

## 🚀 Quick Start

Dinky Server uses a **single-script architecture** for efficient deployment:

### **Simple One-Step Deployment**

```bash
# Clone the repository
git clone <repository-url>
cd dinky-server

# Run the unified deployment script
sudo ./dinky.sh
```

**What `dinky.sh` does:**
- ✅ **Interactive Menu** - Choose exactly what you want to install
- ✅ **System Preparation** - Install dependencies and configure security
- ✅ **Service Deployment** - Deploy your selected components
- ✅ **Auto-Discovery** - Find and deploy APIs/sites automatically
- ✅ **Progress Tracking** - Clear step-by-step progress indicators

## 📋 Deployment Options

### **🎯 Interactive Menu (Recommended)**
```bash
sudo ./dinky.sh                    # Interactive menu interface
```

### **⚡ Direct Commands**
```bash
sudo ./dinky.sh 1                  # Full setup (system + services)
sudo ./dinky.sh 2                  # System setup only
sudo ./dinky.sh 3                  # Deploy services only
./dinky.sh --help                 # Show help (no sudo needed)
```

### **🔧 Menu Options Available**
1. **🚀 Full Setup** - Complete system preparation and service deployment
2. **🔧 System Setup Only** - Prepare server without deploying services
3. **⚡ Deploy Services Only** - Deploy services on pre-configured system
4. **📦 Add Individual Service** - Deploy specific APIs or sites
5. **🔍 Discover New Services** - Find and deploy new services
6. **📋 List All Services** - Show status of all services
7. **🛠️ System Status & Health** - Complete system overview
8. **❓ Help & Documentation** - Built-in help system

### **🧪 Local Development (macOS/Linux)**

For testing and development on your local machine:

```bash
# No system setup required for development
make dev-up           # Start all services
make dev-core         # Traefik + Pi-hole only
make dev-monitoring   # Full LGTM stack
make dev-status       # View service URLs
make dev-down         # Stop everything
```

**Local Development Features:**
- 🚀 **No sudo required** - Uses high ports (8080, 8081, 3000+)
- 🔧 **Fresh start** - No persistent data between restarts
- 📊 **Full LGTM stack** - Complete monitoring setup
- 🌐 **Service discovery** - Auto-discovers APIs and sites

**Local Service URLs:**
- **Traefik Dashboard**: http://localhost:8080
- **Pi-hole Admin**: http://localhost:8081 (admin123)
- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **Example API**: http://localhost:3001
- **Example Site**: http://localhost:3002
- **Mail API**: http://localhost:3003

## 🏗️ Architecture

### **Single-Script Architecture Benefits**

**Benefits:**
- ⚡ **All-in-one solution** - Single script handles everything
- 🎯 **Interactive interface** - User-friendly menu system
- 🔧 **Individual service management** - Add/remove services easily
- 🛡️ **Enhanced security** - Better SSH key validation
- 📊 **Progress tracking** - Clear step indicators
- 🔍 **Service discovery** - Auto-finds new services

### **Core Components**

| Component | Purpose | Port | Status |
|-----------|---------|------|--------|
| **Traefik** | Reverse Proxy & Load Balancer | 8080 | Recommended |
| **Pi-hole** | DNS & Ad Blocking | 8081 | Recommended |
| **Cloudflared** | Secure Tunnel (No Port Forwarding) | - | Optional |
| **Mail Server** | SMTP Relay + REST API | 3005 | Optional |

### **Monitoring Stack (LGTM)**

| Service | Purpose | Port | 
|---------|---------|------|
| **Grafana** | Visualization Dashboard | 3000 |
| **Prometheus** | Metrics Collection | 9090 |
| **Loki** | Log Aggregation | 3100 |
| **Tempo** | Distributed Tracing | 3200 |
| **Pyroscope** | Continuous Profiling | 4040 |
| **cAdvisor** | Container Metrics | - |
| **Node Exporter** | System Metrics | - |

## 📁 Project Structure

```
dinky-server/
├── dinky.sh                     # 🚀 Main deployment script
├── docker-compose.yml           # Core services configuration
├── .env                         # Environment variables (auto-generated)
├── Makefile                     # Development and local testing commands
├── docs/                        # 📚 Documentation
│   ├── apis-guide.md            # API development guide
│   ├── sites-guide.md           # Website development guide
│   └── README.md                # Documentation index
├── config/                      # 🔧 Configuration templates
│   ├── environment.template     # Environment configuration template
│   └── README.md                # Configuration guide
├── infrastructure/              # Network & security infrastructure
│   ├── traefik/                 # Reverse proxy configuration
│   ├── cloudflared/             # Cloudflare tunnel setup
│   ├── pihole/                  # DNS configuration
│   └── firewall/                # Security scripts
├── services/                    # Application services
│   └── mail-server/             # Mail server setup
├── monitoring/                  # Observability stack
│   ├── prometheus/              # Metrics configuration
│   ├── grafana/                 # Dashboard configuration
│   ├── loki/                    # Log aggregation
│   └── setup-monitoring.sh      # Monitoring setup script
├── apis/                        # 🔍 Auto-discovered API services
│   └── example-api/             # Example API with monitoring
└── sites/                       # 🔍 Auto-discovered website services
    └── example-site/            # Example site
```

## 🎯 Features

### **🔧 Single-Script Architecture**
- **Interactive Menu** - User-friendly interface for all operations
- **Progressive Setup** - Step-by-step system preparation and service deployment
- **Progressive security** with 3 configurable levels
- **Auto-discovery** of APIs and sites in your directories
- **Individual service management** - Add services anytime

### **🔒 Security Levels**

| Level | Components | Use Case |
|-------|------------|----------|
| **1. Basic** | Firewall + Fail2ban + Docker security | Development/Testing |
| **2. Standard** | Basic + SSH hardening + Auto-updates | Production (Default) |
| **3. Comprehensive** | Standard + Log monitoring + Security audit | High Security |

**Security Features:**
- **UFW firewall** with sensible defaults
- **Fail2ban** intrusion prevention
- **SSH hardening** with key-based authentication
- **Docker security** enhancements
- **Automated security updates**
- **Log monitoring** with security alerting
- **Security auditing** with compliance checks

### **📊 Comprehensive Monitoring**
- **LGTM Stack** (Loki, Grafana, Tempo, Mimir)
- **Prometheus** metrics with cAdvisor and Node Exporter
- **Pyroscope** continuous profiling
- **OpenTelemetry** distributed tracing
- **Container and system monitoring**
- **Pre-configured dashboards** for all services

### **🌐 Network Infrastructure**
- **Traefik** reverse proxy with automatic service discovery
- **Cloudflare tunnel** for secure external access (optional)
- **Pi-hole** DNS with ad-blocking capabilities
- **Internal service mesh** with Docker networks
- **SSL/TLS termination** at the proxy level

## 🚀 Getting Started

### **Prerequisites**

- **Raspberry Pi 4** (2GB+ RAM recommended) or any Linux server
- **Ubuntu 20.04+**, **Debian 11+**, or **Raspberry Pi OS**
- **2GB+ free disk space**
- **Internet connection** for initial setup

### **🎯 Unified Deployment Script**

#### **Interactive Menu Mode (Recommended)**
```bash
git clone <repository-url>
cd dinky-server
sudo ./dinky.sh
```

#### **Direct Commands**
```bash
sudo ./dinky.sh 1        # Full setup (system + services)
sudo ./dinky.sh 2        # System setup only  
sudo ./dinky.sh 3        # Deploy services only
./dinky.sh --help       # Show help (no sudo needed)
```

## 🎮 Usage Examples

### **Common Workflows**

#### **Initial Server Setup**
```bash
# Complete setup with interactive menu
sudo ./dinky.sh

# Or use direct commands:
sudo ./dinky.sh 1                    # Full setup (recommended for new servers)
```

#### **System-Only Setup**
```bash
# Prepare system without deploying services
sudo ./dinky.sh 2                    # System setup only
```

#### **Service-Only Deployment**
```bash
# Deploy services on pre-configured system
sudo ./dinky.sh 3                    # Deploy services only
```

#### **Adding New Services**
```bash
# Use the interactive menu for service management
sudo ./dinky.sh                     # Choose option 4 from menu

# Or use the built-in discovery feature
sudo ./dinky.sh                     # Choose option 5 for discovery
```

#### **Development Workflow**
```bash
# Local development (no sudo needed)
make dev-up                    # Start everything
make dev-logs                  # View logs
make dev-down                  # Stop everything
```

## 🔧 Service Management

### **Core Commands**

```bash
# Service Status
docker compose ps
docker compose logs -f

# Service Control
docker compose down              # Stop all services
docker compose up -d            # Start all services
docker compose restart <service> # Restart specific service

# Updates
docker compose pull             # Pull latest images
docker compose up -d            # Apply updates
```

### **Individual Service Management**

```bash
# Add new services
sudo ./deploy.sh --add-site blog
sudo ./deploy.sh --add-api user-service

# Discover new services
sudo ./deploy.sh --discover

# List all services
sudo ./deploy.sh --list
```

### **Monitoring & Logs**

```bash
# View deployment logs
tail -f /var/log/dinky-deployment.log

# View setup logs
tail -f /var/log/dinky-setup.log

# Service-specific logs
docker compose logs -f traefik
docker compose logs -f pihole
docker compose logs -f grafana
```

## 🔗 Service URLs

After deployment, access your services at:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Traefik Dashboard** | http://[SERVER_IP]:8080 | - |
| **Pi-hole Admin** | http://[SERVER_IP]:8081 | Password in `.env` |
| **Grafana** | http://[SERVER_IP]:3000 | admin / Password in `.env` |
| **Prometheus** | http://[SERVER_IP]:9090 | - |
| **Pyroscope** | http://[SERVER_IP]:4040 | - |
| **Loki** | http://[SERVER_IP]:3100 | - |
| **Mail API** | http://[SERVER_IP]:3005 | - |

**Note:** Replace `[SERVER_IP]` with your actual server IP address (found in `.env` file)

## 🛠️ Configuration

### **Environment Variables**

The `.env` file is automatically generated during setup with secure defaults:

```bash
# Server Configuration
SERVER_IP=192.168.1.100          # Auto-detected
TZ=Europe/Madrid                 # Timezone
DOMAIN_NAME=dinky.local          # Internal domain

# Service Passwords (Auto-generated)
PIHOLE_PASSWORD=<random>
GRAFANA_PASSWORD=<random>

# Mail Configuration
SMTP_RELAY_HOST=smtp.gmail.com
SMTP_RELAY_USERNAME=your-email@gmail.com
SMTP_RELAY_PASSWORD=your-app-password

# Cloudflare Tunnel
TUNNEL_ID=your-tunnel-id-here
```

**Update the following manually:**
- SMTP relay settings for mail functionality
- Cloudflare tunnel ID for external access
- Domain names for your specific setup

### **Security Configuration**

Security settings are applied during system setup based on your chosen level:

#### **Level 1: Basic Security**
- UFW firewall with essential ports
- Fail2ban for SSH protection
- Docker security enhancements

#### **Level 2: Standard Security (Default)**
- Everything from Level 1
- SSH hardening and key-based auth
- Automatic security updates
- Security monitoring cron jobs

#### **Level 3: Comprehensive Security**
- Everything from Level 2
- Advanced log monitoring
- Security auditing and compliance
- Enhanced intrusion detection

## 🔍 Auto-Discovery

Dinky Server automatically discovers and can deploy services from:

### **APIs Directory**
```
apis/
├── my-api/
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── src/
└── user-service/
    ├── docker-compose.yml
    └── app/
```

### **Sites Directory**
```
sites/
├── blog/
│   ├── docker-compose.yml
│   └── content/
└── portfolio/
    ├── docker-compose.yml
    └── static/
```

**Requirements for auto-discovery:**
- Each service must have its own directory
- Directory must contain `docker-compose.yml` or `docker-compose.yaml`
- Services are deployed with environment variables copied from main `.env`

## 🚨 Troubleshooting

### **Common Issues**

#### **Setup Script Issues**
```bash
# Check setup logs
tail -f /var/log/dinky-setup.log

# Re-run with different security level
sudo ./setup.sh --security-level 1
```

#### **Deployment Issues**
```bash
# Check deployment logs
tail -f /var/log/dinky-deployment.log

# Validate docker-compose
docker compose config

# Check service status
docker compose ps
```

#### **Service Access Issues**
```bash
# Check if services are running
docker compose ps

# Check firewall rules
sudo ufw status

# Verify network connectivity
docker network ls
```

#### **Permission Issues**
```bash
# Ensure scripts are executable
chmod +x setup.sh deploy.sh

# Run with sudo for system operations
sudo ./setup.sh
sudo ./deploy.sh
```

### **Recovery Options**

#### **Rollback Setup**
If system setup fails, automatic rollback restores configuration files from backup.

#### **Service Recovery**
```bash
# Stop all services
docker compose down

# Remove problematic containers
docker compose rm -f

# Restart services
docker compose up -d
```

#### **Complete Reset**
```bash
# Stop and remove everything
docker compose down -v
docker system prune -a

# Re-run deployment
sudo ./deploy.sh
```

## 🤝 Contributing

### **Development Setup**
```bash
# Clone repository
git clone <repository-url>
cd dinky-server

# Use local development environment
make dev-up
make dev-status
```

### **Adding New Services**

1. **Create service directory**: `apis/my-service/` or `sites/my-site/`
2. **Add docker-compose.yml** with your service configuration
3. **Test locally**: `make dev-up`
4. **Deploy**: `sudo ./deploy.sh --add-api my-service`

### **Project Structure Guidelines**

- **System scripts**: `setup.sh`, `deploy.sh` - Core deployment logic
- **Infrastructure**: `infrastructure/` - Network and security components
- **Services**: `services/` - Core application services
- **Monitoring**: `monitoring/` - Observability stack configuration
- **APIs**: `apis/` - Auto-discovered API services
- **Sites**: `sites/` - Auto-discovered website services

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- **Traefik** for excellent reverse proxy capabilities
- **Grafana Labs** for the comprehensive LGTM observability stack
- **Pi-hole** for network-level ad blocking
- **Docker** and **Docker Compose** for containerization
- **Cloudflare** for secure tunnel solutions

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
