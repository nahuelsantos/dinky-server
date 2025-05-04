#!/bin/bash
#
# Dinky Server - Master Installation Script
# This script allows selective installation of components for the Dinky Server

# Check if running with sudo/as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo or as root"
    echo "Please run: sudo $0"
    exit 1
fi

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

# Default IP address (configurable)
DEFAULT_IP="192.168.3.2"
CONFIG_FILE="install.conf"

# Determine Docker Compose command
determine_docker_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
        success "Using docker-compose command"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        success "Using docker compose command"
    else
        error "Neither docker-compose nor docker compose found"
        exit 1
    fi
}

# Header display function
header() {
    echo -e "\n${BLUE}======================================================${NC}"
    echo -e "${BLUE}   $1${NC}"
    echo -e "${BLUE}======================================================${NC}"
}

# Section display function
section() {
    echo -e "\n${CYAN}>> $1${NC}"
}

# Success message function
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Error message function
error() {
    echo -e "${RED}✗ $1${NC}"
}

# Warning message function
warning() {
    echo -e "${YELLOW}! $1${NC}"
}

# Check system requirements
check_requirements() {
    section "Checking system requirements"
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        warning "Docker not found. Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        success "Docker installed"
    else
        success "Docker is installed"
    fi
    
    # Check for Docker Compose (either as a plugin or standalone)
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        warning "Docker Compose not found. Installing Docker Compose plugin..."
        apt-get update
        apt-get install -y docker-compose-plugin
        success "Docker Compose installed"
    else
        success "Docker Compose is installed"
    fi
    
    # Determine Docker Compose command
    determine_docker_compose_cmd
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        warning "curl not found. Installing curl..."
        apt-get update
        apt-get install -y curl
        success "curl installed"
    else
        success "curl is installed"
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    success "Detected architecture: $ARCH"
    
    # Check for network connectivity
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        success "Network connectivity confirmed"
    else
        warning "Network connectivity issues detected. Some components may not install correctly."
    fi
}

# Create the required directories if they don't exist
create_directories() {
    section "Creating required directories"
    
    # Create directories if they don't exist
    mkdir -p services/mail-server/sasl
    touch services/mail-server/sasl/sasl_passwd
    
    success "Directories created"
}

# Create Docker networks
create_networks() {
    section "Setting up Docker networks"
    
    # Create traefik network if it doesn't exist
    if ! docker network inspect traefik_network >/dev/null 2>&1; then
        docker network create traefik_network
        success "Created traefik_network"
    else
        success "traefik_network already exists"
    fi
    
    # Create mail internal network if it doesn't exist
    if ! docker network inspect mail-internal >/dev/null 2>&1; then
        docker network create mail-internal
        success "Created mail-internal network"
    else
        success "mail-internal network already exists"
    fi
}

# Configure environment variables
configure_environment() {
    section "Configuring environment variables"
    
    # Check if .env file exists, if not create from example
    if [ ! -f .env ]; then
        cp .env.example .env
        warning "Created .env file from example. Please edit it with your settings."
        
        # Replace default IP with configured IP
        sed -i "s/192.168.3.2/$SERVER_IP/g" .env
        
        success "Environment file created"
    else
        success "Environment file already exists"
    fi
    
    # Reload environment variables
    if [ -f .env ]; then
        set -a
        source .env
        set +a
        success "Environment variables loaded"
    fi
}

# Install security components
install_security() {
    header "Installing Security Components"
    
    # Run master security setup
    bash infrastructure/firewall/master-security-setup.sh
    
    success "Security components installed"
}

# Install core infrastructure
install_core() {
    header "Installing Core Infrastructure (Traefik, Cloudflared, Pi-hole, Portainer)"
    
    # Create environment variables for core services if needed
    if [ ! -f .env ]; then
        warning "Environment file not found. Running configuration first."
        configure_environment
    fi
    
    # Start core services
    $DOCKER_COMPOSE_CMD up -d traefik cloudflared pihole portainer
    
    success "Core infrastructure installed and running"
}

# Check and update service images in docker-compose.yml files
update_services_images() {
    section "Checking service image references"
    
    # Update mail service Dockerfiles if they reference the wrong image tag format
    if [ -f "services/docker-compose.yml" ]; then
        # Fixed image names instead of using variables that might resolve incorrectly
        sed -i 's|image: ${REGISTRY}/${PROJECT}/mail-server:${TAG}|image: alpine:3.18|g' services/docker-compose.yml
        sed -i 's|image: ${REGISTRY}/${PROJECT}/mail-api:${TAG}|image: node:18-alpine|g' services/docker-compose.yml
        
        # Add build contexts if they don't exist
        if ! grep -q "build:" services/docker-compose.yml; then
            sed -i '/image: alpine:3.18/a\    build:\n      context: ./mail-server\n      dockerfile: Dockerfile' services/docker-compose.yml
            sed -i '/image: node:18-alpine/a\    build:\n      context: ../apis/mail-api\n      dockerfile: Dockerfile' services/docker-compose.yml
        fi
        
        success "Updated mail service image references"
    else
        warning "Could not find services/docker-compose.yml"
    fi
}

# Install mail services
install_mail() {
    header "Installing Mail Services"
    
    # Check for mail environment variables
    if [ ! -f .env.mail ] && [ -f .env.mail.example ]; then
        cp .env.mail.example .env.mail
        warning "Created mail environment file. Please edit it with your settings."
    elif [ ! -f .env.mail ] && [ ! -f .env.mail.example ]; then
        warning "Mail environment files not found. Creating a basic one."
        cat > .env.mail << EOF
# Mail server configuration
MAIL_DOMAIN=${DOMAIN_NAME:-nahuelsantos.com}
MAIL_HOSTNAME=mail.${DOMAIN_NAME:-nahuelsantos.com}
DEFAULT_FROM=noreply@${DOMAIN_NAME:-nahuelsantos.com}
ALLOWED_HOSTS=${DOMAIN_NAME:-nahuelsantos.com}

# SMTP Relay Settings
SMTP_RELAY_HOST=smtp.gmail.com
SMTP_RELAY_PORT=587
SMTP_RELAY_USERNAME=your-gmail-address@gmail.com
SMTP_RELAY_PASSWORD=your-16-character-app-password
USE_TLS=yes
TLS_VERIFY=yes
EOF
    fi
    
    # Build mail services first
    section "Building mail services"
    export ENVIRONMENT=production
    export TRAEFIK_ENTRYPOINT=https
    export ENABLE_TLS=true
    export RESTART_POLICY=always
    export MIDDLEWARE_CHAIN=secured@file
    export SERVER_IP=${SERVER_IP:-192.168.3.2}
    
    # Set SSL paths for production
    if [ -d "/etc/letsencrypt/live/${DOMAIN_NAME}" ]; then
        export SSL_CERT_PATH=/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem
        export SSL_KEY_PATH=/etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem
    fi
    
    $DOCKER_COMPOSE_CMD build mail-server mail-api
    
    # Install and start mail services
    section "Starting mail services"
    $DOCKER_COMPOSE_CMD up -d mail-server mail-api
    
    success "Mail services installed and running"
}

# Install websites
install_websites() {
    header "Installing Websites"
    
    # Install nahuelsantos.com
    section "Installing nahuelsantos.com"
    $DOCKER_COMPOSE_CMD -f sites/nahuelsantos/docker-compose.yml up -d
    success "nahuelsantos.com installed"
    
    # Install loopingbyte.com
    section "Installing loopingbyte.com"
    $DOCKER_COMPOSE_CMD -f sites/loopingbyte/docker-compose.yml up -d
    success "loopingbyte.com installed"
}

# Install monitoring tools
install_monitoring() {
    header "Installing Monitoring Stack"
    
    # Run monitoring setup script if it exists
    if [ -f monitoring/setup-monitoring.sh ]; then
        bash monitoring/setup-monitoring.sh
    else
        # Start monitoring stack directly
        $DOCKER_COMPOSE_CMD up -d prometheus loki promtail tempo pyroscope grafana otel-collector
    fi
    
    success "Monitoring stack installed and running"
}

# Test installation
test_installation() {
    header "Testing Installation"
    
    # Test core services
    section "Testing core services"
    if docker ps | grep -q traefik; then
        success "Traefik is running"
    else
        error "Traefik is not running"
    fi
    
    if docker ps | grep -q cloudflared; then
        success "Cloudflared is running"
    else
        error "Cloudflared is not running"
    fi
    
    if docker ps | grep -q pihole; then
        success "Pi-hole is running"
    else
        error "Pi-hole is not running"
    fi
    
    if docker ps | grep -q portainer; then
        success "Portainer is running"
    else
        error "Portainer is not running"
    fi
    
    # Test mail services if requested
    if [ "$INSTALL_MAIL" = "Y" ]; then
        section "Testing mail services"
        if docker ps | grep -q mail-server; then
            success "Mail server is running"
        else
            error "Mail server is not running"
        fi
        
        if docker ps | grep -q mail-api; then
            success "Mail API is running"
        else
            error "Mail API is not running"
        fi
    fi
    
    # Test websites if requested
    if [ "$INSTALL_WEBSITES" = "Y" ]; then
        section "Testing websites"
        if docker ps | grep -q nahuelsantos; then
            success "nahuelsantos.com is running"
        else
            error "nahuelsantos.com is not running"
        fi
        
        if docker ps | grep -q looping-byte; then
            success "loopingbyte.com is running"
        else
            error "loopingbyte.com is not running"
        fi
    fi
    
    # Test monitoring if requested
    if [ "$INSTALL_MONITORING" = "Y" ]; then
        section "Testing monitoring stack"
        MONITORING_SERVICES=("prometheus" "loki" "promtail" "tempo" "pyroscope" "grafana" "otel-collector")
        
        for service in "${MONITORING_SERVICES[@]}"; do
            if docker ps | grep -q "$service"; then
                success "$service is running"
            else
                error "$service is not running"
            fi
        done
    fi
    
    echo ""
    success "Testing completed"
}

# Save configuration
save_configuration() {
    cat > "$CONFIG_FILE" << EOF
# Dinky Server installation configuration
# Generated on $(date)
SERVER_IP=$SERVER_IP
INSTALL_SECURITY=$INSTALL_SECURITY
INSTALL_CORE=$INSTALL_CORE
INSTALL_MAIL=$INSTALL_MAIL
INSTALL_WEBSITES=$INSTALL_WEBSITES
INSTALL_MONITORING=$INSTALL_MONITORING
EOF
    success "Configuration saved to $CONFIG_FILE"
}

# Load configuration if it exists
load_configuration() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        success "Loaded existing configuration from $CONFIG_FILE"
        return 0
    fi
    return 1
}

# Interactive mode to configure installation
configure_installation() {
    header "Dinky Server Installation Configuration"
    
    echo "This script will help you set up your Dinky Server with the components you need."
    echo "You can install all components or select specific ones."
    echo ""
    
    # Get server IP
    read -p "Enter server IP address [$DEFAULT_IP]: " SERVER_IP
    SERVER_IP=${SERVER_IP:-$DEFAULT_IP}
    
    # Security
    read -p "Install security components? (Y/n): " INSTALL_SECURITY
    INSTALL_SECURITY=${INSTALL_SECURITY:-Y}
    
    # Core infrastructure
    read -p "Install core infrastructure (Traefik, Cloudflared, Pi-hole, Portainer)? (Y/n): " INSTALL_CORE
    INSTALL_CORE=${INSTALL_CORE:-Y}
    
    # Mail services
    read -p "Install mail services? (Y/n): " INSTALL_MAIL
    INSTALL_MAIL=${INSTALL_MAIL:-Y}
    
    # Websites
    read -p "Install websites (nahuelsantos.com, loopingbyte.com)? (Y/n): " INSTALL_WEBSITES
    INSTALL_WEBSITES=${INSTALL_WEBSITES:-Y}
    
    # Monitoring
    read -p "Install monitoring stack? (Y/n): " INSTALL_MONITORING
    INSTALL_MONITORING=${INSTALL_MONITORING:-Y}
    
    # Confirm configuration
    echo ""
    echo "Configuration Summary:"
    echo "- Server IP: $SERVER_IP"
    echo "- Install Security: $INSTALL_SECURITY"
    echo "- Install Core Infrastructure: $INSTALL_CORE"
    echo "- Install Mail Services: $INSTALL_MAIL"
    echo "- Install Websites: $INSTALL_WEBSITES"
    echo "- Install Monitoring: $INSTALL_MONITORING"
    echo ""
    
    read -p "Is this configuration correct? (Y/n): " CONFIRM
    CONFIRM=${CONFIRM:-Y}
    
    if [[ "$CONFIRM" != "Y" && "$CONFIRM" != "y" ]]; then
        echo "Configuration cancelled. Please run the script again."
        exit 1
    fi
    
    # Save configuration
    save_configuration
}

# Main installation process
install() {
    # Create directories and networks
    create_directories
    create_networks
    
    # Configure environment
    configure_environment
    
    # Install selected components
    if [[ "$INSTALL_SECURITY" == "Y" || "$INSTALL_SECURITY" == "y" ]]; then
        install_security
    fi
    
    if [[ "$INSTALL_CORE" == "Y" || "$INSTALL_CORE" == "y" ]]; then
        install_core
    fi
    
    if [[ "$INSTALL_MAIL" == "Y" || "$INSTALL_MAIL" == "y" ]]; then
        install_mail
    fi
    
    if [[ "$INSTALL_WEBSITES" == "Y" || "$INSTALL_WEBSITES" == "y" ]]; then
        install_websites
    fi
    
    if [[ "$INSTALL_MONITORING" == "Y" || "$INSTALL_MONITORING" == "y" ]]; then
        install_monitoring
    fi
    
    # Test installation
    test_installation
}

# Display welcome message
welcome() {
    clear
    header "Welcome to Dinky Server Installation"
    echo "This script will help you install and configure your Dinky Server."
    echo "The installation can be customized to include only the components you need."
    echo ""
    echo "Components available for installation:"
    echo "1. Security (firewall, fail2ban, SSH hardening)"
    echo "2. Core Infrastructure (Traefik, Cloudflared, Pi-hole, Portainer)"
    echo "3. Mail Services (mail server and API)"
    echo "4. Websites (nahuelsantos.com, loopingbyte.com)"
    echo "5. Monitoring Stack (Prometheus, Loki, Grafana, etc.)"
    echo ""
    echo "You can run this script with the following options:"
    echo "  ./install.sh           - Interactive mode"
    echo "  ./install.sh --auto    - Non-interactive mode (uses saved config or defaults)"
    echo "  ./install.sh --help    - Display this help message"
    echo ""
}

# Display help
show_help() {
    welcome
    exit 0
}

# Main execution
main() {
    welcome
    
    # Check system requirements
    check_requirements
    
    # Load existing configuration or configure interactively
    if [[ "$1" == "--auto" ]]; then
        if ! load_configuration; then
            warning "No configuration file found. Using defaults."
            SERVER_IP="$DEFAULT_IP"
            INSTALL_SECURITY="Y"
            INSTALL_CORE="Y"
            INSTALL_MAIL="Y"
            INSTALL_WEBSITES="Y"
            INSTALL_MONITORING="Y"
            save_configuration
        fi
    else
        configure_installation
    fi
    
    # Install components
    install
    
    # Display completion message
    header "Installation Complete"
    echo "Your Dinky Server has been set up with the following components:"
    
    if [[ "$INSTALL_SECURITY" == "Y" || "$INSTALL_SECURITY" == "y" ]]; then
        echo "- Security components"
    fi
    
    if [[ "$INSTALL_CORE" == "Y" || "$INSTALL_CORE" == "y" ]]; then
        echo "- Core infrastructure (Traefik, Cloudflared, Pi-hole, Portainer)"
    fi
    
    if [[ "$INSTALL_MAIL" == "Y" || "$INSTALL_MAIL" == "y" ]]; then
        echo "- Mail services"
    fi
    
    if [[ "$INSTALL_WEBSITES" == "Y" || "$INSTALL_WEBSITES" == "y" ]]; then
        echo "- Websites (nahuelsantos.com, loopingbyte.com)"
    fi
    
    if [[ "$INSTALL_MONITORING" == "Y" || "$INSTALL_MONITORING" == "y" ]]; then
        echo "- Monitoring stack"
    fi
    
    echo ""
    echo "You can access the services at the following URLs:"
    echo "- Portainer: http://$SERVER_IP:9000"
    echo "- Traefik Dashboard: http://$SERVER_IP:20000"
    echo "- Pi-hole Admin: http://$SERVER_IP:19999"
    echo "- Grafana: http://$SERVER_IP:3000"
    echo ""
    echo "For more information, see the documentation in the GitHub Wiki:"
    echo "https://github.com/nahuelsantos/dinky-server/wiki"
}

# Process command line arguments
if [[ "$1" == "--help" ]]; then
    show_help
elif [[ "$1" == "--auto" ]]; then
    main "--auto"
else
    main
fi 