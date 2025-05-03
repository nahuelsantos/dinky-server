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

# Determine Docker Compose command
determine_docker_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
        success "Using docker-compose command"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        success "Using docker compose command"
    else
        warning "Neither docker-compose nor docker compose found. Will be installed during setup."
        DOCKER_COMPOSE_CMD="docker compose"
    fi
}

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
    
    # Create mail environment example file if needed
    if [ ! -f "services/.env.mail.example" ]; then
        warning "services/.env.mail.example file not found, creating one..."
        
        mkdir -p services
        cat > services/.env.mail.example << EOF
# Mail server configuration
MAIL_DOMAIN=nahuelsantos.com
MAIL_HOSTNAME=mail.nahuelsantos.com
DEFAULT_FROM=noreply@nahuelsantos.com
ALLOWED_HOSTS=nahuelsantos.com,loopingbyte.com
EOF
        
        success "Created services/.env.mail.example file"
    else
        success "services/.env.mail.example file exists"
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
    
    # Check for mail compose file
    if [ ! -f "services/docker-compose.yml" ]; then
        warning "services/docker-compose.yml not found. Mail services may not work."
        warning "Creating a basic services/docker-compose.yml file..."
        
        # Create the basic file
        mkdir -p services
        cp -f "$(dirname "$0")/services/docker-compose.yml" services/docker-compose.yml 2>/dev/null || cat > services/docker-compose.yml << EOF
version: '3'

# Consolidated Docker Compose file for all mail services
# Supports both local and production environments through environment variables

services:
  mail-server:
    image: alpine:3.18
    build:
      context: ./mail-server
      dockerfile: Dockerfile
    container_name: \${PROJECT:-dinky}_mail-server
    hostname: \${MAIL_HOSTNAME:-mail.dinky.local}
    restart: unless-stopped
    networks:
      - traefik_network
      - mail-internal
    ports:
      - "\${SERVER_IP:-127.0.0.1}:25:25"   # SMTP
      - "\${SERVER_IP:-127.0.0.1}:587:587" # Submission
    volumes:
      - mail-data:/var/mail
      - mail-logs:/var/log/mail
      - \${SSL_CERT_PATH:-./mail-server/certs/fullchain.pem}:/etc/ssl/certs/cert.pem:ro
      - \${SSL_KEY_PATH:-./mail-server/certs/privkey.pem}:/etc/ssl/private/key.pem:ro
    environment:
      - TZ=\${TZ:-America/Argentina/Buenos_Aires}
      - MAIL_DOMAIN=\${MAIL_DOMAIN:-dinky.local}
      - MAIL_HOSTNAME=\${MAIL_HOSTNAME:-mail.dinky.local}
      - RELAY_HOST=\${SMTP_RELAY_HOST:-smtp.gmail.com}
      - RELAY_PORT=\${SMTP_RELAY_PORT:-587}
      - RELAY_USER=\${SMTP_RELAY_USERNAME:-your-gmail-username@gmail.com}
      - RELAY_PASSWORD=\${SMTP_RELAY_PASSWORD:-your-gmail-app-password}
      - USE_TLS=\${USE_TLS:-yes}
      - TLS_VERIFY=\${TLS_VERIFY:-yes}
      - DEFAULT_USER=\${MAIL_USER:-admin}
      - DEFAULT_PASS=\${MAIL_PASSWORD:-password}
      - DEFAULT_FROM=\${DEFAULT_FROM:-noreply@dinky.local}
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "25"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  mail-api:
    image: node:18-alpine
    build:
      context: ../apis/mail-api
      dockerfile: Dockerfile
    container_name: \${PROJECT:-dinky}_mail-api
    restart: unless-stopped
    networks:
      - traefik_network
      - mail-internal
    depends_on:
      - mail-server
    environment:
      - NODE_ENV=\${NODE_ENV:-production}
      - PORT=20001
      - SMTP_HOST=mail-server
      - SMTP_PORT=25
      - MAIL_DOMAIN=\${MAIL_DOMAIN:-dinky.local}
      - MAIL_HOSTNAME=\${MAIL_HOSTNAME:-mail.dinky.local}
      - DEFAULT_FROM=\${DEFAULT_FROM:-noreply@dinky.local}
      - ALLOWED_HOSTS=\${ALLOWED_HOSTS:-dinky.local}
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:20001/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mail-api.rule=Host(\`mail-api.\${DOMAIN_NAME:-dinky.local}\`)"
      - "traefik.http.routers.mail-api.service=mail-api"
      - "traefik.http.services.mail-api.loadbalancer.server.port=20001"
      # These labels are only applied in production
      - "traefik.http.routers.mail-api.entrypoints=\${TRAEFIK_ENTRYPOINT:-web}"
      - "traefik.http.routers.mail-api.tls=\${ENABLE_TLS:-false}"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  mail-data:
  mail-logs:

networks:
  traefik_network:
    external: true
  mail-internal:
    external: false
EOF
        success "Created services/docker-compose.yml file"
    else
        success "Mail compose file exists"
    fi
}

# Ensure mail service Dockerfiles exist
check_mail_services() {
    section "Checking mail service files"
    
    # Check for mail server Dockerfile
    if [ ! -f "services/mail-server/Dockerfile" ]; then
        warning "services/mail-server/Dockerfile not found, creating a basic one..."
        
        mkdir -p services/mail-server
        cat > services/mail-server/Dockerfile << EOF
FROM alpine:3.18

# Install packages with corrected package names that work on ARM architectures
RUN apk add --no-cache postfix postfix-pcre ca-certificates mailx cyrus-sasl cyrus-sasl-login cyrus-sasl-plain openssl || \\
    apk add --no-cache postfix postfix-pcre ca-certificates mailx cyrus-sasl cyrus-sasl-login cyrus-sasl-crammd5 openssl

# Create necessary directories
RUN mkdir -p /etc/postfix/sasl /var/spool/mail

# Copy configuration files
COPY ./postfix-main.cf /etc/postfix/main.cf
COPY ./sasl/sasl_passwd /etc/postfix/sasl/sasl_passwd
COPY ./start.sh /start.sh

# Set permissions and prepare the environment
RUN chmod +x /start.sh && \\
    chmod 600 /etc/postfix/sasl/sasl_passwd && \\
    touch /var/log/mail.log && \\
    update-ca-certificates && \\
    postmap /etc/postfix/sasl/sasl_passwd && \\
    chmod 600 /etc/postfix/sasl/sasl_passwd.db || true

EXPOSE 25 587

CMD ["/start.sh"]
EOF
        
        success "Created mail server Dockerfile"
    else
        success "Mail server Dockerfile exists"
    fi
    
    # Check for mail server configuration files
    if [ ! -f "services/mail-server/postfix-main.cf" ]; then
        warning "services/mail-server/postfix-main.cf not found, creating a basic one..."
        
        cat > services/mail-server/postfix-main.cf << EOF
# Basic Postfix configuration
myhostname = \$MAIL_HOSTNAME
mydomain = \$MAIL_DOMAIN
myorigin = \$mydomain

inet_interfaces = all
inet_protocols = all

# Mail directories
mail_owner = postfix
mailbox_size_limit = 0
recipient_delimiter = +
append_dot_mydomain = no

# TLS parameters
smtp_use_tls = yes
smtp_tls_security_level = may
smtp_tls_loglevel = 1
smtpd_tls_security_level = may
smtpd_tls_loglevel = 1
smtpd_tls_received_header = yes

# SMTP relay settings (if using external relay)
relayhost = [\$RELAY_HOST]:\$RELAY_PORT
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt

# Recipient restrictions
smtpd_recipient_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination

# Other settings
disable_vrfy_command = yes
smtpd_helo_required = yes
strict_rfc821_envelopes = yes
EOF
        
        success "Created postfix-main.cf"
    else
        success "postfix-main.cf exists"
    fi
    
    # Check for start script
    if [ ! -f "services/mail-server/start.sh" ]; then
        warning "services/mail-server/start.sh not found, creating a basic one..."
        
        cat > services/mail-server/start.sh << EOF
#!/bin/sh
# Mail server startup script

# Update postfix settings with environment variables
postconf -e "myhostname = \$MAIL_HOSTNAME"
postconf -e "mydomain = \$MAIL_DOMAIN"
postconf -e "myorigin = \$MAIL_DOMAIN"

# Configure relayhost if relay settings are provided
if [ -n "\$RELAY_HOST" ] && [ -n "\$RELAY_PORT" ]; then
    echo "Setting up SMTP relay to \$RELAY_HOST:\$RELAY_PORT"
    postconf -e "relayhost = [\$RELAY_HOST]:\$RELAY_PORT"
    
    # Setup SMTP relay with credentials if they exist
    if [ -n "\$RELAY_USER" ] && [ -n "\$RELAY_PASSWORD" ]; then
        echo "[\$RELAY_HOST]:\$RELAY_PORT \$RELAY_USER:\$RELAY_PASSWORD" > /etc/postfix/sasl/sasl_passwd
        postmap /etc/postfix/sasl/sasl_passwd
        postconf -e "smtp_sasl_auth_enable = yes"
        postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl/sasl_passwd"
        postconf -e "smtp_sasl_security_options = noanonymous"
    fi
    
    # Configure TLS
    if [ "\$USE_TLS" = "yes" ]; then
        postconf -e "smtp_use_tls = yes"
        postconf -e "smtp_tls_security_level = may"
        
        if [ "\$TLS_VERIFY" = "yes" ]; then
            postconf -e "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
        else
            postconf -e "smtp_tls_CAfile = "
            postconf -e "smtp_tls_wrappermode = yes"
        fi
    fi
else
    echo "No relay host configured, mail server will deliver directly"
fi

# Start services
echo "Starting mail server..."
postfix start

# Keep container running and tail logs
echo "Mail server started, tailing logs..."
touch /var/log/mail.log
tail -f /var/log/mail.log
EOF
        
        chmod +x services/mail-server/start.sh
        success "Created start.sh"
    else
        success "start.sh exists"
    fi
    
    # Check for mail API Dockerfile
    if [ ! -d "apis/mail-api" ]; then
        warning "apis/mail-api directory not found, creating basic API files..."
        
        mkdir -p apis/mail-api
        
        # Create Dockerfile
        cat > apis/mail-api/Dockerfile << EOF
FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install

# Copy source
COPY . .

# Expose port
EXPOSE 20001

# Start application
CMD ["node", "index.js"]
EOF
        
        # Create package.json
        cat > apis/mail-api/package.json << EOF
{
  "name": "mail-api",
  "version": "1.0.0",
  "description": "Simple mail API for Dinky Server",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "nodemailer": "^6.9.1",
    "cors": "^2.8.5"
  }
}
EOF
        
        # Create index.js
        cat > apis/mail-api/index.js << EOF
const express = require('express');
const nodemailer = require('nodemailer');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 20001;

// Configure allowed hosts
const allowedHosts = process.env.ALLOWED_HOSTS 
  ? process.env.ALLOWED_HOSTS.split(',').map(host => host.trim())
  : ['localhost'];

// Configure CORS
app.use(cors({
  origin: function(origin, callback) {
    if (!origin || allowedHosts.some(host => origin.includes(host))) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  }
}));

// Parse JSON bodies
app.use(express.json());

// Configure mail transporter
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'mail-server',
  port: process.env.SMTP_PORT || 25,
  secure: process.env.MAIL_SECURE === 'true'
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Send email endpoint
app.post('/send', async (req, res) => {
  try {
    const { to, subject, body, from = process.env.DEFAULT_FROM } = req.body;
    
    if (!to || !subject || !body) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    const mailOptions = {
      from,
      to,
      subject,
      text: body,
      html: body.replace(/\\n/g, '<br>')
    };
    
    await transporter.sendMail(mailOptions);
    res.status(200).json({ success: true, message: 'Email sent successfully' });
  } catch (error) {
    console.error('Error sending email:', error);
    res.status(500).json({ error: 'Failed to send email', details: error.message });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(\`Mail API server running on port \${PORT}\`);
});
EOF
        
        success "Created basic mail API files"
    else
        success "Mail API files exist"
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
    
    # Determine Docker Compose command
    determine_docker_compose_cmd
    
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
    
    # Check mail services
    check_mail_services
    
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