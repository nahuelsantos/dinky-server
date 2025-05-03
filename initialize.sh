#!/bin/bash
#
# Dinky Server - Initialization Script
# This script initializes the Dinky Server repository for a fresh installation
# It ensures proper file permissions and creates any missing required files

# ANSI color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script location
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR" || { echo "Failed to change directory to script directory"; exit 1; }

# Print section header
header() {
    echo -e "\n${BLUE}======================================================${NC}"
    echo -e "${BLUE}   $1${NC}"
    echo -e "${BLUE}======================================================${NC}"
}

# Print section
section() {
    echo -e "\n${CYAN}>> $1${NC}"
}

# Print success message
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print warning message
warning() {
    echo -e "${YELLOW}! $1${NC}"
}

# Print error message
error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Create necessary directories
create_directories() {
    section "Creating necessary directories"
    
    # Create directories
    mkdir -p services/mail-server-logs
    mkdir -p services/mail-server/sasl
    mkdir -p monitoring/grafana
    mkdir -p monitoring/prometheus
    mkdir -p monitoring/loki
    mkdir -p monitoring/promtail
    mkdir -p monitoring/tempo
    mkdir -p monitoring/pyroscope
    mkdir -p monitoring/otel-collector
    mkdir -p infrastructure/traefik
    mkdir -p infrastructure/cloudflared
    mkdir -p infrastructure/pihole
    mkdir -p infrastructure/firewall
    mkdir -p sites/nahuelsantos
    mkdir -p sites/loopingbyte
    mkdir -p apis/mail-api
    mkdir -p wiki_content
    
    success "Directories created"
}

# Set proper file permissions
set_permissions() {
    section "Setting file permissions"
    
    # Make scripts executable
    chmod +x install.sh
    chmod +x test.sh
    chmod +x initialize.sh
    
    if [ -d "scripts" ]; then
        find scripts -name "*.sh" -exec chmod +x {} \;
        success "Script permissions set"
    else
        warning "Scripts directory not found, skipping"
    fi
    
    if [ -d "infrastructure/firewall" ]; then
        find infrastructure/firewall -name "*.sh" -exec chmod +x {} \;
        success "Firewall script permissions set"
    fi
    
    if [ -d "monitoring" ]; then
        find monitoring -name "*.sh" -exec chmod +x {} \;
        success "Monitoring script permissions set"
    fi
    
    # Touch required files if they don't exist
    touch services/mail-server/sasl/sasl_passwd
    chmod 600 services/mail-server/sasl/sasl_passwd
    
    success "File permissions set"
}

# Create example environment file if it doesn't exist
create_env_example() {
    section "Checking environment files"
    
    if [ ! -f ".env.example" ]; then
        warning ".env.example file not found, creating one..."
        
        cat > .env.example << EOF
# Project Configuration
PROJECT=dinky
REGISTRY=nahuelsantos
TAG=latest

# Domain Configuration
DOMAIN_NAME=nahuelsantos.com
MAIL_DOMAIN=nahuelsantos.com
BASE_DOMAIN=nahuelsantos.com
API_URL=api.nahuelsantos.com
ALLOWED_HOSTS=nahuelsantos.com,loopingbyte.com

# Mail Server Configuration
MAIL_USER=admin
MAIL_PASSWORD=your-secure-mail-password
DEFAULT_FROM=hi@nahuelsantos.com
FORWARD_EMAIL=your-personal-email@example.com
MAIL_HOSTNAME=mail.nahuelsantos.com

# SMTP Relay Configuration (Gmail)
SMTP_RELAY_HOST=smtp.gmail.com
SMTP_RELAY_PORT=587
SMTP_RELAY_USERNAME=your-gmail-username@gmail.com
SMTP_RELAY_PASSWORD=your-gmail-app-password
USE_TLS=yes
TLS_VERIFY=yes

# Optional Mail Configuration
MAIL_SECURE=false
MAIL_PORT=25

# Cloudflared settings
TUNNEL_ID=your-tunnel-id-here
TUNNEL_TOKEN=your-tunnel-token-here

# Pihole settings
PIHOLE_PASSWORD=your-pihole-password

# Grafana settings
GRAFANA_PASSWORD=your-grafana-password
EOF
        
        success "Created .env.example file"
    else
        success ".env.example file exists"
    fi
    
    # Check if .env file exists, if it does, don't overwrite it
    if [ ! -f ".env" ]; then
        warning ".env file not found. You'll need to create one before installation."
        echo "You can create it by running: cp .env.example .env"
        echo "Then edit it with your specific settings."
    else
        success ".env file exists"
    fi
}

# Check for docker-compose.yml
check_docker_compose() {
    section "Checking docker-compose.yml"
    
    if [ ! -f "docker-compose.yml" ]; then
        error "docker-compose.yml file not found. This is required for installation."
        exit 1
    else
        success "docker-compose.yml file exists"
    fi
}

# Ensure Docker networks exist
create_networks() {
    section "Ensuring Docker networks exist"
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        warning "Docker is not installed or not in PATH. Networks will be created during installation."
        return
    fi
    
    # Check if Docker can be run
    if ! docker ps &> /dev/null; then
        warning "Docker is not running or requires root privileges. Networks will be created during installation."
        return
    fi
    
    # Create networks if they don't exist
    if ! docker network inspect traefik_network &> /dev/null; then
        docker network create traefik_network
        success "Created traefik_network"
    else
        success "traefik_network already exists"
    fi
    
    if ! docker network inspect mail-internal &> /dev/null; then
        docker network create mail-internal
        success "Created mail-internal network"
    else
        success "mail-internal network already exists"
    fi
}

# Main function
main() {
    header "Dinky Server Initialization"
    echo "This script will initialize the Dinky Server repository for installation."
    echo ""
    
    # Create directories
    create_directories
    
    # Set permissions
    set_permissions
    
    # Create environment file example
    create_env_example
    
    # Check for docker-compose.yml
    check_docker_compose
    
    # Create Docker networks
    create_networks
    
    # Final message
    header "Initialization Complete"
    echo "Your Dinky Server repository has been initialized."
    echo "Next steps:"
    echo "1. Edit the .env file with your specific settings"
    echo "2. Run install.sh to install the components you need"
    echo "   $ sudo ./install.sh"
    echo ""
    echo "For more information, see the documentation in the GitHub Wiki:"
    echo "https://github.com/nahuelsantos/dinky-server/wiki"
}

# Run main function
main 