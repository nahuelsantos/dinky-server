#!/bin/bash
# Dinky Server System Setup Script
# Handles system preparation, security, and environment configuration

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
LOG_FILE="/var/log/dinky-setup.log"
BACKUP_DIR="/opt/dinky-backups/$(date +%Y%m%d_%H%M%S)"

# Command line flags
HELP_FLAG=false
SECURITY_LEVEL=2

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --security-level)
                SECURITY_LEVEL="$2"
                shift 2
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
    echo -e "${CYAN}Dinky Server System Setup Script${NC}"
    echo -e "${CYAN}================================${NC}\n"
    echo -e "${WHITE}Usage:${NC}"
    echo -e "  ${GREEN}sudo ./setup.sh${NC}                           # Default setup (security level 2)"
    echo -e "  ${GREEN}sudo ./setup.sh --security-level 3${NC}       # Comprehensive security"
    echo -e "  ${GREEN}sudo ./setup.sh --security-level 1${NC}       # Basic security only"
    echo -e "  ${GREEN}sudo ./setup.sh --help${NC}                   # Show this help"
    echo
    echo -e "${WHITE}Security Levels:${NC}"
    echo -e "  ${CYAN}1. Basic${NC} - Firewall + Fail2ban + Docker security"
    echo -e "  ${CYAN}2. Standard${NC} - Basic + SSH hardening + Auto-updates"
    echo -e "  ${CYAN}3. Comprehensive${NC} - Standard + Log monitoring + Security audit"
    echo
    echo -e "${WHITE}Examples:${NC}"
    echo -e "  ${YELLOW}# Quick basic setup${NC}"
    echo -e "  sudo ./setup.sh --security-level 1"
    echo
    echo -e "  ${YELLOW}# Full security hardening${NC}"
    echo -e "  sudo ./setup.sh --security-level 3"
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
    error "Setup failed. Initiating rollback..."
    
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
TZ=Europe/Madrid
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
        warning "Please update the SMTP and Cloudflare settings in $env_file before deploying services"
    else
        success "Environment file already exists"
    fi
}

# Setup security
setup_security() {
    header "Security Configuration"
    
    info "Running security setup (Level $SECURITY_LEVEL)..."
    
    # For Level 3, use master-security-setup.sh which handles everything
    if [ "$SECURITY_LEVEL" -ge 3 ]; then
        if [ -f "$SCRIPT_DIR/infrastructure/firewall/master-security-setup.sh" ]; then
            info "Running comprehensive security setup..."
            bash "$SCRIPT_DIR/infrastructure/firewall/master-security-setup.sh" || warning "Master security setup had issues, continuing..."
        fi
    else
        # For Level 1 and 2, run individual scripts to avoid duplication
        
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
        if [ "$SECURITY_LEVEL" -ge 2 ]; then
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
    fi
    
    success "Security configuration completed (Level $SECURITY_LEVEL)"
}

# Create Docker networks
setup_docker_networks() {
    header "Setting Up Docker Networks"
    
    info "Creating Docker networks..."
    docker network create traefik_network 2>/dev/null || info "traefik_network already exists"
    
    success "Docker networks ready"
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
 ____  _       _            ____       _               
|  _ \(_)_ __ | | ___   _  / ___|  ___| |_ _   _ _ __  
| | | | | '_ \| |/ / | | | \___ \ / _ \ __| | | | '_ \ 
| |_| | | | | |   <| |_| |  ___) |  __/ |_| |_| | |_) |
|____/|_|_| |_|_|\_\\__, | |____/ \___|\__|\__,_| .__/ 
                    |___/                       |_|    
EOF
    echo -e "${NC}"
    echo -e "${WHITE}System Preparation & Security Configuration${NC}\n"
    
    # Full setup execution flow
    check_root
    setup_directories
    backup_existing_config
    check_requirements
    install_dependencies
    setup_environment
    setup_security
    setup_docker_networks
    
    # Disable error trap for successful completion
    trap - ERR
    
    # Final message
    header "System Setup Complete!"
    
    echo -e "${GREEN}🎉 Your server is now prepared and secured!${NC}\n"
    
    echo -e "${WHITE}What's been configured:${NC}"
    echo -e "  ✅ System dependencies installed"
    echo -e "  ✅ Docker and Docker Compose ready"
    echo -e "  ✅ Security hardening applied (Level $SECURITY_LEVEL)"
    echo -e "  ✅ Environment variables configured"
    echo -e "  ✅ Docker networks created"
    
    echo -e "\n${WHITE}Next steps:${NC}"
    echo -e "  ${CYAN}1.${NC} Review and update settings in ${YELLOW}.env${NC}"
    echo -e "  ${CYAN}2.${NC} Deploy services with: ${GREEN}sudo ./deploy.sh${NC}"
    echo -e "  ${CYAN}3.${NC} Configure external services (Cloudflare tunnel, SMTP)"
    
    success "System setup completed successfully!"
}

# Run main function
main "$@" 