#!/bin/bash
#
# Dinky Server - System Testing Script
# This script tests if all components of Dinky Server are functioning correctly

# ANSI color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
FAILURES=0
SUCCESSES=0
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
    ((SUCCESSES++))
}

# Error message function
error() {
    echo -e "${RED}✗ $1${NC}"
    ((FAILURES++))
}

# Warning message function
warning() {
    echo -e "${YELLOW}! $1${NC}"
}

# Check if Docker is running
check_docker() {
    section "Checking Docker service"
    
    if systemctl is-active --quiet docker; then
        success "Docker service is running"
    elif pgrep -x "dockerd" > /dev/null; then
        # Alternative check for macOS or systems not using systemd
        success "Docker service is running"
    else
        error "Docker service is not running"
        echo "Try starting Docker with: sudo systemctl start docker"
        exit 1
    fi
    
    # Determine Docker Compose command
    determine_docker_compose_cmd
}

# Load configuration if it exists
load_configuration() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    else
        # Default values if no config file exists
        SERVER_IP=${SERVER_IP:-192.168.3.2}
        INSTALL_SECURITY="Y"
        INSTALL_CORE="Y"
        INSTALL_MAIL="Y"
        INSTALL_WEBSITES="Y"
        INSTALL_MONITORING="Y"
        return 1
    fi
}

# Test if a container is running
test_container() {
    local container=$1
    local display_name=$2
    
    if docker ps --format '{{.Names}}' | grep -q "^$container$"; then
        success "$display_name is running"
        return 0
    else
        error "$display_name is not running"
        return 1
    fi
}

# Test if a port is open
test_port() {
    local host=$1
    local port=$2
    local service=$3
    
    if command -v nc &> /dev/null; then
        if nc -z -w 2 "$host" "$port"; then
            success "$service port $port is open"
            return 0
        else
            error "$service port $port is closed"
            return 1
        fi
    else
        if timeout 2 bash -c "</dev/tcp/$host/$port"; then
            success "$service port $port is open"
            return 0
        else
            error "$service port $port is closed"
            return 1
        fi
    fi
}

# Test HTTP endpoint
test_http() {
    local url=$1
    local service=$2
    local expected_status=${3:-200}
    local acceptable_statuses=${4:-"$expected_status"}
    
    # Use curl to test HTTP endpoint with timeout
    if command -v curl &> /dev/null; then
        local status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url")
        
        # Check if status is in the list of acceptable statuses
        if [[ "$acceptable_statuses" == *"$status"* ]]; then
            success "$service endpoint is responsive (HTTP $status)"
            return 0
        else
            error "$service endpoint returned HTTP $status (expected one of: $acceptable_statuses)"
            return 1
        fi
    else
        warning "curl not installed, skipping HTTP test for $service"
        return 0
    fi
}

# Test core infrastructure
test_core() {
    header "Testing Core Infrastructure"
    
    # Test Traefik
    section "Testing Traefik"
    test_container "traefik" "Traefik"
    test_port "$SERVER_IP" 20000 "Traefik dashboard"
    test_port "127.0.0.1" 80 "Traefik HTTP"
    test_http "http://$SERVER_IP:20000/dashboard/" "Traefik dashboard" 200 "200 301 302"
    
    # Test Portainer
    section "Testing Portainer"
    test_container "portainer" "Portainer"
    test_port "$SERVER_IP" 9000 "Portainer UI"
    test_http "http://$SERVER_IP:9000" "Portainer UI" 200 "200 301 302"
    
    # Test Pi-hole
    section "Testing Pi-hole"
    test_container "pihole" "Pi-hole"
    test_port "$SERVER_IP" 53 "Pi-hole DNS (TCP)"
    test_port "$SERVER_IP" 19999 "Pi-hole admin interface"
    test_http "http://$SERVER_IP:19999/admin/" "Pi-hole admin interface" 200 "200 301 302 403"
    
    # Test Cloudflared
    section "Testing Cloudflared"
    test_container "cloudflared" "Cloudflared"
    
    echo ""
    if [ $FAILURES -eq 0 ]; then
        success "All core infrastructure tests passed"
    else
        error "$FAILURES core infrastructure tests failed"
    fi
}

# Test mail services
test_mail() {
    header "Testing Mail Services"
    
    # Test Mail Server
    section "Testing Mail Server"
    test_container "mail-server" "Mail Server"
    test_port "127.0.0.1" 25 "SMTP"
    test_port "127.0.0.1" 587 "SMTP submission"
    
    # Test direct SMTP connection to the mail server
    section "Testing Mail Server SMTP connection"
    if docker exec -i mail-server sh -c '(echo "EHLO test" && sleep 1 && echo "QUIT") > /dev/tcp/localhost/25' 2>/dev/null; then
        success "SMTP server responds to EHLO command"
    elif docker exec -i mail-server sh -c 'command -v nc && (echo "EHLO test"; sleep 1; echo "QUIT") | nc localhost 25'; then
        success "SMTP server responds to EHLO command"
    else
        warning "Could not test SMTP commands directly - server might still be working"
    fi
    
    # Test Mail API
    section "Testing Mail API"
    test_container "mail-api" "Mail API"
    
    # Test Mail API health endpoint
    section "Testing Mail API health endpoint"
    if docker exec -i mail-api sh -c 'wget -q -O- http://localhost:20001/health' 2>/dev/null; then
        success "Mail API health endpoint is responding"
    elif docker exec -i mail-api sh -c 'curl -s http://localhost:20001/health'; then
        success "Mail API health endpoint is responding"
    else
        error "Mail API health endpoint is not responding"
    fi
    
    # Attempt to send a test email (just test functionality, not actual delivery)
    section "Testing Mail API send endpoint"
    if docker exec -i mail-api sh -c 'curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "{\"to\":\"test@example.com\",\"subject\":\"Test\",\"body\":\"Test\"}" http://localhost:20001/send' 2>/dev/null | grep -q "200"; then
        success "Mail API send endpoint is functioning"
    else
        error "Mail API send endpoint is not functioning properly"
        echo "To debug:"
        echo "- Check mail-api logs: docker logs mail-api"
        echo "- Check mail-server logs: docker logs mail-server"
    fi
    
    # Check /etc/hosts configuration
    section "Testing Mail API DNS configuration"
    if grep -q "mail-api.local" /etc/hosts; then
        success "mail-api.local is properly configured in /etc/hosts"
    else
        error "mail-api.local is not configured in /etc/hosts"
        echo "Add this line to /etc/hosts: 127.0.0.1 mail-api.local"
    fi
    
    echo ""
    if [ $FAILURES -eq 0 ]; then
        success "All mail service tests passed"
    else
        error "$FAILURES mail service tests failed"
        echo -e "\n${YELLOW}Mail Service Troubleshooting:${NC}"
        echo "1. Check mail-server logs: docker logs mail-server"
        echo "2. Check mail-api logs: docker logs mail-api" 
        echo "3. To send a test email: make send-test-email EMAIL=your@email.com"
        echo "4. Make sure mail-api.local is in /etc/hosts: 127.0.0.1 mail-api.local"
    fi
}

# Test websites
test_websites() {
    header "Testing Websites"
    
    # Test nahuelsantos.com
    section "Testing nahuelsantos.com"
    test_container "cv" "nahuelsantos.com"
    
    # Test loopingbyte.com
    section "Testing loopingbyte.com"
    test_container "looping-byte" "loopingbyte.com"
    
    echo ""
    if [ $FAILURES -eq 0 ]; then
        success "All website tests passed"
    else
        error "$FAILURES website tests failed"
    fi
}

# Test monitoring stack
test_monitoring() {
    header "Testing Monitoring Stack"
    
    # Test all monitoring containers
    section "Testing monitoring containers"
    local monitoring_services=(
        "prometheus:Prometheus"
        "loki:Loki"
        "promtail:Promtail"
        "tempo:Tempo"
        "pyroscope:Pyroscope"
        "grafana:Grafana"
        "otel-collector:OpenTelemetry Collector"
    )
    
    for service in "${monitoring_services[@]}"; do
        IFS=':' read -r container display_name <<< "$service"
        test_container "$container" "$display_name"
    done
    
    # Test specific monitoring ports
    section "Testing monitoring ports"
    test_port "$SERVER_IP" 9090 "Prometheus"
    test_port "$SERVER_IP" 3100 "Loki"
    test_port "$SERVER_IP" 3200 "Tempo"
    test_port "$SERVER_IP" 4040 "Pyroscope"
    test_port "$SERVER_IP" 3000 "Grafana"
    
    # Test specific HTTP endpoints
    section "Testing monitoring HTTP endpoints"
    test_http "http://$SERVER_IP:9090" "Prometheus UI"
    test_http "http://$SERVER_IP:3000" "Grafana UI"
    
    echo ""
    if [ $FAILURES -eq 0 ]; then
        success "All monitoring tests passed"
    else
        error "$FAILURES monitoring tests failed"
    fi
}

# Test security components
test_security() {
    header "Testing Security Components"
    
    # Check if UFW is active
    section "Testing firewall"
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        success "UFW firewall is active"
    else
        error "UFW firewall is not active"
    fi
    
    # Check if fail2ban is running
    section "Testing fail2ban"
    if command -v fail2ban-client &> /dev/null && systemctl is-active --quiet fail2ban; then
        success "fail2ban is active"
        # Check for fail2ban jails
        local jails=$(fail2ban-client status | grep "Jail list" | sed 's/^.*Jail list:\s\+//' | sed 's/,//g')
        if [ -n "$jails" ]; then
            success "fail2ban jails are configured: $jails"
        else
            warning "No fail2ban jails are configured"
        fi
    else
        error "fail2ban is not active"
    fi
    
    # Check SSH configuration
    section "Testing SSH configuration"
    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
        success "SSH password authentication is disabled (key-based auth only)"
    else
        warning "SSH password authentication is enabled"
    fi
    
    echo ""
    if [ $FAILURES -eq 0 ]; then
        success "All security tests passed"
    else
        error "$FAILURES security tests failed"
    fi
}

# Main function
main() {
    header "Dinky Server System Test"
    echo "Testing all components of your Dinky Server installation"
    echo ""
    
    # Initialize counters
    FAILURES=0
    SUCCESSES=0
    
    # Load configuration
    load_configuration
    
    # Check if Docker is running
    check_docker
    
    # Test components based on what's installed
    if [[ "$INSTALL_SECURITY" == "Y" || "$INSTALL_SECURITY" == "y" ]]; then
        test_security
    fi
    
    if [[ "$INSTALL_CORE" == "Y" || "$INSTALL_CORE" == "y" ]]; then
        test_core
    fi
    
    if [[ "$INSTALL_MAIL" == "Y" || "$INSTALL_MAIL" == "y" ]]; then
        test_mail
    fi
    
    if [[ "$INSTALL_WEBSITES" == "Y" || "$INSTALL_WEBSITES" == "y" ]]; then
        test_websites
    fi
    
    if [[ "$INSTALL_MONITORING" == "Y" || "$INSTALL_MONITORING" == "y" ]]; then
        test_monitoring
    fi
    
    # Display summary
    header "Test Summary"
    echo "Tests completed with:"
    echo "- $SUCCESSES success(es)"
    echo "- $FAILURES failure(s)"
    
    if [ $FAILURES -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed! Your Dinky Server is running correctly.${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed. Please check the issues above.${NC}"
        exit 1
    fi
}

# Run the main function
main 