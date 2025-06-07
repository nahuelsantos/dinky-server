# Dinky Server Documentation

Welcome to the Dinky Server documentation! This directory contains comprehensive guides for setting up, configuring, and managing your self-hosted server infrastructure.

## 📚 Available Guides

### **🚀 Getting Started**
- **[Main README](../README.md)** - Complete setup guide and overview
- **[Quick Start](../README.md#-quick-start)** - Fast deployment instructions

### **🔧 Development Guides**
- **[APIs Guide](apis-guide.md)** - Building and deploying API services
- **[Sites Guide](sites-guide.md)** - Creating and managing websites
- **[Example API](apis-guide.md#-example-api-reference)** - Hands-on learning
- **[Local Development](../README.md#-local-development)** - Testing with Makefile commands

### **🛠️ Advanced Topics**
- **[Infrastructure Components](../infrastructure/)** - Network and security setup
- **[Monitoring Stack](../monitoring/)** - Observability and metrics
- **[LGTM Testing with Argus](https://github.com/nahuelsantos/argus)** - Comprehensive stack validation
- **[Service Configuration](../services/)** - Individual service setup

## 🎯 Quick Navigation

### **For New Users**
1. Start with the **[Main README](../README.md)**
2. Run `sudo ./dinky.sh` for interactive setup

### **For Developers**
1. Read the **[APIs Guide](apis-guide.md)** for API development
2. Check the **[Sites Guide](sites-guide.md)** for website hosting
3. Try the **[Example API](apis-guide.md#-example-api-reference)** for hands-on learning
4. Use `make up` for local testing

### **For System Administrators**
1. Review **[Infrastructure Documentation](../infrastructure/)**
2. Configure **[Monitoring](../monitoring/)** for observability
3. Set up **[Security](../infrastructure/firewall/)** policies

## 🔍 Finding What You Need

### **Common Tasks**
- **Deploy new service** → [APIs Guide](apis-guide.md) or [Sites Guide](sites-guide.md)
- **Security setup** → [Main README - Security Features](../README.md#-what-you-get)
- **Troubleshooting** → [Main README - Troubleshooting](../README.md#-troubleshooting)
- **Local development** → [Main README - Development](../README.md#-local-development)

### **Service-Specific Documentation**
- **Traefik** → `infrastructure/traefik/`
- **Pi-hole** → `infrastructure/pihole/`
- **Monitoring** → `monitoring/` directory
- **Mail Server** → `services/mail-server/`
- **Cloudflare Tunnel** → `infrastructure/cloudflared/`

## 📝 Documentation Standards

Our documentation follows these principles:
- **Clear examples** for all configurations
- **Step-by-step instructions** for complex tasks
- **Troubleshooting sections** for common issues
- **Security considerations** for all setups
- **Development-friendly** with local testing guides

## 🤝 Contributing

When adding documentation:
1. Follow the existing structure and formatting
2. Include practical examples
3. Add troubleshooting tips
4. Keep security considerations in mind
5. Test all instructions before committing

## 🔗 External Resources

- **Docker Documentation** - https://docs.docker.com/
- **Traefik Documentation** - https://doc.traefik.io/traefik/
- **Pi-hole Documentation** - https://docs.pi-hole.net/
- **Grafana Documentation** - https://grafana.com/docs/
- **Prometheus Documentation** - https://prometheus.io/docs/

## 🔌 Complete Port Reference

### Web UI Services
- **8080** - Traefik Dashboard  
- **8081** - Pi-hole Admin Interface
- **9000** - Portainer Container Management
- **3000** - Grafana Dashboards
- **9090** - Prometheus Metrics UI
- **9093** - Alertmanager Web Interface
- **3100** - Loki (no UI, API only)
- **3200** - Tempo (no UI, API only) 
- **4040** - Pyroscope Profiling UI
- **8082** - cAdvisor Container Metrics
- **9100** - Node Exporter (metrics endpoint)
- **3001** - Argus LGTM Stack Validator

### Monitoring & Telemetry Endpoints
- **4317** - OTEL Collector (gRPC)
- **4318** - OTEL Collector (HTTP) 
- **8888** - OTEL Collector Internal Metrics
- **8889** - OTEL Collector Prometheus Metrics
- **8080** - Traefik Dashboard & Metrics (at /metrics path)
- **1777** - OTEL Collector pprof endpoint
- **13133** - OTEL Collector health check
- **55679** - OTEL Collector zpages

### Core Infrastructure  
- **25** - SMTP (Mail Server)
- **53** - DNS (Pi-hole) 
- **80** - HTTP (Traefik, internal)
- **443** - HTTPS (Traefik, internal)
- **587** - SMTP Submission (Mail Server)
- **8000** - Portainer Edge Agent

### Example Services
- **3003** - Example API (Simple REST API)
- **3004** - Example Site (Simple Static Site)

### LGTM Testing
- **3001** - Argus LGTM Stack Validator ([Source Code](https://github.com/nahuelsantos/argus))

### Reserved Port Ranges

**For User APIs:**
- **3002-3099** - Recommended for APIs (avoiding 3001, 3003)

**For User Sites:**  
- **8003-8099** - Recommended for Sites (avoiding 8080-8082, 8088-8089)

**Avoid Using:**
- **1-1024** - System reserved ports
- **3000-3299** - LGTMA stack and core services
- **4000-4400** - Telemetry and profiling  
- **8080-8082, 8088-8089** - Traefik and monitoring
- **9000-9199** - Prometheus ecosystem

## 🔒 Security Considerations

All external services are bound to `${SERVER_IP}` (not 0.0.0.0) for security:
- Only accessible from local network or configured tunnels
- Cloudflared provides secure external access without port forwarding
- Internal container communication uses Docker networks

## 📊 Monitoring Integration

All services automatically export metrics to Prometheus:
- Container metrics via cAdvisor
- System metrics via Node Exporter  
- Application metrics via OTEL Collector
- Custom metrics via your applications

For detailed monitoring setup, see the main [README.md](../README.md#monitoring--observability). 