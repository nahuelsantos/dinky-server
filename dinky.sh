#!/bin/bash
# Dinky Server - Unified Deployment Script
# Provides menu-driven interface for system setup and service deployment

# Terminal compatibility fix for unknown terminal types (e.g., xterm-ghostty)
if ! tput colors >/dev/null 2>&1; then
    export TERM=xterm-256color
    # If that still fails, fallback to basic xterm
    if ! tput colors >/dev/null 2>&1; then
        export TERM=xterm
    fi
fi

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
LOG_FILE="/var/log/dinky.log"
BACKUP_DIR="/opt/dinky-backups/$(date +%Y%m%d_%H%M%S)"

# Global variables
DOCKER_COMPOSE=""
DISCOVERED_SERVICES=()

# Utility functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" >/dev/null 2>&1 || echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo -e "$1"
}

success() { log "${GREEN}✓ $1${NC}"; }
error() { log "${RED}✗ ERROR: $1${NC}"; }
warning() { log "${YELLOW}⚠ WARNING: $1${NC}"; }
info() { log "${BLUE}ℹ INFO: $1${NC}"; }

header() {
    echo -e "\n${PURPLE}============================================================${NC}"
    echo -e "${PURPLE}   $1${NC}"
    echo -e "${PURPLE}============================================================${NC}\n"
}

step_banner() {
    echo -e "\n${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│  STEP: $1${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}\n"
}

critical_warning() {
    echo -e "\n${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  🚨 CRITICAL WARNING 🚨${NC}"
    echo -e "${RED}║  $1${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

ssh_key_prompt() {
    critical_warning "SSH CONFIGURATION - LOCKOUT RISK!"
    
    echo -e "${RED}${WHITE}IMPORTANT: We are about to modify SSH configuration!${NC}"
    echo -e "${RED}If you don't have SSH keys properly configured, you could be${NC}"
    echo -e "${RED}PERMANENTLY LOCKED OUT of your server!${NC}\n"
    
    echo -e "${WHITE}Before proceeding, you MUST ensure:${NC}"
    echo -e "  ${CYAN}1.${NC} You have generated SSH keys on your client machine"
    echo -e "  ${CYAN}2.${NC} Your public key is in ~/.ssh/authorized_keys on this server"
    echo -e "  ${CYAN}3.${NC} You can successfully SSH with key authentication"
    echo -e "  ${CYAN}4.${NC} You have tested the connection from another terminal"
    
    echo -e "\n${WHITE}To set up SSH keys:${NC}"
    echo -e "  ${YELLOW}On your local machine:${NC} ssh-keygen -t ed25519"
    echo -e "  ${YELLOW}Copy to server:${NC} ssh-copy-id user@server"
    echo -e "  ${YELLOW}Test connection:${NC} ssh user@server"
    
    echo -e "\n${RED}${WHITE}If you proceed without proper SSH key setup, you may lose access!${NC}"
    echo -e "${RED}${WHITE}Only continue if you're absolutely certain SSH keys are working!${NC}\n"
    
    local attempts=0
    while [ $attempts -lt 3 ]; do
        read -p "${WHITE}Have you verified SSH key authentication is working? (yes/no): ${NC}" -n 1 -r ssh_response
        case $ssh_response in
            yes|YES|y|Y)
                success "Proceeding with SSH hardening..."
                return 0
                ;;
            no|NO|n|N)
                warning "SSH hardening skipped for safety"
                echo -e "${YELLOW}Please set up SSH keys first, then run the script again${NC}"
                return 1
                ;;
            *)
                error "Please answer 'yes' or 'no'"
                attempts=$((attempts + 1))
                if [ $attempts -eq 3 ]; then
                    warning "Too many invalid responses. Skipping SSH hardening for safety."
                    return 1
                fi
                ;;
        esac
    done
}

# Show main menu
show_menu() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
 ____  _       _            ____                           
|  _ \(_)_ __ | | ___   _  / ___|  ___ _ ____   _____ _ __ 
| | | | | '_ \| |/ / | | | \___ \ / _ \ '__\ \ / / _ \ '__|
| |_| | | | | |   <| |_| |  ___) |  __/ |   \ V /  __/ |   
|____/|_|_| |_|_|\_\\__, | |____/ \___|_|    \_/ \___|_|   
                    |___/                                  
EOF
    echo -e "${NC}"
    echo -e "${WHITE}Comprehensive Self-Hosted Server Solution${NC}"
    echo -e "${WHITE}=========================================${NC}\n"
    
    echo -e "${CYAN}Main Menu:${NC}"
    echo -e "  ${GREEN}1.${NC} 🚀 Full Setup (System + Services) ${RED}🔐${NC}"
    echo -e "  ${GREEN}2.${NC} 🔧 System Setup Only ${RED}🔐${NC}"
    echo -e "  ${GREEN}3.${NC} ⚡ Deploy Services Only ${RED}🔐${NC}"
    echo -e "  ${GREEN}4.${NC} 📦 Add Individual Service ${RED}🔐${NC}"
    echo -e "  ${GREEN}5.${NC} 🎯 Deploy All Services (Dinky + Examples) ${RED}🔐${NC}"
    echo -e "  ${GREEN}6.${NC} 🔍 Discover New Services"
    echo -e "  ${GREEN}7.${NC} 📋 List All Services"
    echo -e "  ${GREEN}8.${NC} 🛠️  System Status & Health"
    echo -e "  ${GREEN}9.${NC} ❓ Help & Documentation"
    echo -e "  ${GREEN}0.${NC} 🚪 Exit"
    echo
    echo -e "${YELLOW}${RED}🔐${NC} ${YELLOW}= Requires sudo privileges${NC}"
    echo
}

# Check if running as root for system operations
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root or with sudo"
        echo -e "${YELLOW}Please run: sudo $0${NC}"
        exit 1
    fi
}

# Auto-detect Docker Compose command
detect_docker_compose() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE="docker-compose"
    else
        warning "Docker Compose not found. Will be installed during system setup."
        DOCKER_COMPOSE=""
    fi
}

# System setup functions (from setup.sh)
source_setup_functions() {
    # Check system requirements
    check_system_requirements() {
        step_banner "1/6 - SYSTEM REQUIREMENTS CHECK"
        
        # Check OS
        if ! grep -q "Raspberry Pi\|Ubuntu\|Debian" /proc/version 2>/dev/null; then
            warning "This script is optimized for Raspberry Pi OS, Ubuntu, or Debian"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return 1
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
        step_banner "2/6 - DEPENDENCY INSTALLATION"
        
        info "Updating package lists..."
        apt update
        
        info "Installing essential packages..."
        apt install -y curl wget git unzip software-properties-common \
                      apt-transport-https ca-certificates gnupg lsb-release \
                      jq htop nano ufw fail2ban
        
        # Install Docker if not present
        if ! command -v docker &> /dev/null; then
            info "Installing Docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            rm get-docker.sh
            usermod -aG docker $SUDO_USER 2>/dev/null || true
            success "Docker installed"
        else
            success "Docker already installed"
        fi
        
        # Install Docker Compose if not present
        if ! command -v docker compose &> /dev/null; then
            info "Installing Docker Compose..."
            if ! docker compose version &> /dev/null; then
                local compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
                curl -L "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                chmod +x /usr/local/bin/docker-compose
            fi
            success "Docker Compose installed"
        else
            success "Docker Compose already installed"
        fi
        
        systemctl enable docker
        systemctl start docker
        success "All dependencies installed"
    }

    # Setup environment
    setup_environment() {
        step_banner "3/6 - ENVIRONMENT CONFIGURATION"
        
        local env_file="$SCRIPT_DIR/.env"
        
        if [ ! -f "$env_file" ]; then
            if [ -f "$SCRIPT_DIR/.env.example" ]; then
                info "Creating environment configuration from .env.example..."
                cp "$SCRIPT_DIR/.env.example" "$env_file"
                # Add SERVER_IP for dinky server
                echo "" >> "$env_file"
                echo "# Server Configuration" >> "$env_file"
                echo "SERVER_IP=dinky" >> "$env_file"
                success "Environment file created from .env.example"
                warning "Please update the configuration values in $env_file as needed"
            else
                error ".env.example file not found. Cannot create environment configuration."
                return 1
            fi
        else
            success "Environment file already exists"
        fi
    }

    # Setup security
    setup_security() {
        local security_level=${1:-2}
        
        step_banner "4/6 - SECURITY CONFIGURATION (LEVEL $security_level)"
        
        info "Running security setup..."
        
        if [ "$security_level" -ge 3 ]; then
            if [ -f "$SCRIPT_DIR/infrastructure/firewall/master-security-setup.sh" ]; then
                info "Running comprehensive security setup..."
                bash "$SCRIPT_DIR/infrastructure/firewall/master-security-setup.sh" || warning "Master security setup had issues, continuing..."
            fi
        else
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
            
            # Standard security (Level 2+) - SSH hardening with safety check
            if [ "$security_level" -ge 2 ]; then
                if [ -f "$SCRIPT_DIR/infrastructure/firewall/setup-ssh-keys.sh" ]; then
                    info "Preparing SSH hardening setup..."
                    if ssh_key_prompt; then
                        bash "$SCRIPT_DIR/infrastructure/firewall/setup-ssh-keys.sh" || warning "SSH setup had issues, continuing..."
                    else
                        warning "SSH hardening skipped - server remains accessible with password"
                    fi
                fi
                
                if [ -f "$SCRIPT_DIR/infrastructure/firewall/setup-auto-updates.sh" ]; then
                    info "Setting up automatic security updates..."
                    bash "$SCRIPT_DIR/infrastructure/firewall/setup-auto-updates.sh" || warning "Auto-updates setup had issues, continuing..."
                fi
            fi
        fi
        
        success "Security configuration completed (Level $security_level)"
    }

    # Create Docker networks
    setup_docker_networks() {
        step_banner "5/6 - DOCKER NETWORK SETUP"
        
        info "Creating Docker networks..."
        docker network create traefik_network 2>/dev/null || info "traefik_network already exists"
        
        success "Docker networks ready"
    }
}

# Service deployment functions (from deploy.sh)
source_deploy_functions() {
    # Component selection
    select_components() {
        step_banner "6/6 - SERVICE COMPONENT SELECTION"
        
        echo -e "${WHITE}Select components to install:${NC}\n"
        
        # Portainer
        echo -e "${CYAN}1. Portainer (Container Management UI)${NC} - ${GREEN}Recommended${NC}"
        read -p "   Install Portainer? (Y/n): " -n 1 -r; echo
        INSTALL_PORTAINER=$([[ ! $REPLY =~ ^[Nn]$ ]] && echo true || echo false)
        
        # Traefik
        echo -e "\n${CYAN}2. Traefik (Reverse Proxy)${NC} - ${GREEN}Recommended${NC}"
        read -p "   Install Traefik? (Y/n): " -n 1 -r; echo
        INSTALL_TRAEFIK=$([[ ! $REPLY =~ ^[Nn]$ ]] && echo true || echo false)
        
        # Cloudflared
        echo -e "\n${CYAN}3. Cloudflared (Cloudflare Tunnel)${NC} - ${YELLOW}Optional${NC}"
        read -p "   Install Cloudflared? (y/N): " -n 1 -r; echo
        INSTALL_CLOUDFLARED=$([[ $REPLY =~ ^[Yy]$ ]] && echo true || echo false)
        
        # Pi-hole
        echo -e "\n${CYAN}4. Pi-hole (DNS & Ad Blocking)${NC} - ${GREEN}Recommended${NC}"
        read -p "   Install Pi-hole? (Y/n): " -n 1 -r; echo
        INSTALL_PIHOLE=$([[ ! $REPLY =~ ^[Nn]$ ]] && echo true || echo false)
        
        # Monitoring
        echo -e "\n${CYAN}5. Monitoring Stack (LGTMA)${NC} - ${GREEN}Recommended${NC}"
        read -p "   Install Monitoring? (Y/n): " -n 1 -r; echo
        INSTALL_MONITORING=$([[ ! $REPLY =~ ^[Nn]$ ]] && echo true || echo false)
        
        # Mail server - Now mandatory
        echo -e "\n${CYAN}6. Mail Server (SMTP Relay)${NC} - ${GREEN}Recommended${NC}"
        read -p "   Install Mail Server? (Y/n): " -n 1 -r; echo
        INSTALL_MAIL=$([[ ! $REPLY =~ ^[Nn]$ ]] && echo true || echo false)
        
        # Summary
        echo -e "\n${WHITE}Selected components:${NC}"
        $INSTALL_PORTAINER && echo -e "  ${GREEN}✓${NC} Portainer"
        $INSTALL_TRAEFIK && echo -e "  ${GREEN}✓${NC} Traefik"
        $INSTALL_CLOUDFLARED && echo -e "  ${GREEN}✓${NC} Cloudflared"
        $INSTALL_PIHOLE && echo -e "  ${GREEN}✓${NC} Pi-hole"
        $INSTALL_MONITORING && echo -e "  ${GREEN}✓${NC} Monitoring Stack"
        $INSTALL_MAIL && echo -e "  ${GREEN}✓${NC} Mail Server"
        
        echo
        read -p "Proceed with installation? (Y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            info "Installation cancelled by user"
            return 1
        fi
    }

    # Deploy core services
    deploy_core_services() {
        header "DEPLOYING CORE INFRASTRUCTURE"
        
        cd "$SCRIPT_DIR"
        detect_docker_compose
        
        local compose_services=""
        
        $INSTALL_PORTAINER && compose_services="portainer"
        $INSTALL_TRAEFIK && compose_services="$compose_services traefik"
        $INSTALL_CLOUDFLARED && compose_services="$compose_services cloudflared"
        $INSTALL_PIHOLE && compose_services="$compose_services pihole"
        $INSTALL_MAIL && compose_services="$compose_services mail-server"
        
        if $INSTALL_MONITORING; then
            info "Setting up monitoring stack..."
            [ -f "$SCRIPT_DIR/monitoring/setup-monitoring.sh" ] && bash "$SCRIPT_DIR/monitoring/setup-monitoring.sh"
            compose_services="$compose_services prometheus alertmanager loki promtail tempo pyroscope grafana otel-collector cadvisor node-exporter"
        fi
        
        if [ -n "$compose_services" ]; then
            info "Starting selected services: $compose_services"
            $DOCKER_COMPOSE up -d $compose_services
            sleep 10
            success "Core infrastructure deployed"
        fi
    }

    # Show deployment status
    show_deployment_status() {
        header "DEPLOYMENT COMPLETE!"
        
        echo -e "${GREEN}🎉 Dinky Server services have been successfully deployed!${NC}\n"
        
        local server_ip=$(grep "SERVER_IP=" "$SCRIPT_DIR/.env" | cut -d'=' -f2 2>/dev/null || hostname -I | awk '{print $1}')
        
        echo -e "${WHITE}Core Infrastructure URLs:${NC}"
        $INSTALL_PORTAINER && echo -e "  ${CYAN}Portainer:${NC} http://$server_ip:9000"
        $INSTALL_TRAEFIK && echo -e "  ${CYAN}Traefik Dashboard:${NC} http://$server_ip:8080"
        
        if $INSTALL_PIHOLE; then
            local pihole_password=$(grep "PIHOLE_PASSWORD=" "$SCRIPT_DIR/.env" | cut -d'=' -f2 2>/dev/null)
            echo -e "  ${CYAN}Pi-hole Admin:${NC} http://$server_ip:8081"
            [ -n "$pihole_password" ] && echo -e "    ${YELLOW}Password:${NC} $pihole_password"
        fi
        
        if $INSTALL_MONITORING; then
            local grafana_password=$(grep "GRAFANA_PASSWORD=" "$SCRIPT_DIR/.env" | cut -d'=' -f2 2>/dev/null)
            echo -e "  ${CYAN}Grafana:${NC} http://$server_ip:3000 (admin/$grafana_password)"
            echo -e "  ${CYAN}Prometheus:${NC} http://$server_ip:9090"
            echo -e "  ${CYAN}Alertmanager:${NC} http://$server_ip:9093"
        fi
        
        # Show LGTM Stack Testing information
        if $INSTALL_MONITORING; then
            echo -e "\n${WHITE}LGTM Stack Testing:${NC}"
            echo -e "  ${CYAN}Argus (LGTM Validator):${NC} docker run -p 3001:3001 ghcr.io/nahuelsantos/argus:v0.0.1"
            echo -e "    ${YELLOW}• Complete LGTM stack integration testing${NC}"
            echo -e "    ${YELLOW}• Synthetic data generation (metrics, logs, traces)${NC}"
            echo -e "    ${YELLOW}• Performance and scale testing${NC}"
            echo -e "    ${YELLOW}• Dashboard: http://$server_ip:3001${NC}"
            echo -e "\n  ${CYAN}Quick Start:${NC}"
            echo -e "    ${CYAN}docker run -p 3001:3001 \\${NC}"
            echo -e "      ${CYAN}-e PROMETHEUS_URL=http://$server_ip:9090 \\${NC}"
            echo -e "      ${CYAN}-e GRAFANA_URL=http://$server_ip:3000 \\${NC}"
            echo -e "      ${CYAN}-e LOKI_URL=http://$server_ip:3100 \\${NC}"
            echo -e "      ${CYAN}-e TEMPO_URL=http://$server_ip:3200 \\${NC}"
            echo -e "      ${CYAN}ghcr.io/nahuelsantos/argus:v0.0.1${NC}"
        fi
        
        echo -e "\n${WHITE}Next Steps:${NC}"
        $INSTALL_CLOUDFLARED && echo -e "  ${YELLOW}1.${NC} Update TUNNEL_ID in .env"
        $INSTALL_MAIL && echo -e "  ${YELLOW}2.${NC} Configure SMTP relay settings in .env"
        echo -e "  ${YELLOW}3.${NC} Review security settings"
        $INSTALL_MONITORING && echo -e "  ${YELLOW}4.${NC} Test your LGTM stack with Argus"
        
        success "Deployment completed successfully!"
    }
}

# Menu option handlers
handle_full_setup() {
    header "FULL SETUP (SYSTEM + SERVICES)"
    
    echo -e "${WHITE}Security Level Selection:${NC}"
    echo -e "  ${CYAN}1.${NC} Basic - Firewall + Fail2ban + Docker security"
    echo -e "  ${CYAN}2.${NC} Standard - Basic + SSH hardening + Auto-updates ${GREEN}(Recommended)${NC}"
    echo -e "  ${CYAN}3.${NC} Comprehensive - Standard + Log monitoring + Security audit"
    echo
    read -p "Select security level (1-3) [2]: " -n 1 -r; echo
    local security_level=${REPLY:-2}
    
    # System setup
    check_system_requirements || return 1
    mkdir -p "/opt/dinky-server" "/var/log"
    touch "$LOG_FILE" && chmod 644 "$LOG_FILE"
    install_dependencies
    setup_environment
    setup_security "$security_level"
    setup_docker_networks
    
    # Service deployment
    select_components || return 1
    deploy_core_services
    show_deployment_status
    
    echo
    read -p "Press Enter to return to main menu..."
}

handle_system_setup() {
    header "SYSTEM SETUP ONLY"
    
    echo -e "${WHITE}Security Level Selection:${NC}"
    echo -e "  ${CYAN}1.${NC} Basic - Firewall + Fail2ban + Docker security"
    echo -e "  ${CYAN}2.${NC} Standard - Basic + SSH hardening + Auto-updates ${GREEN}(Recommended)${NC}"
    echo -e "  ${CYAN}3.${NC} Comprehensive - Standard + Log monitoring + Security audit"
    echo
    read -p "Select security level (1-3) [2]: " -n 1 -r; echo
    local security_level=${REPLY:-2}
    
    check_system_requirements || return 1
    mkdir -p "/opt/dinky-server" "/var/log"
    touch "$LOG_FILE" && chmod 644 "$LOG_FILE"
    install_dependencies
    setup_environment
    setup_security "$security_level"
    setup_docker_networks
    
    header "SYSTEM SETUP COMPLETE!"
    success "Your server is now prepared and secured!"
    echo -e "\n${WHITE}Next step:${NC} Deploy services with option 3 from the main menu"
    
    echo
    read -p "Press Enter to return to main menu..."
}

handle_deploy_services() {
    header "DEPLOY SERVICES ONLY"
    
    # Check prerequisites
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        error ".env file not found"
        echo -e "${YELLOW}Please run System Setup first (option 2)${NC}"
        read -p "Press Enter to return to main menu..."
        return 1
    fi
    
    if ! docker network ls | grep -q "traefik_network"; then
        error "traefik_network not found"
        echo -e "${YELLOW}Please run System Setup first (option 2)${NC}"
        read -p "Press Enter to return to main menu..."
        return 1
    fi
    
    select_components || return 1
    deploy_core_services
    show_deployment_status
    
    echo
    read -p "Press Enter to return to main menu..."
}

handle_add_service() {
    header "ADD INDIVIDUAL SERVICE"
    
    echo -e "${WHITE}Service Type:${NC}"
    echo -e "  ${CYAN}1.${NC} Add API"
    echo -e "  ${CYAN}2.${NC} Add Site"
    echo -e "  ${CYAN}3.${NC} Back to main menu"
    echo
    read -p "Select option (1-3): " -n 1 -r; echo
    
    case $REPLY in
        1)
            read -p "Enter API name: " api_name
            if [ -n "$api_name" ]; then
                add_individual_service "api" "$api_name"
            fi
            ;;
        2)
            read -p "Enter site name: " site_name
            if [ -n "$site_name" ]; then
                add_individual_service "site" "$site_name"
            fi
            ;;
        3)
            return 0
            ;;
    esac
    
    echo
    read -p "Press Enter to return to main menu..."
}

# Add individual service function (integrated from deploy.sh)
add_individual_service() {
    local service_type="$1"
    local service_name="$2"
    
    step_banner "DEPLOYING $service_type: $service_name"
    
    # Detect Docker Compose command
    detect_docker_compose
    
    # Validate inputs
    if [ -z "$service_name" ]; then
        error "Service name is required"
        return 1
    fi
    
    # Determine directory based on type
    local service_dir=""
    if [ "$service_type" = "site" ]; then
        service_dir="$SCRIPT_DIR/sites/$service_name"
    elif [ "$service_type" = "api" ]; then
        service_dir="$SCRIPT_DIR/apis/$service_name"
    else
        error "Invalid service type: $service_type"
        return 1
    fi
    
    # Check if service directory exists
    if [ ! -d "$service_dir" ]; then
        error "Service directory does not exist: $service_dir"
        echo -e "${YELLOW}Please create the directory and add a docker-compose.yml file first${NC}"
        return 1
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
        return 1
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
        
        success "Service deployed successfully!"
    else
        error "Failed to deploy $service_type '$service_name'"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
}

handle_deploy_examples() {
    header "DEPLOY EXAMPLE SERVICES"
    
    echo -e "${WHITE}This will deploy example services for learning and testing.${NC}"
    echo -e "${CYAN}Services to deploy:${NC}"
    echo -e "  ${GREEN}•${NC} Example API (Simple Go REST API with basic endpoints)"
    echo -e "  ${GREEN}•${NC} Example Site (Simple static HTML site for learning)"
    echo
    echo -e "${WHITE}For LGTM Stack Testing:${NC}"
    echo -e "  ${CYAN}•${NC} Use Argus: docker run -p 3001:3001 ghcr.io/nahuelsantos/argus:v0.0.1"
    echo
    
    read -p "Continue with deployment? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        info "Deployment cancelled"
        echo
        read -p "Press Enter to return to main menu..."
        return 0
    fi
    
    # Detect Docker Compose command
    detect_docker_compose
    
    if [ -z "$DOCKER_COMPOSE" ]; then
        error "Docker Compose is not available. Please run system setup first."
        echo
        read -p "Press Enter to return to main menu..."
        return 1
    fi
    
    local deployment_success=true

    # Deploy Example API (Simple)
    step_banner "DEPLOYING EXAMPLE API (Simple REST API)"
    if [ -d "$SCRIPT_DIR/apis/example-api" ]; then
        cd "$SCRIPT_DIR/apis/example-api"
        
        # Copy .env if needed
        if [ ! -f ".env" ] && [ -f "$SCRIPT_DIR/.env" ]; then
            info "Copying environment file for example API"
            cp "$SCRIPT_DIR/.env" ".env"
        fi
        
        if $DOCKER_COMPOSE up -d; then
            success "Example API deployed successfully!"
            
            # Get API port
            local api_port=$(grep -E "^\s*-\s*\"[0-9]+:" docker-compose.yml | head -1 | sed -E 's/.*"([0-9]+):.*/\1/')
            if [ -n "$api_port" ]; then
                local server_ip=$(grep "SERVER_IP=" "$SCRIPT_DIR/.env" 2>/dev/null | cut -d'=' -f2 || hostname -I | awk '{print $1}')
                echo -e "  ${CYAN}API URL:${NC} http://$server_ip:$api_port"
                echo -e "  ${CYAN}Health Check:${NC} http://$server_ip:$api_port/health"
                echo -e "  ${CYAN}Hello Endpoint:${NC} http://$server_ip:$api_port/hello"
            fi
        else
            error "Failed to deploy example API"
            deployment_success=false
        fi
        
        cd "$SCRIPT_DIR"
    else
        warning "Example API directory not found: $SCRIPT_DIR/apis/example-api"
    fi

    # Deploy Example Site (Simple)
    step_banner "DEPLOYING EXAMPLE SITE (Simple Static Site)"
    if [ -d "$SCRIPT_DIR/sites/example-site" ]; then
        cd "$SCRIPT_DIR/sites/example-site"
        
        # Copy .env if needed
        if [ ! -f ".env" ] && [ -f "$SCRIPT_DIR/.env" ]; then
            info "Copying environment file for example site"
            cp "$SCRIPT_DIR/.env" ".env"
        fi
        
        if $DOCKER_COMPOSE up -d; then
            success "Example Site deployed successfully!"
            
            # Get site port
            local site_port=$(grep -E "^\s*-\s*\"[0-9]+:" docker-compose.yml | head -1 | sed -E 's/.*"([0-9]+):.*/\1/')
            if [ -n "$site_port" ]; then
                local server_ip=$(grep "SERVER_IP=" "$SCRIPT_DIR/.env" 2>/dev/null | cut -d'=' -f2 || hostname -I | awk '{print $1}')
                echo -e "  ${CYAN}Site URL:${NC} http://$server_ip:$site_port"
            fi
        else
            error "Failed to deploy example site"
            deployment_success=false
        fi
        
        cd "$SCRIPT_DIR"
    else
        warning "Example Site directory not found: $SCRIPT_DIR/sites/example-site"
    fi
    
    # Summary
    echo -e "\n${WHITE}Deployment Summary:${NC}"
    if [ "$deployment_success" = true ]; then
        success "All example services deployed successfully!"
        echo -e "\n${WHITE}What you have now:${NC}"
        echo -e "  ${CYAN}📚 Learning:${NC} Example API & Site for understanding the setup"
        echo -e "\n${WHITE}Next Steps:${NC}"
        echo -e "  ${CYAN}1.${NC} Test the Example API endpoints"
        echo -e "  ${CYAN}2.${NC} Explore the Example Site"
        echo -e "  ${CYAN}3.${NC} For LGTM testing: docker run -p 3001:3001 ghcr.io/nahuelsantos/argus:v0.0.1"
        echo -e "  ${CYAN}4.${NC} Add your own services using these as templates"
    else
        warning "Some deployments failed. Check the logs above for details."
        echo -e "\n${WHITE}Troubleshooting:${NC}"
        echo -e "  ${CYAN}•${NC} Check docker logs: docker compose logs <service-name>"
        echo -e "  ${CYAN}•${NC} Verify port availability: netstat -tlnp"
        echo -e "  ${CYAN}•${NC} Ensure .env file is properly configured"
    fi
    
    echo
    read -p "Press Enter to return to main menu..."
}

handle_discover_services() {
    header "DISCOVER NEW SERVICES"
    
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
        
        # Display services with numbers for selection
        for i in "${!DISCOVERED_SERVICES[@]}"; do
            IFS=':' read -r type name path <<< "${DISCOVERED_SERVICES[$i]}"
            echo -e "  ${CYAN}$((i+1)).${NC} $type: $name"
        done
        
        echo -e "\n${WHITE}Service Selection:${NC}"
        echo -e "  ${CYAN}a${NC} - Deploy all services"
        echo -e "  ${CYAN}s${NC} - Select specific services"
        echo -e "  ${CYAN}n${NC} - Skip deployment"
        echo
        read -p "Choose option (a/s/n): " -n 1 -r
        echo
        
        case $REPLY in
            a|A)
                info "Deploying all discovered services..."
                deploy_discovered_services "${DISCOVERED_SERVICES[@]}"
                ;;
            s|S)
                select_and_deploy_services
                ;;
            n|N)
                info "Skipping deployment of new services"
                ;;
            *)
                warning "Invalid option. Skipping deployment."
                ;;
        esac
    else
        info "No new services found"
    fi
    
    echo
    read -p "Press Enter to return to main menu..."
}

# Function to select specific services for deployment
select_and_deploy_services() {
    echo -e "\n${WHITE}Select services to deploy:${NC}"
    echo -e "${YELLOW}Enter service numbers separated by spaces (e.g., 1 3 5), or 'all' for all services${NC}"
    
    # Display services again for reference
    for i in "${!DISCOVERED_SERVICES[@]}"; do
        IFS=':' read -r type name path <<< "${DISCOVERED_SERVICES[$i]}"
        echo -e "  ${CYAN}$((i+1)).${NC} $type: $name"
    done
    
    echo
    read -p "Enter your selection: " selection
    
    if [ -z "$selection" ]; then
        info "No services selected. Skipping deployment."
        return
    fi
    
    # Parse selection
    local services_to_deploy=()
    
    if [ "$selection" = "all" ]; then
        services_to_deploy=("${DISCOVERED_SERVICES[@]}")
        info "Selected all services for deployment"
    else
        # Parse numbers
        for num in $selection; do
            # Validate number
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#DISCOVERED_SERVICES[@]}" ]; then
                local index=$((num-1))
                services_to_deploy+=("${DISCOVERED_SERVICES[$index]}")
                IFS=':' read -r type name path <<< "${DISCOVERED_SERVICES[$index]}"
                info "Selected: $type - $name"
            else
                warning "Invalid selection: $num (ignoring)"
            fi
        done
    fi
    
    if [ ${#services_to_deploy[@]} -eq 0 ]; then
        warning "No valid services selected. Skipping deployment."
        return
    fi
    
    echo -e "\n${WHITE}Services to deploy:${NC}"
    for service in "${services_to_deploy[@]}"; do
        IFS=':' read -r type name path <<< "$service"
        echo -e "  ${CYAN}$type${NC}: $name"
    done
    
    echo
    read -p "Proceed with deployment? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        deploy_discovered_services "${services_to_deploy[@]}"
    else
        info "Deployment cancelled"
    fi
}

# Deploy discovered services (updated to accept specific services)
deploy_discovered_services() {
    local services_to_deploy=("$@")
    
    if [ ${#services_to_deploy[@]} -eq 0 ]; then
        return 0
    fi
    
    detect_docker_compose
    
    for service in "${services_to_deploy[@]}"; do
        IFS=':' read -r type name compose_file <<< "$service"
        local service_dir=$(dirname "$compose_file")
        
        step_banner "DEPLOYING $type: $name"
        
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
            success "$type '$name' deployed successfully!"
            
            # Try to detect port from docker-compose file
            local port=$(grep -E "^\s*-\s*\"[0-9]+:" "$compose_file" | head -1 | sed -E 's/.*"([0-9]+):.*/\1/')
            if [ -n "$port" ]; then
                local server_ip=$(grep "SERVER_IP=" "$SCRIPT_DIR/.env" 2>/dev/null | cut -d'=' -f2 || hostname -I | awk '{print $1}')
                echo -e "  ${CYAN}URL:${NC} http://$server_ip:$port"
            fi
        else
            warning "Failed to deploy $type '$name'"
        fi
        
        cd "$SCRIPT_DIR"
    done
    
    success "Selected services deployment completed!"
}

handle_list_services() {
    header "ALL SERVICES STATUS"
    
    echo -e "${WHITE}Scanning for services...${NC}\n"
    
    # List APIs
    if [ -d "$SCRIPT_DIR/apis" ]; then
        echo -e "${CYAN}APIs:${NC}"
        local found_apis=false
        while IFS= read -r compose_file; do
            if [ -n "$compose_file" ]; then
                found_apis=true
                local service_dir=$(dirname "$compose_file")
                local service_name=$(basename "$service_dir")
                
                # Check if service is running
                if docker ps --format "table {{.Names}}" | grep -q "$service_name" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} $service_name (running)"
                else
                    echo -e "  ${RED}✗${NC} $service_name (stopped)"
                fi
            fi
        done < <(find "$SCRIPT_DIR/apis" -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null)
        
        if [ "$found_apis" = false ]; then
            echo -e "  ${YELLOW}No APIs found${NC}"
        fi
        echo
    fi
    
    # List Sites
    if [ -d "$SCRIPT_DIR/sites" ]; then
        echo -e "${CYAN}Sites:${NC}"
        local found_sites=false
        while IFS= read -r compose_file; do
            if [ -n "$compose_file" ]; then
                found_sites=true
                local service_dir=$(dirname "$compose_file")
                local service_name=$(basename "$service_dir")
                
                # Check if service is running
                if docker ps --format "table {{.Names}}" | grep -q "$service_name" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} $service_name (running)"
                else
                    echo -e "  ${RED}✗${NC} $service_name (stopped)"
                fi
            fi
        done < <(find "$SCRIPT_DIR/sites" -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null)
        
        if [ "$found_sites" = false ]; then
            echo -e "  ${YELLOW}No sites found${NC}"
        fi
        echo
    fi
    
    # List Core Services
    echo -e "${CYAN}Core Services:${NC}"
    if command -v docker >/dev/null 2>&1; then
        # Try docker-compose first, then docker compose
        local docker_cmd=""
        if command -v docker-compose >/dev/null 2>&1; then
            docker_cmd="docker-compose"
        elif docker compose version >/dev/null 2>&1; then
            docker_cmd="docker compose"
        fi
        
        if [ -n "$docker_cmd" ] && $docker_cmd ps >/dev/null 2>&1; then
            # Process each service directly with ports info
            $docker_cmd ps --format "{{.Name}}\t{{.Status}}\t{{.Ports}}" | while IFS=$'\t' read -r name status ports; do
                if [[ "$status" == *"Up"* ]]; then
                    echo -e "  ${GREEN}✓${NC} $name - $ports"
                elif [[ "$status" == *"Restarting"* ]]; then
                    echo -e "  ${YELLOW}⟳${NC} $name - restarting"
                elif [[ -n "$status" ]]; then
                    echo -e "  ${RED}✗${NC} $name - $status"
                fi
            done
        else
            echo -e "  ${YELLOW}No services running${NC}"
        fi
    else
        echo -e "  ${RED}✗${NC} Docker not available"
    fi
    
    success "Service listing completed"
    
    echo
    read -p "Press Enter to return to main menu..."
}

handle_system_status() {
    header "System Status & Health"
    
    echo -e "${WHITE}System Information:${NC}"
    echo -e "  ${CYAN}OS:${NC} $(lsb_release -d 2>/dev/null | cut -f2 || uname -o)"
    echo -e "  ${CYAN}Kernel:${NC} $(uname -r)"
    echo -e "  ${CYAN}Memory:${NC} $(free -h | awk 'NR==2{printf "Used: %s/%s (%.1f%%)", $3,$2,$3*100/$2}')"
    echo -e "  ${CYAN}Disk:${NC} $(df -h / | awk 'NR==2{printf "Used: %s/%s (%s)", $3,$2,$5}')"
    
    echo -e "\n${WHITE}Docker Status:${NC}"
    if command -v docker >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Docker installed: $(docker --version | cut -d' ' -f3 | tr -d ',')"
        if docker compose version >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Docker Compose: $(docker compose version --short)"
        fi
        
        echo -e "\n${WHITE}Running Services:${NC}"
        # Try docker-compose first, then docker compose
        local docker_cmd=""
        if command -v docker-compose >/dev/null 2>&1; then
            docker_cmd="docker-compose"
        elif docker compose version >/dev/null 2>&1; then
            docker_cmd="docker compose"
        fi
        
        if [ -n "$docker_cmd" ] && $docker_cmd ps >/dev/null 2>&1; then
            # Process each service directly with ports info
            $docker_cmd ps --format "{{.Name}}\t{{.Status}}\t{{.Ports}}" | while IFS=$'\t' read -r name status ports; do
                if [[ "$status" == *"Up"* ]]; then
                    echo -e "  ${GREEN}✓${NC} $name - $ports"
                elif [[ "$status" == *"Restarting"* ]]; then
                    echo -e "  ${YELLOW}⟳${NC} $name - restarting"
                elif [[ -n "$status" ]]; then
                    echo -e "  ${RED}✗${NC} $name - $status"
                fi
            done
        else
            echo -e "  ${YELLOW}No services running${NC}"
        fi
    else
        echo -e "  ${RED}✗${NC} Docker not installed"
    fi
    
    echo -e "\n${WHITE}Security Status:${NC}"
    command -v ufw >/dev/null 2>&1 && echo -e "  ${GREEN}✓${NC} UFW Firewall: $(ufw status | head -1 | cut -d: -f2 | tr -d ' ')" || echo -e "  ${RED}✗${NC} UFW not installed"
    command -v fail2ban-client >/dev/null 2>&1 && echo -e "  ${GREEN}✓${NC} Fail2ban: Active" || echo -e "  ${YELLOW}○${NC} Fail2ban not installed"
    
    echo
    read -p "Press Enter to return to main menu..."
}

handle_help() {
    header "Help & Documentation"
    
    echo -e "${WHITE}Menu Navigation:${NC}"
    echo -e "  ${RED}🔐${NC} = Option requires sudo privileges"
    echo -e "  Options 1-5 need 'sudo ./dinky.sh' to run"
    echo -e "  Options 6-10 can run without sudo"
    
    echo -e "\n${WHITE}Quick Start Guide:${NC}"
    echo -e "  ${CYAN}1.${NC} First-time users: Choose ${GREEN}Full Setup${NC} (option 1)"
    echo -e "  ${CYAN}2.${NC} Existing systems: Use ${GREEN}Deploy Services Only${NC} (option 3) - Select components"
    echo -e "  ${CYAN}3.${NC} Try all services: Use ${GREEN}Deploy All Services${NC} (option 5)"
    echo -e "  ${CYAN}4.${NC} Add more services: Use ${GREEN}Add Individual Service${NC} (option 4)"
    
    echo -e "\n${WHITE}Security Levels:${NC}"
    echo -e "  ${CYAN}Basic:${NC} Firewall + Fail2ban + Docker security"
    echo -e "  ${CYAN}Standard:${NC} Basic + SSH hardening + Auto-updates"
    echo -e "  ${CYAN}Comprehensive:${NC} Standard + Log monitoring + Security audit"
    
    echo -e "\n${WHITE}Available Services:${NC}"
    echo -e "  ${CYAN}Portainer:${NC} Docker container management interface"
    echo -e "  ${CYAN}Traefik:${NC} Reverse proxy and load balancer"
    echo -e "  ${CYAN}Pi-hole:${NC} Network-wide ad blocking"
    echo -e "  ${CYAN}Monitoring:${NC} Full LGTM stack (Grafana, Prometheus, Loki, Tempo)"
    echo -e "  ${CYAN}Cloudflared:${NC} Secure tunnel for external access"
    echo -e "  ${CYAN}Mail Server:${NC} SMTP relay for internal services"
    echo -e "  ${CYAN}Dinky Monitor:${NC} Advanced monitoring API with system insights"
    echo -e "  ${CYAN}Dinky Dashboard:${NC} Advanced observability control center"
    echo -e "  ${CYAN}Example API:${NC} Simple Go REST API for learning"
    echo -e "  ${CYAN}Example Site:${NC} Simple static HTML site for learning"
    
    echo -e "\n${WHITE}Documentation:${NC}"
    echo -e "  ${CYAN}Main README:${NC} ./README.md"
    echo -e "  ${CYAN}APIs Guide:${NC} ./docs/apis-guide.md"
    echo -e "  ${CYAN}Sites Guide:${NC} ./docs/sites-guide.md"
    echo -e "  ${CYAN}Logs:${NC} tail -f $LOG_FILE"
    
    echo -e "\n${WHITE}Support Commands:${NC}"
    echo -e "  ${CYAN}Service Status:${NC} docker compose ps"
    echo -e "  ${CYAN}View Logs:${NC} docker compose logs -f"
    echo -e "  ${CYAN}Restart Service:${NC} docker compose restart <service>"
    echo -e "  ${CYAN}Stop All:${NC} docker compose down"
    
    echo -e "\n${WHITE}Port Reference:${NC}"
    echo -e "  ${CYAN}Web UIs:${NC} 8080 (Traefik), 8081 (Pi-hole), 9000 (Portainer)"
    echo -e "  ${CYAN}Monitoring:${NC} 3000 (Grafana), 9090 (Prometheus), 4040 (Pyroscope)"
    echo -e "  ${CYAN}Dinky Services:${NC} 3001 (Monitor), 3002 (Dashboard)"
    echo -e "  ${CYAN}Examples:${NC} 8080 (API), 8081 (Site) in production"
    echo -e "  ${CYAN}Available:${NC} 3003-3099 (APIs), 8003-8099 (Sites)"
    
    echo
    read -p "Press Enter to return to main menu..."
}

# Main script execution
main() {
    # Source function definitions
    source_setup_functions
    source_deploy_functions
    
    # Check root for system operations (only for certain options)
    if [[ "$1" != "--help" && "$1" != "-h" ]]; then
        case "${1:-menu}" in
            1|2|full|setup) check_root ;;
        esac
    fi
    
    # Handle command line arguments
    case "${1:-menu}" in
        --help|-h)
            echo "Dinky Server - Unified Deployment Script"
            echo "Usage: sudo ./dinky.sh [option]"
            echo
            echo "Options:"
            echo "  1, full     Full setup (system + services)"
            echo "  2, setup    System setup only"
            echo "  3, deploy   Deploy services only"
            echo "  --help      Show this help"
            echo
            echo "Interactive menu will be shown if no option is provided."
            exit 0
            ;;
        1|full)
            check_root
            handle_full_setup
            exit 0
            ;;
        2|setup)
            check_root
            handle_system_setup
            exit 0
            ;;
        3|deploy)
            check_root
            handle_deploy_services
            exit 0
            ;;
    esac
    
    # Interactive menu mode
    while true; do
        show_menu
        read -p "Select an option (0-9): " -n 1 -r REPLY
        echo
        
        case $REPLY in
            1) check_root && handle_full_setup ;;
            2) check_root && handle_system_setup ;;
            3) check_root && handle_deploy_services ;;
            4) check_root && handle_add_service ;;
            5) check_root && handle_deploy_examples ;;
            6) handle_discover_services ;;
            7) handle_list_services ;;
            8) handle_system_status ;;
            9) handle_help ;;
            0) 
                echo -e "${GREEN}Thank you for using Dinky Server!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 0-9.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run main function with all arguments
main "$@" 