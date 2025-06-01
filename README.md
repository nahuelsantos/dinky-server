# Dinky Server

A comprehensive self-hosted server setup with monitoring, security, and service management - all through a single interactive script.

## 🚀 Quick Start

```bash
git clone <repository-url>
cd dinky-server
sudo ./dinky.sh
```

That's it! The interactive menu will guide you through everything.

## 📋 What You Get

**Core Services:**
- 🐳 **Portainer** - Container management UI
- 🔄 **Traefik** - Reverse proxy with automatic SSL
- 🛡️ **Pi-hole** - Network-wide ad blocking
- ☁️ **Cloudflared** - Secure tunnel (no port forwarding needed)
- 📧 **Mail Server** - SMTP relay with REST API

**Monitoring Stack (LGTM):**
- 📊 **Grafana** - Beautiful dashboards
- 📈 **Prometheus** - Metrics collection
- 📝 **Loki** - Log aggregation  
- 🔍 **Tempo** - Distributed tracing
- 🔥 **Pyroscope** - Performance profiling

**Security Features:**
- 🔥 UFW firewall + Fail2ban
- 🔐 SSH hardening with key authentication
- 🛡️ Docker security enhancements
- 🔄 Automatic security updates
- 📊 Security monitoring and auditing

## 👁️ LGTM Stack Testing

For testing your LGTM monitoring stack, use **[Argus](https://github.com/nahuelsantos/argus)**:

```bash
# Quick test your LGTM stack
docker run -p 3001:3001 ghcr.io/nahuelsantos/argus:v0.0.1

# Or use the local development command
make argus
```

**Argus** (external tool): https://github.com/nahuelsantos/argus

## 🎯 Menu Options

1. **🚀 Full Setup** - New server? Start here for complete setup
2. **🔧 System Setup Only** - Prepare server security and dependencies
3. **⚡ Deploy Services Only** - Deploy services on prepared system
4. **📦 Add Individual Service** - Deploy specific APIs or sites
5. **🎯 Deploy Example Services** - Try the included examples
6. **🔍 Discover New Services** - Auto-find and deploy new services
7. **📋 List All Services** - See what's running
8. **🛠️ System Status & Health** - Complete system overview
9. **❓ Help & Documentation** - Built-in help system

## 💻 Local Development

Test everything locally on your machine:

```bash
make up        # Start all services (no sudo needed)
make status    # View service status and URLs
make down      # Stop everything
make logs      # View all logs
make clean     # Clean containers, volumes, and images
make reset     # Complete reset of environment
```

## 🏗️ Project Structure

```
dinky-server/
├── dinky.sh                    # 🚀 Main script - run this!
├── docker-compose.yml          # Core services
├── .env                        # Auto-generated config
├── Makefile                    # Local development
├── apis/                       # 🔍 Auto-discovered APIs
│   └── example-api/            # Simple Go REST API example
├── sites/                      # 🔍 Auto-discovered sites  
│   └── example-site/           # Simple static site example
├── infrastructure/             # Network & security
├── monitoring/                 # LGTM stack config
└── services/                   # Core services
```

## 🔧 Adding Your Own Services

1. **Create a directory**: `apis/my-api/` or `sites/my-site/`
2. **Add docker-compose.yml** with your service
3. **Run the script**: `sudo ./dinky.sh` → Option 6 (Discover Services)

The system automatically finds and deploys new services!

## 🌐 Access Your Services

After deployment, visit:
- **Traefik Dashboard**: http://[SERVER_IP]:8080
- **Pi-hole Admin**: http://[SERVER_IP]:8081
- **Grafana**: http://[SERVER_IP]:3000
- **Portainer**: http://[SERVER_IP]:9000
- **Prometheus**: http://[SERVER_IP]:9090
- **Loki**: http://[SERVER_IP]:3100
- **Tempo**: http://[SERVER_IP]:3200
- **Pyroscope**: http://[SERVER_IP]:4040
- **OTEL Collector (gRPC)**: http://[SERVER_IP]:4317
- **OTEL Collector (HTTP)**: http://[SERVER_IP]:4318
- **OTEL Collector Metrics**: http://[SERVER_IP]:8888
- **cAdvisor**: http://[SERVER_IP]:8082
- **Node Exporter**: http://[SERVER_IP]:9100

*(SERVER_IP is auto-detected and shown in the script)*

**Core Infrastructure Ports** (no web UI):
- **HTTP**: 80 (internal, via Traefik)
- **HTTPS**: 443 (internal, via Traefik) 
- **DNS**: 53 (Pi-hole)
- **SMTP**: 25, 587 (Mail server)

**Example Services:**
- **Example API (Simple)**: http://[SERVER_IP]:3003
- **Example Site (Simple)**: http://[SERVER_IP]:3004

## 📡 Example API Endpoints

The included Example API (port 3003) provides simple REST API demonstration:

- **💓 Health Check**: http://[SERVER_IP]:3003/health
- **👋 Hello Endpoint**: http://[SERVER_IP]:3003/hello
- **👥 Users Endpoint**: http://[SERVER_IP]:3003/users

## 🔍 Complete Port Reference

**Web UI Services:**
```
8080 - Traefik Dashboard
8081 - Pi-hole Admin  
9000 - Portainer
3000 - Grafana
9090 - Prometheus
3100 - Loki
3200 - Tempo
4040 - Pyroscope
8082 - cAdvisor
9100 - Node Exporter
```

**Monitoring Endpoints:**
```
4317 - OTEL Collector (gRPC)
4318 - OTEL Collector (HTTP)
8888 - OTEL Collector Metrics
```

**Core Infrastructure:**
```
25   - SMTP
53   - DNS (Pi-hole)
80   - HTTP (Traefik, internal)
443  - HTTPS (Traefik, internal)
587  - SMTP Submission
```

**Example Services:**
```
3003 - Example API (Simple REST API)
3004 - Example Site (Simple static site)
```

**Available for Your Services:**
```
3001-3099 - Recommended for APIs  
8003-8099 - Recommended for Sites
```

**For LGTM Stack Testing:**
```
3001 - Argus (docker run -p 3001:3001 ghcr.io/nahuelsantos/argus:v0.0.1)
```