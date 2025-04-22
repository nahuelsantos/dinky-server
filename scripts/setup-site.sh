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
    echo -e "${BLUE}===== Dinky Server Site Setup =====${NC}"
    echo -e "This script helps set up a new website in your Dinky server."
    echo -e ""
    echo -e "Usage: $0 [site_name] [domain] [git_repo]"
    echo -e ""
    echo -e "Arguments:"
    echo -e "  site_name  - Name of the site directory (e.g., nahuelsantos)"
    echo -e "  domain     - Domain for the site (e.g., nahuelsantos.com)"
    echo -e "  git_repo   - Git repository URL (optional)"
    echo -e ""
    echo -e "Examples:"
    echo -e "  $0 nahuelsantos nahuelsantos.com https://github.com/nahuelsantos/nahuelsantos-website.git"
    echo -e "  $0 loopingbyte loopingbyte.com"
}

# Main setup function
function setup_site {
    local site_name=$1
    local domain=$2
    local git_repo=$3
    
    if [ -z "$site_name" ] || [ -z "$domain" ]; then
        echo -e "${RED}Error: Site name and domain are required.${NC}"
        show_help
        exit 1
    fi
    
    echo -e "${BLUE}===== Setting up site: $site_name at $domain =====${NC}"
    
    # Create site directory
    local site_dir="$DINKY_ROOT/sites/$site_name"
    if [ -d "$site_dir" ]; then
        echo -e "${YELLOW}Site directory already exists: $site_dir${NC}"
        read -p "Do you want to continue and potentially overwrite files? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Setup cancelled.${NC}"
            exit 1
        fi
    else
        echo -e "Creating site directory: $site_dir"
        mkdir -p "$site_dir"
    fi
    
    # Clone git repository if provided
    if [ ! -z "$git_repo" ]; then
        echo -e "${BLUE}Cloning repository: $git_repo${NC}"
        if [ -d "$site_dir/.git" ]; then
            read -p "Git repository already exists. Pull latest changes? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cd "$site_dir" && git pull
            fi
        else
            git clone "$git_repo" "$site_dir"
        fi
    fi
    
    # Create environment file
    echo -e "${BLUE}Setting up environment file${NC}"
    if [ -f "/opt/dinky-server/scripts/environment-manager.sh" ]; then
        bash /opt/dinky-server/scripts/environment-manager.sh setup-env "site-$site_name"
        
        # Update domain in environment file
        bash /opt/dinky-server/scripts/environment-manager.sh update-env "site-$site_name" "SITE_DOMAIN=$domain"
        bash /opt/dinky-server/scripts/environment-manager.sh update-env "site-$site_name" "SITE_EMAIL=hello@$domain"
    else
        echo -e "${RED}Environment manager script not found. Creating basic environment file.${NC}"
        
        cat > "$site_dir/.env.prod" << EOL
# Production Environment for $site_name site

# Site-specific settings
SITE_DOMAIN=$domain
SITE_EMAIL=hello@$domain

# Mail API configuration
MAIL_API_URL=http://mail-api:20001/send
EOL
        echo -e "${GREEN}Basic environment file created at $site_dir/.env.prod${NC}"
    fi
    
    # Create docker-compose.yml if it doesn't exist
    if [ ! -f "$site_dir/docker-compose.yml" ]; then
        echo -e "${BLUE}Creating sample docker-compose.yml${NC}"
        
        cat > "$site_dir/docker-compose.yml" << EOL
services:
  $site_name-web:
    # Use your site's Docker image or build configuration
    # Example for a Node.js site:
    # image: node:16-alpine
    # build: .
    container_name: $site_name-web
    restart: unless-stopped
    networks:
      - default
      - traefik_network
      - mail-internal  # For connecting to the mail service
    env_file:
      - .env.prod
    # Map your site's port (adjust as needed)
    # ports:
    #   - "20002:20002"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.$site_name.rule=Host(\`$domain\`)"
      - "traefik.http.routers.$site_name.entrypoints=websecure"
      - "traefik.http.routers.$site_name.tls=true"
      # Adjust service port if needed
      - "traefik.http.services.$site_name.loadbalancer.server.port=20002"

networks:
  traefik_network:
    external: true
  mail-internal:
    external: true
    name: services_mail-internal
EOL
        echo -e "${GREEN}Sample docker-compose.yml created at $site_dir/docker-compose.yml${NC}"
        echo -e "${YELLOW}Please review and adjust the docker-compose.yml according to your site's needs.${NC}"
    else
        echo -e "${YELLOW}docker-compose.yml already exists. Skipping creation.${NC}"
        
        # Check if the docker-compose.yml has mail-internal network
        if ! grep -q "mail-internal" "$site_dir/docker-compose.yml"; then
            echo -e "${YELLOW}Note: Your docker-compose.yml might need to be updated to connect to the mail service.${NC}"
            echo -e "Add these networks to your service:"
            echo -e "  networks:"
            echo -e "    - default"
            echo -e "    - traefik_network"
            echo -e "    - mail-internal"
            echo -e ""
            echo -e "And add this to the networks section:"
            echo -e "  mail-internal:"
            echo -e "    external: true"
            echo -e "    name: services_mail-internal"
        fi
    fi
    
    echo -e "${GREEN}Site setup complete!${NC}"
    echo -e "The site has been set up at: $site_dir"
    echo -e ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "1. Review and adjust the docker-compose.yml according to your site's needs"
    echo -e "2. Review and update the environment file: $site_dir/.env.prod"
    echo -e "3. Deploy your site with: cd $site_dir && docker-compose up -d"
}

# Display help if no arguments
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# Handle help flag
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_help
    exit 0
fi

# Run the setup
setup_site "$1" "$2" "$3" 