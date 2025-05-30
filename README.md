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

## 🎯 Menu Options

1. **🚀 Full Setup** - New server? Start here for complete setup
2. **🔧 System Setup Only** - Prepare server security and dependencies
3. **⚡ Deploy Services Only** - Deploy services on prepared system
4. **📦 Add Individual Service** - Deploy specific APIs or sites
5. **🎯 Deploy Example Site & API** - Try the included examples
6. **🔍 Discover New Services** - Auto-find and deploy new services
7. **📋 List All Services** - See what's running
8. **🛠️ System Status & Health** - Complete system overview
9. **❓ Help & Documentation** - Built-in help system

## 💻 Local Development

Test everything locally on your machine:

```bash
make dev-up        # Start all services (no sudo needed)
make dev-status    # View service URLs
make dev-down      # Stop everything
```

## 🏗️ Project Structure

```
dinky-server/
├── dinky.sh                    # 🚀 Main script - run this!
├── docker-compose.yml          # Core services
├── .env                        # Auto-generated config
├── Makefile                    # Local development
├── apis/                       # 🔍 Auto-discovered APIs
│   └── example-api/            # Go REST API example
├── sites/                      # 🔍 Auto-discovered sites  
│   └── example-site/           # Static site example
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
- **Example Site**: http://[SERVER_IP]:3002

## 📡 Example API Endpoints

The included Example API (port 3001) provides comprehensive testing endpoints:

- **📖 API Documentation**: http://[SERVER_IP]:3001/docs
- **🎮 Web UI**: http://[SERVER_IP]:3001/ui  
- **💓 Health Check**: http://[SERVER_IP]:3001/health
- **📊 Metrics**: http://[SERVER_IP]:3001/metrics

**Testing Endpoints** (POST requests):
- `/test/metrics` - Generate custom metrics
- `/test/logs` - Generate log entries  
- `/test/error` - Create intentional errors
- `/test/cpu` - CPU load testing
- `/test/memory` - Memory allocation testing
- `/test/trace` - Distributed tracing simulation

Perfect for testing your monitoring stack and learning the system!

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
3001 - Example API
3002 - Example Site
```

**Available for Your Services:**
```
3003-3099 - Recommended for APIs
8003-8099 - Recommended for Sites
```

## 🛠️ Basic Commands

```bash
# Service management
docker compose ps              # Check status
docker compose logs -f         # View logs
docker compose restart <name>  # Restart service

# Updates
docker compose pull           # Get latest images
docker compose up -d          # Apply updates
```

## 🚨 Troubleshooting

**Terminal Issues** (auto-fixed, but if needed):
```bash
sudo TERM=xterm-256color ./dinky.sh
```

**Permission Issues**:
```bash
chmod +x dinky.sh
sudo ./dinky.sh
```

**Service Issues**:
```bash
docker compose down
docker compose up -d
```

**Get Help**:
```bash
./dinky.sh --help           # Command help
sudo ./dinky.sh             # Use built-in menu help (option 9)
```

## 🎯 Why Dinky Server?

- **One Script Does Everything** - No complex setup procedures
- **Interactive & Guided** - Clear menus and progress indicators  
- **Secure by Default** - Multiple security levels available
- **Auto-Discovery** - Finds your services automatically
- **Production Ready** - Full monitoring and management
- **Local Development** - Test everything on your machine

## 📚 More Information

- **Built-in Help**: Run `sudo ./dinky.sh` and select option 9
- **API Guide**: `./docs/apis-guide.md`
- **Sites Guide**: `./docs/sites-guide.md`
- **Examples**: Check `apis/example-api/` and `sites/example-site/`

---

**Need help?** The script has comprehensive built-in documentation and error handling. Just run it and explore the menu!