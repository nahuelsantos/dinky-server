#!/bin/bash
# Dinky Server Deployment Script
# Comprehensive deployment solution for Raspberry Pi and other devices

set -e

# Color definitions for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/dinky-deployment.log"
BACKUP_DIR="/opt/dinky-backups/$(date +%Y%m%d_%H%M%S)"
DEPLOYED_COMPONENTS_FILE="/opt/dinky-server/deployed-components.txt"

# Auto-detect Docker Compose command
DOCKER_COMPOSE=""
detect_docker_compose() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE="docker-compose"
    else
        error "Neither 'docker compose' nor 'docker-compose' is available"
        error "Please install Docker Compose first"
        exit 1
    fi
    info "Using Docker Compose command: $DOCKER_COMPOSE"
}

# Component flags
INSTALL_TRAEFIK=false
INSTALL_CLOUDFLARED=false
INSTALL_PIHOLE=false
INSTALL_MONITORING=false
INSTALL_MAIL=false
DISCOVERED_SERVICES=()

# Command line flags
DISCOVER_ONLY=false
ADD_SERVICE=""
ADD_TYPE=""
LIST_SERVICES=false
HELP_FLAG=false

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --discover)
                DISCOVER_ONLY=true
                shift
                ;;
            --add-site)
                ADD_TYPE="site"
                ADD_SERVICE="$2"
                shift 2
                ;;
            --add-api)
                ADD_TYPE="api"
                ADD_SERVICE="$2"
                shift 2
                ;;
            --list)
                LIST_SERVICES=true
                shift
                ;;
            --help|-h)
                HELP_FLAG=true
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help
show_help() {
    echo -e "${CYAN}Dinky Server Deployment Script${NC}"
    echo -e "${CYAN}==============================${NC}\n"
    echo -e "${WHITE}Usage:${NC}"
    echo -e "  ${GREEN}sudo ./deploy.sh${NC}                    # Full deployment"
    echo -e "  ${GREEN}sudo ./deploy.sh --discover${NC}         # Discover and deploy new services"
    echo -e "  ${GREEN}sudo ./deploy.sh --add-site <name>${NC}  # Deploy specific site"
    echo -e "  ${GREEN}sudo ./deploy.sh --add-api <name>${NC}   # Deploy specific API"
    echo -e "  ${GREEN}sudo ./deploy.sh --list${NC}             # List all available services"
    echo -e "  ${GREEN}sudo ./deploy.sh --help${NC}             # Show this help"
    echo
    echo -e "${WHITE}Examples:${NC}"
    echo -e "  ${YELLOW}# Initial deployment${NC}"
    echo -e "  sudo ./deploy.sh"
    echo
    echo -e "  ${YELLOW}# Add a new blog site later${NC}"
    echo -e "  sudo ./deploy.sh --add-site my-blog"
    echo
    echo -e "  ${YELLOW}# Add a new API later${NC}"
    echo -e "  sudo ./deploy.sh --add-api user-service"
    echo
    echo -e "  ${YELLOW}# Discover all new services${NC}"
    echo -e "  sudo ./deploy.sh --discover"
    echo
    echo -e "  ${YELLOW}# List all available services${NC}"
    echo -e "  sudo ./deploy.sh --list"
}

# Utility functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" >/dev/null
    echo -e "$1"
}

success() {
    log "${GREEN}✓ $1${NC}"
}

error() {
    log "${RED}✗ ERROR: $1${NC}"
}

warning() {
    log "${YELLOW}⚠ WARNING: $1${NC}"
}

info() {
    log "${BLUE}ℹ INFO: $1${NC}"
}

header() {
    echo -e "\n${PURPLE}============================================================${NC}"
    echo -e "${PURPLE}   $1${NC}"
    echo -e "${PURPLE}============================================================${NC}\n"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root or with sudo"
        echo -e "${YELLOW}Please run: sudo $0${NC}"
        exit 1
    fi
}

# Create necessary directories
setup_directories() {
    info "Setting up directories..."
    mkdir -p "$BACKUP_DIR"
    mkdir -p "/opt/dinky-server"
    mkdir -p "/var/log"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    success "Directories created"
}

# Backup existing configuration
backup_existing_config() {
    info "Creating backup of existing configuration..."
    
    # Backup important files
    local files_to_backup=(
        "/etc/docker/daemon.json"
        "/etc/ufw/user.rules"
        "/etc/fail2ban/jail.local"
        "/etc/ssh/sshd_config"
        "$SCRIPT_DIR/docker-compose.yml"
        "$SCRIPT_DIR/.env"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    
    success "Backup created at $BACKUP_DIR"
}

# Rollback function
rollback() {
    error "Deployment failed. Initiating rollback..."
    
    # Stop any running containers
    cd "$SCRIPT_DIR"
    docker compose down 2>/dev/null || true
    
    # Restore backed up files
    if [ -d "$BACKUP_DIR" ]; then
        info "Restoring configuration files..."
        cp "$BACKUP_DIR"/* /etc/ 2>/dev/null || true
        cp "$BACKUP_DIR/docker-compose.yml" "$SCRIPT_DIR/" 2>/dev/null || true
        cp "$BACKUP_DIR/.env" "$SCRIPT_DIR/" 2>/dev/null || true
    fi
    
    warning "Rollback completed. Check logs at $LOG_FILE for details."
    exit 1
}

# Trap errors for rollback
trap rollback ERR

# Check system requirements
check_requirements() {
    header "Checking System Requirements"
    
    # Check OS
    if ! grep -q "Raspberry Pi\|Ubuntu\|Debian" /proc/version 2>/dev/null; then
        warning "This script is optimized for Raspberry Pi OS, Ubuntu, or Debian"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check available space
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 2097152 ]; then # 2GB in KB
        warning "Less than 2GB free space available. Some components may fail to install."
    fi
    
    # Check memory
    local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    if [ "$total_mem" -lt 1048576 ]; then # 1GB in KB
        warning "Less than 1GB RAM available. Consider enabling swap or reducing components."
    fi
    
    success "System requirements check completed"
}

# Install dependencies
install_dependencies() {
    header "Installing Dependencies"
    
    info "Updating package lists..."
    apt update
    
    info "Installing essential packages..."
    apt install -y \
        curl \
        wget \
        git \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        jq \
        htop \
        nano \
        ufw \
        fail2ban
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        
        # Add current user to docker group
        usermod -aG docker $SUDO_USER 2>/dev/null || true
        
        success "Docker installed"
    else
        success "Docker already installed"
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker compose &> /dev/null; then
        info "Installing Docker Compose..."
        
        # For newer systems, Docker Compose is included with Docker
        if ! docker compose version &> /dev/null; then
            # Fallback to standalone installation
            local compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
            curl -L "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
        fi
        
        success "Docker Compose installed"
    else
        success "Docker Compose already installed"
    fi
    
    # Start Docker service
    systemctl enable docker
    systemctl start docker
    
    success "All dependencies installed"
}

# Component selection menu
select_components() {
    header "Component Selection"
    
    echo -e "${WHITE}Select components to install:${NC}\n"
    
    # Traefik (required for most setups)
    echo -e "${CYAN}1. Traefik (Reverse Proxy)${NC} - ${GREEN}Recommended${NC}"
    read -p "   Install Traefik? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        INSTALL_TRAEFIK=false
    else
        INSTALL_TRAEFIK=true
    fi
    
    # Cloudflared (optional)
    echo -e "\n${CYAN}2. Cloudflared (Cloudflare Tunnel)${NC} - ${YELLOW}Optional${NC}"
    echo -e "   ${WHITE}Provides secure external access without port forwarding${NC}"
    read -p "   Install Cloudflared? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_CLOUDFLARED=true
    fi
    
    # Pi-hole
    echo -e "\n${CYAN}3. Pi-hole (DNS & Ad Blocking)${NC} - ${GREEN}Recommended${NC}"
    read -p "   Install Pi-hole? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        INSTALL_PIHOLE=false
    else
        INSTALL_PIHOLE=true
    fi
    
    # Monitoring
    echo -e "\n${CYAN}4. Monitoring Stack (Prometheus, Grafana, Loki)${NC} - ${GREEN}Recommended${NC}"
    echo -e "   ${WHITE}Provides comprehensive system monitoring and alerting${NC}"
    read -p "   Install Monitoring? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        INSTALL_MONITORING=false
    else
        INSTALL_MONITORING=true
    fi
    
    # Mail server
    echo -e "\n${CYAN}5. Mail Server (SMTP Relay + API)${NC} - ${YELLOW}Optional${NC}"
    echo -e "   ${WHITE}Provides email sending capabilities${NC}"
    read -p "   Install Mail Server? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_MAIL=true
    fi
    
    # Summary
    echo -e "\n${WHITE}Selected components:${NC}"
    $INSTALL_TRAEFIK && echo -e "  ${GREEN}✓${NC} Traefik"
    $INSTALL_CLOUDFLARED && echo -e "  ${GREEN}✓${NC} Cloudflared"
    $INSTALL_PIHOLE && echo -e "  ${GREEN}✓${NC} Pi-hole"
    $INSTALL_MONITORING && echo -e "  ${GREEN}✓${NC} Monitoring Stack"
    $INSTALL_MAIL && echo -e "  ${GREEN}✓${NC} Mail Server"
    
    echo
    read -p "Proceed with installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        info "Installation cancelled by user"
        exit 0
    fi
}

# Discover APIs and Sites
discover_services() {
    header "Discovering Additional Services"
    
    info "Scanning apis/ and sites/ directories..."
    
    # Scan apis directory
    if [ -d "$SCRIPT_DIR/apis" ]; then
        while IFS= read -r -d '' compose_file; do
            local service_dir=$(dirname "$compose_file")
            local service_name=$(basename "$service_dir")
            DISCOVERED_SERVICES+=("api:$service_name:$compose_file")
            info "Found API: $service_name"
        done < <(find "$SCRIPT_DIR/apis" -name "docker-compose.yml" -o -name "docker-compose.yaml" -print0 2>/dev/null)
    fi
    
    # Scan sites directory
    if [ -d "$SCRIPT_DIR/sites" ]; then
        while IFS= read -r -d '' compose_file; do
            local service_dir=$(dirname "$compose_file")
            local service_name=$(basename "$service_dir")
            DISCOVERED_SERVICES+=("site:$service_name:$compose_file")
            info "Found Site: $service_name"
        done < <(find "$SCRIPT_DIR/sites" -name "docker-compose.yml" -o -name "docker-compose.yaml" -print0 2>/dev/null)
    fi
    
    if [ ${#DISCOVERED_SERVICES[@]} -gt 0 ]; then
        echo -e "\n${WHITE}Discovered services:${NC}"
        for service in "${DISCOVERED_SERVICES[@]}"; do
            IFS=':' read -r type name path <<< "$service"
            echo -e "  ${CYAN}$type${NC}: $name"
        done
        
        echo
        read -p "Deploy discovered services? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            DISCOVERED_SERVICES=()
        fi
    else
        info "No additional services found"
    fi
}

# Setup environment variables
setup_environment() {
    header "Environment Configuration"
    
    local env_file="$SCRIPT_DIR/.env"
    
    if [ ! -f "$env_file" ]; then
        info "Creating environment configuration..."
        
        # Get server IP
        local server_ip=$(hostname -I | awk '{print $1}')
        
        cat > "$env_file" << EOF
# Dinky Server Environment Variables
# Generated on $(date)

# Server Configuration
SERVER_IP=$server_ip
TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
DOMAIN_NAME=dinky.local

# Pi-hole Configuration
PIHOLE_PASSWORD=$(openssl rand -base64 32)

# Mail Server Configuration
MAIL_DOMAIN=dinky.local
MAIL_HOSTNAME=mail.dinky.local
DEFAULT_FROM=noreply@dinky.local
DEFAULT_TO=admin@dinky.local
ALLOWED_HOSTS=dinky.local

# SMTP Relay Configuration (Update with your values)
SMTP_RELAY_HOST=smtp.gmail.com
SMTP_RELAY_PORT=587
SMTP_RELAY_USERNAME=your-email@gmail.com
SMTP_RELAY_PASSWORD=your-app-password

# TLS Configuration
USE_TLS=yes
TLS_VERIFY=yes

# Grafana Configuration
GRAFANA_PASSWORD=$(openssl rand -base64 32)

# Cloudflare Tunnel (Update with your tunnel ID)
TUNNEL_ID=your-tunnel-id-here
EOF
        
        success "Environment file created at $env_file"
        warning "Please update the SMTP and Cloudflare settings in $env_file before starting services"
    else
        success "Environment file already exists"
    fi
}

# Setup security
setup_security() {
    header "Security Configuration"
    
    echo -e "${WHITE}Security Level Selection:${NC}\n"
    echo -e "${CYAN}1. Basic${NC} - Firewall + Fail2ban + Docker security"
    echo -e "${CYAN}2. Standard${NC} - Basic + SSH hardening + Auto-updates"
    echo -e "${CYAN}3. Comprehensive${NC} - Standard + Log monitoring + Security audit"
    echo
    read -p "Select security level (1-3) [2]: " -n 1 -r
    echo
    
    local security_level=${REPLY:-2}
    
    info "Running security setup (Level $security_level)..."
    
    # Basic security (Level 1+)
    if [ -f "$SCRIPT_DIR/infrastructure/firewall/setup-firewall.sh" ]; then
        info "Setting up firewall..."
        bash "$SCRIPT_DIR/infrastructure/firewall/setup-firewall.sh"
    fi
    
    if [ -f "$SCRIPT_DIR/infrastructure/firewall/setup-fail2ban.sh" ]; then
        info "Setting up fail2ban..."
        bash "$SCRIPT_DIR/infrastructure/firewall/setup-fail2ban.sh" || warning "Fail2ban setup had issues, continuing..."
    fi
    
    if [ -f "$SCRIPT_DIR/infrastructure/firewall/setup-docker-security.sh" ]; then
        info "Setting up Docker security..."
        bash "$SCRIPT_DIR/infrastructure/firewall/setup-docker-security.sh" || warning "Docker security setup had issues, continuing..."
    fi
    
    # Standard security (Level 2+)
    if [ "$security_level" -ge 2 ]; then
        if [ -f "$SCRIPT_DIR/infrastructure/firewall/setup-ssh-keys.sh" ]; then
            info "Setting up SSH hardening..."
            bash "$SCRIPT_DIR/infrastructure/firewall/setup-ssh-keys.sh" || warning "SSH setup had issues, continuing..."
        fi
        
        if [ -f "$SCRIPT_DIR/infrastructure/firewall/setup-auto-updates.sh" ]; then
            info "Setting up automatic security updates..."
            bash "$SCRIPT_DIR/infrastructure/firewall/setup-auto-updates.sh" || warning "Auto-updates setup had issues, continuing..."
        fi
        
        if [ -f "$SCRIPT_DIR/infrastructure/firewall/setup-cron.sh" ]; then
            info "Setting up security cron jobs..."
            bash "$SCRIPT_DIR/infrastructure/firewall/setup-cron.sh" || warning "Cron setup had issues, continuing..."
        fi
    fi
    
    # Comprehensive security (Level 3)
    if [ "$security_level" -ge 3 ]; then
        if [ -f "$SCRIPT_DIR/infrastructure/firewall/setup-logwatch.sh" ]; then
            info "Setting up log monitoring..."
            bash "$SCRIPT_DIR/infrastructure/firewall/setup-logwatch.sh" || warning "Logwatch setup had issues, continuing..."
        fi
        
        if [ -f "$SCRIPT_DIR/infrastructure/firewall/security-check.sh" ]; then
            info "Running security audit..."
            bash "$SCRIPT_DIR/infrastructure/firewall/security-check.sh" || warning "Security check had issues, continuing..."
        fi
        
        # Run master security setup as final comprehensive check
        if [ -f "$SCRIPT_DIR/infrastructure/firewall/master-security-setup.sh" ]; then
            info "Running comprehensive security validation..."
            bash "$SCRIPT_DIR/infrastructure/firewall/master-security-setup.sh" || warning "Master security setup had issues, continuing..."
        fi
    fi
    
    success "Security configuration completed (Level $security_level)"
}

# Deploy core infrastructure
deploy_core() {
    header "Deploying Core Infrastructure"
    
    cd "$SCRIPT_DIR"
    
    # Detect Docker Compose command if not already detected
    if [ -z "$DOCKER_COMPOSE" ]; then
        detect_docker_compose
    fi
    
    # Create Docker network
    info "Creating Docker networks..."
    docker network create traefik_network 2>/dev/null || info "traefik_network already exists"
    
    # Prepare docker-compose.yml based on selected components
    local compose_services=""
    
    if $INSTALL_TRAEFIK; then
        info "Preparing Traefik configuration..."
        compose_services="traefik"
    fi
    
    if $INSTALL_CLOUDFLARED; then
        info "Preparing Cloudflared configuration..."
        compose_services="$compose_services cloudflared"
    fi
    
    if $INSTALL_PIHOLE; then
        info "Preparing Pi-hole configuration..."
        compose_services="$compose_services pihole"
    fi
    
    if $INSTALL_MAIL; then
        info "Preparing Mail server configuration..."
        compose_services="$compose_services mail-server mail-api"
    fi
    
    if $INSTALL_MONITORING; then
        info "Setting up monitoring stack..."
        if [ -f "$SCRIPT_DIR/monitoring/setup-monitoring.sh" ]; then
            bash "$SCRIPT_DIR/monitoring/setup-monitoring.sh"
        fi
        compose_services="$compose_services prometheus loki promtail tempo pyroscope grafana otel-collector"
    fi
    
    # Deploy selected services
    if [ -n "$compose_services" ]; then
        info "Starting selected services: $compose_services"
        $DOCKER_COMPOSE up -d $compose_services
        
        # Wait for services to be ready
        sleep 10
        
        success "Core infrastructure deployed"
    fi
}

# Deploy discovered services
deploy_discovered_services() {
    if [ ${#DISCOVERED_SERVICES[@]} -eq 0 ]; then
        return
    fi
    
    header "Deploying Additional Services"
    
    # Detect Docker Compose command if not already detected
    if [ -z "$DOCKER_COMPOSE" ]; then
        detect_docker_compose
    fi
    
    for service in "${DISCOVERED_SERVICES[@]}"; do
        IFS=':' read -r type name path <<< "$service"
        
        info "Deploying $type: $name"
        
        local service_dir=$(dirname "$path")
        cd "$service_dir"
        
        # Check if .env is needed
        if grep -q '\${' "$path" 2>/dev/null; then
            if [ ! -f "$service_dir/.env" ] && [ -f "$SCRIPT_DIR/.env" ]; then
                info "Copying environment file to $service_dir"
                cp "$SCRIPT_DIR/.env" "$service_dir/.env"
            fi
        fi
        
        # Deploy the service
        $DOCKER_COMPOSE up -d
        
        success "$type $name deployed"
    done
    
    cd "$SCRIPT_DIR"
}

# Save deployment state
save_deployment_state() {
    info "Saving deployment state..."
    
    cat > "$DEPLOYED_COMPONENTS_FILE" << EOF
# Dinky Server Deployed Components
# Generated on $(date)

TRAEFIK=$INSTALL_TRAEFIK
CLOUDFLARED=$INSTALL_CLOUDFLARED
PIHOLE=$INSTALL_PIHOLE
MONITORING=$INSTALL_MONITORING
MAIL=$INSTALL_MAIL

# Discovered Services
EOF
    
    for service in "${DISCOVERED_SERVICES[@]}"; do
        echo "$service" >> "$DEPLOYED_COMPONENTS_FILE"
    done
    
    success "Deployment state saved"
}

# Display final status
show_status() {
    header "Deployment Complete!"
    
    echo -e "${GREEN}🎉 Dinky Server has been successfully deployed!${NC}\n"
    
    # Show service URLs
    local server_ip=$(grep "SERVER_IP=" "$SCRIPT_DIR/.env" | cut -d'=' -f2)
    
    echo -e "${WHITE}Service Access URLs:${NC}"
    
    if $INSTALL_TRAEFIK; then
        echo -e "  ${CYAN}Traefik Dashboard:${NC} http://$server_ip:8080"
    fi
    
    if $INSTALL_PIHOLE; then
        local pihole_password=$(grep "PIHOLE_PASSWORD=" "$SCRIPT_DIR/.env" | cut -d'=' -f2)
        echo -e "  ${CYAN}Pi-hole Admin:${NC} http://$server_ip:8081"
        echo -e "    ${YELLOW}Password:${NC} $pihole_password"
    fi
    
    if $INSTALL_MONITORING; then
        local grafana_password=$(grep "GRAFANA_PASSWORD=" "$SCRIPT_DIR/.env" | cut -d'=' -f2)
        echo -e "  ${CYAN}Grafana:${NC} http://$server_ip:3000 (admin/$grafana_password)"
        echo -e "  ${CYAN}Prometheus:${NC} http://$server_ip:9090"
    fi
    
    if $INSTALL_MAIL; then
        echo -e "  ${CYAN}Mail API:${NC} http://$server_ip:3000"
    fi
    
    echo -e "\n${WHITE}Management Commands:${NC}"
    echo -e "  ${CYAN}View logs:${NC} docker compose logs -f"
    echo -e "  ${CYAN}Stop services:${NC} docker compose down"
    echo -e "  ${CYAN}Update services:${NC} docker compose pull && docker compose up -d"
    echo -e "  ${CYAN}Deployment logs:${NC} tail -f $LOG_FILE"
    
    echo -e "\n${WHITE}Next Steps:${NC}"
    if $INSTALL_CLOUDFLARED; then
        echo -e "  ${YELLOW}1.${NC} Update TUNNEL_ID in $SCRIPT_DIR/.env"
        echo -e "  ${YELLOW}2.${NC} Add Cloudflare tunnel credentials to infrastructure/cloudflared/"
    fi
    if $INSTALL_MAIL; then
        echo -e "  ${YELLOW}3.${NC} Configure SMTP relay settings in $SCRIPT_DIR/.env"
    fi
    echo -e "  ${YELLOW}4.${NC} Review security settings and update passwords"
    
    success "Deployment completed successfully!"
}

# List all available services
list_all_services() {
    header "Available Services"
    
    echo -e "${WHITE}Scanning for services...${NC}\n"
    
    # List APIs
    if [ -d "$SCRIPT_DIR/apis" ]; then
        echo -e "${CYAN}APIs:${NC}"
        find "$SCRIPT_DIR/apis" -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null | while read compose_file; do
            local service_dir=$(dirname "$compose_file")
            local service_name=$(basename "$service_dir")
            
            # Check if service is running
            if docker ps --format "table {{.Names}}" | grep -q "$service_name" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $service_name (running)"
            else
                echo -e "  ${RED}✗${NC} $service_name (stopped)"
            fi
        done
        echo
    fi
    
    # List Sites
    if [ -d "$SCRIPT_DIR/sites" ]; then
        echo -e "${CYAN}Sites:${NC}"
        find "$SCRIPT_DIR/sites" -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null | while read compose_file; do
            local service_dir=$(dirname "$compose_file")
            local service_name=$(basename "$service_dir")
            
            # Check if service is running
            if docker ps --format "table {{.Names}}" | grep -q "$service_name" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $service_name (running)"
            else
                echo -e "  ${RED}✗${NC} $service_name (stopped)"
            fi
        done
        echo
    fi
    
    success "Service listing completed"
}

# Add individual service
add_individual_service() {
    local service_type="$1"
    local service_name="$2"
    
    header "Adding Individual Service"
    
    # Detect Docker Compose command
    detect_docker_compose
    
    # Validate inputs
    if [ -z "$service_name" ]; then
        error "Service name is required"
        echo -e "${YELLOW}Usage: sudo ./deploy.sh --add-$service_type <service-name>${NC}"
        exit 1
    fi
    
    # Determine directory based on type
    local service_dir=""
    if [ "$service_type" = "site" ]; then
        service_dir="$SCRIPT_DIR/sites/$service_name"
    elif [ "$service_type" = "api" ]; then
        service_dir="$SCRIPT_DIR/apis/$service_name"
    else
        error "Invalid service type: $service_type"
        exit 1
    fi
    
    # Check if service directory exists
    if [ ! -d "$service_dir" ]; then
        error "Service directory does not exist: $service_dir"
        echo -e "${YELLOW}Please create the directory and add a docker-compose.yml file first${NC}"
        exit 1
    fi
    
    # Check if docker-compose file exists
    local compose_file=""
    if [ -f "$service_dir/docker-compose.yml" ]; then
        compose_file="$service_dir/docker-compose.yml"
    elif [ -f "$service_dir/docker-compose.yaml" ]; then
        compose_file="$service_dir/docker-compose.yaml"
    else
        error "No docker-compose file found in $service_dir"
        echo -e "${YELLOW}Please add a docker-compose.yml file to the service directory${NC}"
        exit 1
    fi
    
    info "Deploying $service_type: $service_name"
    
    # Change to service directory
    cd "$service_dir"
    
    # Check if .env is needed and copy main .env if necessary
    if grep -q '\${' "$compose_file" 2>/dev/null; then
        if [ ! -f "$service_dir/.env" ] && [ -f "$SCRIPT_DIR/.env" ]; then
            info "Copying environment file to $service_dir"
            cp "$SCRIPT_DIR/.env" "$service_dir/.env"
        fi
    fi
    
    # Deploy the service
    if $DOCKER_COMPOSE up -d; then
        success "$service_type '$service_name' deployed successfully!"
        
        # Update deployed components file
        if [ -f "$DEPLOYED_COMPONENTS_FILE" ]; then
            echo "$service_type:$service_name:$compose_file" >> "$DEPLOYED_COMPONENTS_FILE"
        fi
        
        # Show service info
        echo -e "\n${WHITE}Service Information:${NC}"
        echo -e "  ${CYAN}Type:${NC} $service_type"
        echo -e "  ${CYAN}Name:${NC} $service_name"
        echo -e "  ${CYAN}Directory:${NC} $service_dir"
        
        # Try to detect port from docker-compose file
        local port=$(grep -E "^\s*-\s*\"[0-9]+:" "$compose_file" | head -1 | sed -E 's/.*"([0-9]+):.*/\1/')
        if [ -n "$port" ]; then
            local server_ip=$(grep "SERVER_IP=" "$SCRIPT_DIR/.env" 2>/dev/null | cut -d'=' -f2 || hostname -I | awk '{print $1}')
            echo -e "  ${CYAN}URL:${NC} http://$server_ip:$port"
        fi
    else
        error "Failed to deploy $service_type '$service_name'"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
}

# Discover and deploy new services only
discover_new_services() {
    header "Discovering New Services"
    
    info "Scanning for new services..."
    
    # Clear discovered services array
    DISCOVERED_SERVICES=()
    
    # Scan apis directory
    if [ -d "$SCRIPT_DIR/apis" ]; then
        while IFS= read -r compose_file; do
            if [ -n "$compose_file" ]; then
                local service_dir=$(dirname "$compose_file")
                local service_name=$(basename "$service_dir")
                
                # Check if service is already running
                if ! docker ps --format "table {{.Names}}" | grep -q "$service_name" 2>/dev/null; then
                    DISCOVERED_SERVICES+=("api:$service_name:$compose_file")
                    info "Found new API: $service_name"
                fi
            fi
        done < <(find "$SCRIPT_DIR/apis" -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null)
    fi
    
    # Scan sites directory
    if [ -d "$SCRIPT_DIR/sites" ]; then
        while IFS= read -r compose_file; do
            if [ -n "$compose_file" ]; then
                local service_dir=$(dirname "$compose_file")
                local service_name=$(basename "$service_dir")
                
                # Check if service is already running
                if ! docker ps --format "table {{.Names}}" | grep -q "$service_name" 2>/dev/null; then
                    DISCOVERED_SERVICES+=("site:$service_name:$compose_file")
                    info "Found new Site: $service_name"
                fi
            fi
        done < <(find "$SCRIPT_DIR/sites" -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null)
    fi
    
    if [ ${#DISCOVERED_SERVICES[@]} -gt 0 ]; then
        echo -e "\n${WHITE}New services found:${NC}"
        for service in "${DISCOVERED_SERVICES[@]}"; do
            IFS=':' read -r type name path <<< "$service"
            echo -e "  ${CYAN}$type${NC}: $name"
        done
        
        echo
        read -p "Deploy these new services? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            deploy_discovered_services
        else
            info "Skipping deployment of new services"
        fi
    else
        info "No new services found"
    fi
}

# Main execution
main() {
    # Parse command line arguments first
    parse_arguments "$@"
    
    # Handle help flag
    if [ "$HELP_FLAG" = true ]; then
        show_help
        exit 0
    fi
    
    # Handle list services flag
    if [ "$LIST_SERVICES" = true ]; then
        list_all_services
        exit 0
    fi
    
    # Handle individual service addition
    if [ -n "$ADD_SERVICE" ]; then
        # These operations don't require full root setup
        setup_directories
        add_individual_service "$ADD_TYPE" "$ADD_SERVICE"
        exit 0
    fi
    
    # Handle discover only flag
    if [ "$DISCOVER_ONLY" = true ]; then
        # These operations don't require full root setup
        setup_directories
        discover_new_services
        exit 0
    fi
    
    # Full deployment - show ASCII art header
    echo -e "${PURPLE}"
    cat << "EOF"
    ____  _       __            ____                            
   / __ \(_)___  / /____  __   / __ \___  ____  ____ ___  _____ 
  / / / / / __ \/ //_/ / / /  / / / / _ \/ __ \/ __ `__ \/ ___/ 
 / /_/ / / / / / ,< / /_/ /  / /_/ /  __/ /_/ / / / / / / /     
/_____/_/_/ /_/_/|_|\__, /  /_____/\___/ .___/_/ /_/ /_/_/      
                  /____/              /_/                      
EOF
    echo -e "${NC}"
    echo -e "${WHITE}Comprehensive Deployment Solution for Self-Hosted Services${NC}\n"
    
    # Full deployment execution flow
    check_root
    setup_directories
    backup_existing_config
    check_requirements
    install_dependencies
    select_components
    discover_services
    setup_environment
    setup_security
    deploy_core
    deploy_discovered_services
    save_deployment_state
    show_status
    
    # Disable error trap for successful completion
    trap - ERR
}

# Run main function
main "$@" 