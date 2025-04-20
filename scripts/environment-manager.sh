#!/bin/bash
set -e

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DINKY_ROOT="/opt/dinky-server"

# Print help message
function show_help {
    echo -e "${BLUE}===== Dinky Server Environment Manager =====${NC}"
    echo -e "This script helps manage environment variables across your Dinky server components."
    echo -e ""
    echo -e "Usage: $0 [command] [arguments]"
    echo -e ""
    echo -e "Commands:"
    echo -e "  setup-env [component]        - Create environment files for a component based on templates"
    echo -e "  update-env [component] [var] - Update a specific environment variable"
    echo -e "  list-env [component]         - List all environment files and their values"
    echo -e "  backup-env                   - Create a timestamped backup of all environment files"
    echo -e ""
    echo -e "Components:"
    echo -e "  main           - Main server environment variables"
    echo -e "  mail           - Mail service environment variables"
    echo -e "  monitoring     - Monitoring stack environment variables"
    echo -e "  traefik        - Traefik environment variables"
    echo -e "  cloudflared    - Cloudflared environment variables"
    echo -e "  site-[name]    - Environment for a specific site (e.g., site-nahuelsantos)"
    echo -e ""
    echo -e "Examples:"
    echo -e "  $0 setup-env mail"
    echo -e "  $0 update-env mail MAIL_DOMAIN=example.com"
    echo -e "  $0 list-env"
}

# Create environment files based on templates
function setup_env {
    local component=$1
    
    case $component in
        main)
            if [ ! -f "$DINKY_ROOT/.env" ]; then
                echo -e "${YELLOW}Creating main environment file...${NC}"
                cat > "$DINKY_ROOT/.env" << EOL
# Main Dinky Server Environment Variables
TZ=UTC

# Server hostname and domain
SERVER_HOSTNAME=dinky
SERVER_DOMAIN=local

# Network configuration
DOCKER_SUBNET=192.168.3.0/24
DOCKER_GATEWAY=192.168.3.1

# Traefik basic auth credentials (if needed)
# Generate with: echo \$(htpasswd -nb admin secure_password) | sed -e s/\\$/\\$\\$/g
# TRAEFIK_BASIC_AUTH=admin:$$2y$$05$$rtsKhz.....
EOL
                echo -e "${GREEN}Main environment file created at $DINKY_ROOT/.env${NC}"
            else
                echo -e "${YELLOW}Main environment file already exists. Use update-env to modify it.${NC}"
            fi
            ;;
            
        mail)
            if [ ! -f "$DINKY_ROOT/services/.env.mail.prod" ]; then
                echo -e "${YELLOW}Creating mail environment file...${NC}"
                
                # If template exists, copy it
                if [ -f "$DINKY_ROOT/services/.env.mail" ]; then
                    cp "$DINKY_ROOT/services/.env.mail" "$DINKY_ROOT/services/.env.mail.prod"
                    echo -e "${GREEN}Mail environment file created from template at $DINKY_ROOT/services/.env.mail.prod${NC}"
                    echo -e "${YELLOW}Please review and update the file with your settings.${NC}"
                else
                    echo -e "${RED}Mail template file not found. Creating basic template.${NC}"
                    cat > "$DINKY_ROOT/services/.env.mail.prod" << EOL
# Mail Service Environment Variables
TZ=UTC

# Mail Server Configuration
MAIL_DOMAIN=example.com
MAIL_HOSTNAME=mail.example.com

# Default From Address for Contact Forms
DEFAULT_FROM=noreply@example.com

# Allowed Host Domains (comma-separated)
ALLOWED_HOSTS=example.com,subdomain.example.com

# Gmail SMTP Relay Configuration (RECOMMENDED)
# RELAY_HOST=smtp.gmail.com
# RELAY_PORT=587
# RELAY_USER=your-gmail-address@gmail.com
# RELAY_PASSWORD=your-16-character-app-password
EOL
                    echo -e "${GREEN}Basic mail environment file created at $DINKY_ROOT/services/.env.mail.prod${NC}"
                    echo -e "${YELLOW}Please update the file with your specific settings.${NC}"
                fi
            else
                echo -e "${YELLOW}Mail environment file already exists. Use update-env to modify it.${NC}"
            fi
            ;;
            
        monitoring)
            if [ ! -f "$DINKY_ROOT/monitoring/.env.monitoring" ]; then
                echo -e "${YELLOW}Creating monitoring environment file...${NC}"
                cat > "$DINKY_ROOT/monitoring/.env.monitoring" << EOL
# Monitoring Stack Environment Variables

# Grafana configuration
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=change_me_immediately
GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-worldmap-panel

# Data retention
PROMETHEUS_RETENTION_TIME=15d
LOKI_RETENTION_PERIOD=720h
TEMPO_RETENTION_PERIOD=336h

# Resource limits
PROMETHEUS_MEMORY=1G
LOKI_MEMORY=512M
GRAFANA_MEMORY=512M
EOL
                echo -e "${GREEN}Monitoring environment file created at $DINKY_ROOT/monitoring/.env.monitoring${NC}"
            else
                echo -e "${YELLOW}Monitoring environment file already exists. Use update-env to modify it.${NC}"
            fi
            ;;
            
        site-*)
            local site_name=${component#site-}
            if [ -z "$site_name" ]; then
                echo -e "${RED}Site name is required. Use site-[name] format.${NC}"
                return 1
            fi
            
            local site_dir="$DINKY_ROOT/sites/$site_name"
            mkdir -p "$site_dir"
            
            if [ ! -f "$site_dir/.env.prod" ]; then
                echo -e "${YELLOW}Creating environment file for site $site_name...${NC}"
                cat > "$site_dir/.env.prod" << EOL
# Production Environment for $site_name site

# Site-specific settings
SITE_DOMAIN=$site_name.com
SITE_EMAIL=hello@$site_name.com

# Database configuration (if needed)
# DB_HOST=localhost
# DB_NAME=${site_name}_db
# DB_USER=${site_name}_user
# DB_PASSWORD=change_me_immediately

# Mail API configuration
MAIL_API_URL=http://mail-api:20001/send
EOL
                echo -e "${GREEN}Site environment file created at $site_dir/.env.prod${NC}"
            else
                echo -e "${YELLOW}Site environment file already exists. Use update-env to modify it.${NC}"
            fi
            ;;
            
        *)
            echo -e "${RED}Unknown component: $component${NC}"
            show_help
            return 1
            ;;
    esac
}

# Update a specific environment variable
function update_env {
    local component=$1
    local var_setting=$2
    
    if [ -z "$var_setting" ]; then
        echo -e "${RED}Variable setting is required in format KEY=VALUE${NC}"
        return 1
    fi
    
    # Split the variable setting into key and value
    local key=$(echo $var_setting | cut -d= -f1)
    local value=$(echo $var_setting | cut -d= -f2-)
    
    if [ -z "$key" ] || [ -z "$value" ]; then
        echo -e "${RED}Invalid format. Use KEY=VALUE format.${NC}"
        return 1
    fi
    
    local env_file=""
    case $component in
        main)
            env_file="$DINKY_ROOT/.env"
            ;;
        mail)
            env_file="$DINKY_ROOT/services/.env.mail.prod"
            ;;
        monitoring)
            env_file="$DINKY_ROOT/monitoring/.env.monitoring"
            ;;
        site-*)
            local site_name=${component#site-}
            if [ -z "$site_name" ]; then
                echo -e "${RED}Site name is required. Use site-[name] format.${NC}"
                return 1
            fi
            env_file="$DINKY_ROOT/sites/$site_name/.env.prod"
            ;;
        *)
            echo -e "${RED}Unknown component: $component${NC}"
            show_help
            return 1
            ;;
    esac
    
    if [ ! -f "$env_file" ]; then
        echo -e "${RED}Environment file not found: $env_file${NC}"
        echo -e "${YELLOW}Create it first with: $0 setup-env $component${NC}"
        return 1
    fi
    
    # Check if the key already exists
    if grep -q "^$key=" "$env_file"; then
        # Update existing key
        sed -i "s|^$key=.*|$key=$value|" "$env_file"
        echo -e "${GREEN}Updated $key in $env_file${NC}"
    else
        # Add new key
        echo "$key=$value" >> "$env_file"
        echo -e "${GREEN}Added $key to $env_file${NC}"
    fi
}

# List all environment files and their values
function list_env {
    local component=$1
    
    if [ -z "$component" ]; then
        echo -e "${BLUE}Available environment files:${NC}"
        
        if [ -f "$DINKY_ROOT/.env" ]; then
            echo -e "  ✅ Main environment: $DINKY_ROOT/.env"
        fi
        
        if [ -f "$DINKY_ROOT/services/.env.mail.prod" ]; then
            echo -e "  ✅ Mail service: $DINKY_ROOT/services/.env.mail.prod"
        fi
        
        if [ -f "$DINKY_ROOT/monitoring/.env.monitoring" ]; then
            echo -e "  ✅ Monitoring stack: $DINKY_ROOT/monitoring/.env.monitoring"
        fi
        
        # Find site environment files
        for site_env in $(find "$DINKY_ROOT/sites" -name ".env.prod" 2>/dev/null); do
            site_name=$(basename $(dirname "$site_env"))
            echo -e "  ✅ Site $site_name: $site_env"
        done
        
        echo -e "\nUse '$0 list-env [component]' to view the contents of a specific file."
        return 0
    fi
    
    local env_file=""
    case $component in
        main)
            env_file="$DINKY_ROOT/.env"
            ;;
        mail)
            env_file="$DINKY_ROOT/services/.env.mail.prod"
            ;;
        monitoring)
            env_file="$DINKY_ROOT/monitoring/.env.monitoring"
            ;;
        site-*)
            local site_name=${component#site-}
            if [ -z "$site_name" ]; then
                echo -e "${RED}Site name is required. Use site-[name] format.${NC}"
                return 1
            fi
            env_file="$DINKY_ROOT/sites/$site_name/.env.prod"
            ;;
        *)
            echo -e "${RED}Unknown component: $component${NC}"
            show_help
            return 1
            ;;
    esac
    
    if [ ! -f "$env_file" ]; then
        echo -e "${RED}Environment file not found: $env_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Contents of $env_file:${NC}"
    while IFS= read -r line; do
        if [[ $line =~ ^#.* ]] || [[ -z $line ]]; then
            # Print comments and empty lines as is
            echo -e "  $line"
        elif [[ $line =~ PASSWORD|SECRET|KEY|TOKEN ]]; then
            # Mask sensitive values
            key=$(echo "$line" | cut -d= -f1)
            echo -e "  $key=********"
        else
            # Print other variables normally
            echo -e "  $line"
        fi
    done < "$env_file"
}

# Backup all environment files
function backup_env {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_dir="$DINKY_ROOT/scripts/backup/env_$timestamp"
    
    mkdir -p "$backup_dir"
    
    # Backup main .env
    if [ -f "$DINKY_ROOT/.env" ]; then
        cp "$DINKY_ROOT/.env" "$backup_dir/main.env"
    fi
    
    # Backup mail env
    if [ -f "$DINKY_ROOT/services/.env.mail.prod" ]; then
        cp "$DINKY_ROOT/services/.env.mail.prod" "$backup_dir/mail.env"
    fi
    
    # Backup monitoring env
    if [ -f "$DINKY_ROOT/monitoring/.env.monitoring" ]; then
        cp "$DINKY_ROOT/monitoring/.env.monitoring" "$backup_dir/monitoring.env"
    fi
    
    # Backup site envs
    for site_env in $(find "$DINKY_ROOT/sites" -name ".env.prod" 2>/dev/null); do
        site_name=$(basename $(dirname "$site_env"))
        cp "$site_env" "$backup_dir/site_${site_name}.env"
    done
    
    echo -e "${GREEN}All environment files backed up to $backup_dir${NC}"
}

# Main function
function main {
    local command=$1
    shift
    
    case $command in
        setup-env)
            setup_env "$@"
            ;;
        update-env)
            update_env "$@"
            ;;
        list-env)
            list_env "$@"
            ;;
        backup-env)
            backup_env
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            if [ -z "$command" ]; then
                show_help
            else
                echo -e "${RED}Unknown command: $command${NC}"
                show_help
                exit 1
            fi
            ;;
    esac
}

# Run the script
main "$@" 