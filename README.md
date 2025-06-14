# Dinky Server

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

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
- 📧 **Mail Server** - SMTP relay for internal services

**Monitoring Stack (LGTMA):**
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

The monitoring stack provides comprehensive observability with metrics, logs, traces, and profiling. You can test the stack manually or use external validation tools as needed.

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
- **Alertmanager**: http://[SERVER_IP]:9093
- **Loki**: http://[SERVER_IP]:3100
- **Tempo**: http://[SERVER_IP]:3200
- **Pyroscope**: http://[SERVER_IP]:4040
- **OTEL Collector (gRPC)**: http://[SERVER_IP]:4317
- **OTEL Collector (HTTP)**: http://[SERVER_IP]:4318
- **OTEL Collector Metrics**: http://[SERVER_IP]:8888
- **OTEL Collector Prometheus Metrics**: http://[SERVER_IP]:8889
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
9093 - Alertmanager
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
8889 - OTEL Collector Prometheus Metrics
8080 - Traefik Metrics (at /metrics path)
```

**LGTMA Monitoring Stack:**
```
3000 - Grafana (dashboards and visualization)
9090 - Prometheus (metrics collection and alerting)
9093 - Alertmanager (alert management and routing)
3100 - Loki (log aggregation and search)
3200 - Tempo (distributed request tracing)
4040 - Pyroscope (continuous performance profiling)
8082 - cAdvisor (container resource monitoring)
9100 - Node Exporter (system metrics collection)
3001 - Argus (LGTM stack testing and validation)
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
3002-3099 - Recommended for APIs (excluding 3001, 3003)
8003-8099 - Recommended for Sites (excluding 8080-8082, 8088-8089)
```

**For LGTM Stack Testing:**
```

```

## Monitoring & Observability

Dinky Server includes a comprehensive LGTM (Loki, Grafana, Tempo, Metrics) stack:

### Components
- **Grafana** (Port 3000): Dashboards and visualization
- **Prometheus** (Port 9090): Metrics collection and storage  
- **Loki** (Port 3100): Log aggregation and search
- **Tempo** (Port 3200): Distributed tracing
- **Pyroscope** (Port 4040): Continuous profiling

- **cAdvisor** (Port 8082): Container metrics
- **Node Exporter** (Port 9100): System metrics

### Integration
- Prometheus scrapes metrics from all services
- Grafana provides unified dashboards for metrics, logs, and traces
- OpenTelemetry Collector processes and routes telemetry data
- Alerting rules monitor system health and performance


📖 **Documentation**: See [Data Retention Policy](docs/retention-policy.md) for storage and cleanup configuration.