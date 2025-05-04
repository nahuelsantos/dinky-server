#!/bin/bash
#
# Dinky Server - Comprehensive Testing Script
# This script performs thorough tests on all Dinky Server components

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
FAILURES=0
SUCCESSES=0

# Help message
show_help() {
  echo "Dinky Server Comprehensive Testing Script"
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --help             Show this help message"
  echo "  --all              Test all components (default)"
  echo "  --core             Test only core infrastructure"
  echo "  --mail             Test only mail services"
  echo "  --monitoring       Test only monitoring stack"
  echo "  --security         Test only security components"
  echo "  --skip-external    Skip tests requiring external services (Gmail, etc.)"
  echo "  --verbose          Show more detailed output"
  echo ""
  echo "Example: $0 --mail --verbose"
}

# Parse command line arguments
VERBOSE=false
TEST_CORE=false
TEST_MAIL=false
TEST_MONITORING=false
TEST_SECURITY=false
SKIP_EXTERNAL=false

# If no arguments, test all
if [ $# -eq 0 ]; then
  TEST_CORE=true
  TEST_MAIL=true
  TEST_MONITORING=true
  TEST_SECURITY=true
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      show_help
      exit 0
      ;;
    --all)
      TEST_CORE=true
      TEST_MAIL=true
      TEST_MONITORING=true
      TEST_SECURITY=true
      shift
      ;;
    --core)
      TEST_CORE=true
      shift
      ;;
    --mail)
      TEST_MAIL=true
      shift
      ;;
    --monitoring)
      TEST_MONITORING=true
      shift
      ;;
    --security)
      TEST_SECURITY=true
      shift
      ;;
    --skip-external)
      SKIP_EXTERNAL=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

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

# Verbose output function
verbose() {
  if [ "$VERBOSE" = true ]; then
    echo -e "  $1"
  fi
}

# Check if Docker is running
check_docker() {
  section "Checking Docker service"
  
  if systemctl is-active --quiet docker || pgrep -x "dockerd" > /dev/null; then
    success "Docker service is running"
  else
    error "Docker service is not running"
    echo "Try starting Docker with: sudo systemctl start docker"
    exit 1
  fi
}

# Test if a container is running
test_container() {
  local container=$1
  local display_name=$2
  
  if docker ps --format '{{.Names}}' | grep -q "^$container$"; then
    success "$display_name container is running"
    return 0
  else
    error "$display_name container is not running"
    return 1
  fi
}

# Test if a port is open
test_port() {
  local host=$1
  local port=$2
  local service=$3
  
  verbose "Testing $service on $host:$port"
  
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
  
  verbose "Testing HTTP endpoint: $url"
  
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
test_core_infrastructure() {
  header "Testing Core Infrastructure"
  
  # Determine IP address
  SERVER_IP=$(hostname -I | awk '{print $1}')
  verbose "Using server IP: $SERVER_IP"
  
  # Test Traefik
  section "Testing Traefik"
  test_container "traefik" "Traefik"
  test_port "$SERVER_IP" 80 "Traefik HTTP"
  test_port "127.0.0.1" 20000 "Traefik dashboard"
  test_http "http://127.0.0.1:20000/dashboard/" "Traefik dashboard" 200 "200 301 302"
  
  # Test Portainer
  section "Testing Portainer"
  test_container "portainer" "Portainer"
  test_port "127.0.0.1" 9000 "Portainer UI"
  test_http "http://127.0.0.1:9000" "Portainer UI" 200 "200 301 302"
  
  # Test Pi-hole
  section "Testing Pi-hole"
  test_container "pihole" "Pi-hole"
  test_port "$SERVER_IP" 53 "Pi-hole DNS (TCP)"
  test_port "$SERVER_IP" 19999 "Pi-hole admin interface"
  test_http "http://127.0.0.1:19999/admin/" "Pi-hole admin interface" 200 "200 301 302 403"
  
  # Test Cloudflared
  section "Testing Cloudflared"
  test_container "cloudflared" "Cloudflared"
  
  if [ $FAILURES -eq 0 ]; then
    success "All core infrastructure tests passed"
  else
    error "$FAILURES core infrastructure tests failed"
  fi
}

# Test mail services
test_mail_services() {
  header "Testing Mail Services"
  
  # Test mail-server container
  section "Testing mail-server"
  test_container "mail-server" "Mail Server"
  test_port "127.0.0.1" 25 "SMTP"
  test_port "127.0.0.1" 587 "SMTP submission"
  
  # Test mail-api container
  section "Testing mail-api"
  test_container "mail-api" "Mail API"
  test_port "127.0.0.1" 20001 "Mail API"
  test_http "http://127.0.0.1:20001/health" "Mail API health endpoint"
  
  # Check mail-server configuration
  section "Checking mail-server configuration"
  if docker exec -it mail-server sh -c "postconf -n" > /dev/null; then
    success "Postfix configuration is valid"
  else
    error "Postfix configuration is invalid"
  fi
  
  # Check SMTP relay configuration
  if [ "$SKIP_EXTERNAL" != true ]; then
    section "Testing SMTP relay connection"
    SMTP_RELAY_HOST=$(docker exec -it mail-server sh -c "postconf -h relayhost" | tr -d '[]' | cut -d':' -f1)
    SMTP_RELAY_PORT=$(docker exec -it mail-server sh -c "postconf -h relayhost" | tr -d '[]' | cut -d':' -f2)
    
    if [ -z "$SMTP_RELAY_HOST" ] || [ "$SMTP_RELAY_HOST" = "relayhost" ]; then
      warning "No SMTP relay configured"
    else
      verbose "Testing connection to $SMTP_RELAY_HOST:$SMTP_RELAY_PORT"
      if docker exec -it mail-server sh -c "nc -z -w 5 $SMTP_RELAY_HOST $SMTP_RELAY_PORT" 2>/dev/null; then
        success "Can connect to SMTP relay at $SMTP_RELAY_HOST:$SMTP_RELAY_PORT"
      else
        error "Cannot connect to SMTP relay at $SMTP_RELAY_HOST:$SMTP_RELAY_PORT"
      fi
    fi
  fi
  
  # Check internal network connectivity
  section "Testing internal network connectivity"
  if docker exec -it mail-api sh -c "ping -c 1 mail-server" > /dev/null 2>&1; then
    success "mail-api can reach mail-server"
  else
    error "mail-api cannot reach mail-server"
  fi
  
  if [ $FAILURES -eq 0 ]; then
    success "All mail service tests passed"
  else
    error "$FAILURES mail service tests failed"
    echo -e "\n${YELLOW}Mail Service Troubleshooting:${NC}"
    echo "1. Check mail-server logs: docker logs mail-server"
    echo "2. Check mail-api logs: docker logs mail-api" 
    echo "3. To send a test email: sudo ./scripts/send-test-email.sh your@email.com"
    echo "4. Check if mail-api.local is in /etc/hosts file"
  fi
}

# Test monitoring stack
test_monitoring_stack() {
  header "Testing Monitoring Stack"
  
  # Test monitoring services
  local monitoring_services=(
    "prometheus:Prometheus"
    "loki:Loki"
    "promtail:Promtail"
    "tempo:Tempo"
    "pyroscope:Pyroscope"
    "grafana:Grafana"
    "otel-collector:OpenTelemetry Collector"
  )
  
  section "Testing monitoring containers"
  for service in "${monitoring_services[@]}"; do
    IFS=':' read -r container display_name <<< "$service"
    test_container "$container" "$display_name"
  done
  
  # Test monitoring ports
  section "Testing monitoring ports"
  SERVER_IP=$(hostname -I | awk '{print $1}')
  test_port "127.0.0.1" 9090 "Prometheus"
  test_port "127.0.0.1" 3100 "Loki"
  test_port "127.0.0.1" 3200 "Tempo"
  test_port "127.0.0.1" 4040 "Pyroscope"
  test_port "127.0.0.1" 3000 "Grafana"
  
  # Test monitoring HTTP endpoints
  section "Testing monitoring HTTP endpoints"
  test_http "http://127.0.0.1:9090" "Prometheus UI"
  test_http "http://127.0.0.1:3000" "Grafana UI"
  
  if [ $FAILURES -eq 0 ]; then
    success "All monitoring stack tests passed"
  else
    error "$FAILURES monitoring stack tests failed"
  fi
}

# Test security components
test_security_components() {
  header "Testing Security Components"
  
  # Check if UFW is active
  section "Testing firewall"
  if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    success "UFW firewall is active"
    
    # Check important firewall rules
    ufw_rules=$(sudo ufw status | grep -E "(22|80|443)/tcp" | wc -l)
    if [ "$ufw_rules" -ge 3 ]; then
      success "Essential firewall rules are configured"
    else
      warning "Some essential firewall rules might be missing"
    fi
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
  
  if [ $FAILURES -eq 0 ]; then
    success "All security tests passed"
  else
    error "$FAILURES security tests failed"
  fi
}

# Main function
main() {
  # Check if script is running as root
  if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run with sudo or as root"
    echo "Please run: sudo $0"
    exit 1
  fi
  
  header "Dinky Server Comprehensive Test"
  check_docker
  
  # Run selected tests
  if [ "$TEST_CORE" = true ]; then
    test_core_infrastructure
  fi
  
  if [ "$TEST_MAIL" = true ]; then
    test_mail_services
  fi
  
  if [ "$TEST_MONITORING" = true ]; then
    test_monitoring_stack
  fi
  
  if [ "$TEST_SECURITY" = true ]; then
    test_security_components
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
    echo -e "For more detailed troubleshooting, run with the --verbose flag."
    exit 1
  fi
}

# Run the main function
main 