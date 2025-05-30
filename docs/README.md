# Dinky Server Documentation

Welcome to the Dinky Server documentation! This directory contains comprehensive guides for setting up, configuring, and managing your self-hosted server infrastructure.

## 📚 Available Guides

### **🚀 Getting Started**
- **[Main README](../README.md)** - Complete setup guide and overview
- **[Quick Start](../README.md#getting-started)** - Fast deployment instructions
- **[Configuration Guide](../config/README.md)** - Environment and service configuration

### **🔧 Development Guides**
- **[APIs Guide](apis-guide.md)** - Building and deploying API services
- **[Sites Guide](sites-guide.md)** - Creating and managing websites
- **[Local Development](../README.md#local-development)** - Testing with Makefile commands

### **🛠️ Advanced Topics**
- **[Infrastructure Components](../infrastructure/)** - Network and security setup
- **[Monitoring Stack](../monitoring/)** - Observability and metrics
- **[Service Configuration](../services/)** - Individual service setup

## 🎯 Quick Navigation

### **For New Users**
1. Start with the **[Main README](../README.md)**
2. Run `sudo ./dinky.sh` for interactive setup
3. Follow the **[Configuration Guide](../config/README.md)** for customization

### **For Developers**
1. Read the **[APIs Guide](apis-guide.md)** for API development
2. Check the **[Sites Guide](sites-guide.md)** for website hosting
3. Try the **[Example API](apis-guide.md#-example-api-reference)** for hands-on learning
4. Use `make dev-up` for local testing

### **For System Administrators**
1. Review **[Infrastructure Documentation](../infrastructure/)**
2. Configure **[Monitoring](../monitoring/)** for observability
3. Set up **[Security](../infrastructure/firewall/)** policies

## 🔍 Finding What You Need

### **Common Tasks**
- **Deploy new service** → [APIs Guide](apis-guide.md) or [Sites Guide](sites-guide.md)
- **Configure environment** → [Configuration Guide](../config/README.md)
- **Security setup** → [Main README - Security](../README.md#security-levels)
- **Troubleshooting** → [Main README - Troubleshooting](../README.md#troubleshooting)
- **Local development** → [Main README - Development](../README.md#local-development)

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