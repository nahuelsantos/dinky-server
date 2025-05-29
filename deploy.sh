#!/bin/bash
# Dinky Server Service Deployment Script
# Handles service selection and deployment only

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
        error "Please run setup.sh first to install dependencies"
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
    echo -e "${CYAN}Dinky Server Service Deployment Script${NC}"
    echo -e "${CYAN}=====================================${NC}\n"
    echo -e "${WHITE}Usage:${NC}"
    echo -e "  ${GREEN}sudo ./deploy.sh${NC}                    # Full service deployment"
    echo -e "  ${GREEN}sudo ./deploy.sh --discover${NC}         # Discover and deploy new services"
    echo -e "  ${GREEN}sudo ./deploy.sh --add-site <name>${NC}  # Deploy specific site"
    echo -e "  ${GREEN}sudo ./deploy.sh --add-api <name>${NC}   # Deploy specific API"
    echo -e "  ${GREEN}sudo ./deploy.sh --list${NC}             # List all available services"
    echo -e "  ${GREEN}sudo ./deploy.sh --help${NC}             # Show this help"
    echo
    echo -e "${WHITE}Prerequisites:${NC}"
    echo -e "  ${YELLOW}Run setup.sh first to prepare your system${NC}"
    echo
    echo -e "${WHITE}Examples:${NC}"
    echo -e "  ${YELLOW}# Full deployment${NC}"
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

# Check if system is prepared
check_prerequisites() {
    header "Checking Prerequisites"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root or with sudo"
        echo -e "${YELLOW}Please run: sudo $0${NC}"
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        echo -e "${YELLOW}Please run setup.sh first to install dependencies${NC}"
        exit 1
    fi
    
    # Check if .env file exists
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        error ".env file not found"
        echo -e "${YELLOW}Please run setup.sh first to create environment configuration${NC}"
        exit 1
    fi
    
    # Check if traefik_network exists
    if ! docker network ls | grep -q "traefik_network"; then
        error "traefik_network not found"
        echo -e "${YELLOW}Please run setup.sh first to create Docker networks${NC}"
        exit 1
    fi
    
    success "All prerequisites met"
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

# Deploy core infrastructure
deploy_core() {
    header "Deploying Core Infrastructure"
    
    cd "$SCRIPT_DIR"
    
    # Detect Docker Compose command if not already detected
    if [ -z "$DOCKER_COMPOSE" ]; then
        detect_docker_compose
    fi
    
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
        compose_services="$compose_services prometheus loki promtail tempo pyroscope grafana otel-collector cadvisor node-exporter"
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
    
    mkdir -p "/opt/dinky-server"
    
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
    
    echo -e "${GREEN}🎉 Dinky Server services have been successfully deployed!${NC}\n"
    
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
        echo -e "  ${CYAN}Pyroscope:${NC} http://$server_ip:4040"
        echo -e "  ${CYAN}Loki:${NC} http://$server_ip:3100"
    fi
    
    if $INSTALL_MAIL; then
        echo -e "  ${CYAN}Mail API:${NC} http://$server_ip:3005"
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
    
    # Show header
    echo -e "${PURPLE}"
    cat << "EOF"
 ____  _       _            ____             _             
|  _ \(_)_ __ | | ___   _  |  _ \  ___ _ __ | | ___  _   _ 
| | | | | '_ \| |/ / | | | | | | |/ _ \ '_ \| |/ _ \| | | |
| |_| | | | | |   <| |_| | | |_| |  __/ |_) | | (_) | |_| |
|____/|_|_| |_|_|\_\__, | |____/ \___| .__/|_|\___/ \__, |
                   |___/             |_|            |___/ 
EOF
    echo -e "${NC}"
    echo -e "${WHITE}Service Deployment & Management${NC}\n"
    
    # Handle specific actions
    if [ "$LIST_SERVICES" = true ]; then
        list_all_services
        exit 0
    fi
    
    if [ "$DISCOVER_ONLY" = true ]; then
        check_prerequisites
        discover_new_services
        exit 0
    fi
    
    if [ -n "$ADD_SERVICE" ] && [ -n "$ADD_TYPE" ]; then
        check_prerequisites
        add_individual_service "$ADD_TYPE" "$ADD_SERVICE"
        exit 0
    fi
    
    # Full deployment execution flow
    check_prerequisites
    select_components
    discover_services
    deploy_core
    deploy_discovered_services
    save_deployment_state
    show_status
}

# Run main function
main "$@" 