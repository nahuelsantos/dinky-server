#!/bin/bash
# Master security setup script for Dinky server
# This script installs and configures all security enhancements

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Script location
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR"

# ANSI color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display section headers
section() {
  echo -e "\n${BLUE}============================================================${NC}"
  echo -e "${BLUE}   $1${NC}"
  echo -e "${BLUE}============================================================${NC}\n"
}

# Function to check network connectivity
check_network() {
  section "Checking Network Connectivity"
  echo "Testing network connection..."
  
  if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${GREEN}Network connectivity confirmed.${NC}"
    return 0
  else
    echo -e "${YELLOW}Warning: Network connectivity issues detected.${NC}"
    echo -e "${YELLOW}Some components that require package installation may have limited functionality.${NC}"
    echo -e "${YELLOW}These components can be reinstalled later when network connectivity is restored.${NC}"
    
    read -p "Do you want to continue with potentially limited functionality? (y/n): " continue_offline
    if [[ "$continue_offline" != "y" && "$continue_offline" != "Y" ]]; then
      echo -e "${RED}Setup aborted. Please try again when network connectivity is available.${NC}"
      exit 1
    fi
    
    return 1
  fi
}

# Function to run a component script with proper error handling
run_component() {
  local script=$1
  local description=$2
  local requires_network=$3
  
  if [ ! -f "$script" ]; then
    echo -e "${RED}ERROR: Script $script not found!${NC}"
    return 1
  fi
  
  # Check if component requires network and network is down
  if [ "$requires_network" = "true" ] && [ "$NETWORK_AVAILABLE" = "false" ]; then
    echo -e "${YELLOW}Warning: $description may have limited functionality due to network issues.${NC}"
    echo -e "${YELLOW}You can run it again later with: sudo bash $script${NC}"
  fi
  
  # Make script executable
  chmod +x "$script"
  
  section "$description"
  
  # Run the script
  if bash "$script"; then
    echo -e "\n${GREEN}✓ $description completed successfully${NC}"
    return 0
  else
    echo -e "\n${RED}✗ $description failed with exit code $?${NC}"
    echo -e "${YELLOW}Do you want to continue with the next component? (y/n)${NC}"
    read -r answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
      echo -e "${RED}Aborting master setup script${NC}"
      exit 1
    fi
    return 1
  fi
}

# Welcome message
section "Welcome to Dinky Server Security Setup"
echo "This script will set up comprehensive security measures for your server."
echo "It includes firewall configuration, intrusion detection, secure SSH,"
echo "Docker security, log monitoring, and automatic updates."
echo ""
echo -e "${YELLOW}Note: Some components may require server restarts or manual input${NC}"
echo -e "${YELLOW}Please monitor the process and provide input when requested${NC}"
echo ""
read -p "Press Enter to begin the security setup process..."

# Check network connectivity
check_network
if [ $? -eq 0 ]; then
  NETWORK_AVAILABLE=true
else
  NETWORK_AVAILABLE=false
fi

# Ensure all scripts are executable
chmod +x ./*.sh

# Setup base firewall (doesn't require network)
run_component "./setup-firewall.sh" "Setting up base firewall rules" "false"

# Setup Fail2Ban for intrusion detection and prevention (requires network)
run_component "./setup-fail2ban.sh" "Installing and configuring Fail2Ban" "true"

# Warning for SSH key setup
section "IMPORTANT: SSH Key Setup"
echo -e "${YELLOW}The next script will secure SSH by enforcing key-based authentication${NC}"
echo -e "${YELLOW}This will DISABLE password authentication${NC}"
echo -e "${RED}Make sure you have set up your SSH keys before continuing!${NC}"
echo -e "${RED}If you have not added your SSH public key to ~/.ssh/authorized_keys,${NC}"
echo -e "${RED}YOU WILL BE LOCKED OUT OF YOUR SERVER!${NC}"
echo ""
read -p "Do you have SSH key access set up? (y/n): " ssh_ready
if [[ "$ssh_ready" != "y" && "$ssh_ready" != "Y" ]]; then
  echo "Skipping SSH hardening. Set up your SSH keys and run this script later."
else
  run_component "./setup-ssh-keys.sh" "Securing SSH access" "false"
fi

# Setup Docker security (doesn't require network for basic functionality)
run_component "./setup-docker-security.sh" "Enhancing Docker security" "false"

# Setup log monitoring (requires network for full installation)
run_component "./setup-logwatch.sh" "Setting up log monitoring with Logwatch" "true"

# Setup automated security checks (doesn't require network)
run_component "./setup-cron.sh" "Setting up automated security checks" "false"

# Setup automatic updates (requires network for full functionality)
run_component "./setup-auto-updates.sh" "Configuring automatic security updates" "true"

# Final message
section "Security Setup Complete"
echo -e "${GREEN}Security measures have been installed and configured.${NC}"
echo ""
echo "The following security enhancements are now active:"
echo "  ✓ UFW Firewall with restrictive rules"
if [ "$NETWORK_AVAILABLE" = "true" ]; then
  echo "  ✓ Fail2Ban intrusion prevention"
else
  echo "  ⚠ Fail2Ban may have limited functionality (run setup again when network is available)"
fi
if [[ "$ssh_ready" == "y" || "$ssh_ready" == "Y" ]]; then
  echo "  ✓ SSH hardening with key-based authentication"
else
  echo "  ✗ SSH hardening was skipped (run setup-ssh-keys.sh manually after setting up keys)"
fi
echo "  ✓ Docker security enhancements"
if [ "$NETWORK_AVAILABLE" = "true" ]; then
  echo "  ✓ Logwatch monitoring"
  echo "  ✓ Automatic security updates"
else
  echo "  ⚠ Logwatch may have limited functionality (run setup again when network is available)"
  echo "  ⚠ Automatic updates may have limited functionality (run setup again when network is available)"
fi
echo "  ✓ Automated security checks (runs daily)"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo " - Review the logs in /var/log/security-check.log regularly"
if [ "$NETWORK_AVAILABLE" = "true" ]; then
  echo " - Check for failed intrusion attempts with: sudo fail2ban-client status"
fi
echo " - Run manual security audit: sudo bash firewall/security-check.sh"
echo " - Run system updates: sudo system-update"
if [ "$NETWORK_AVAILABLE" = "false" ]; then
  echo ""
  echo -e "${YELLOW}Network Issues Detected:${NC}"
  echo " - Run the following when network connectivity is restored to complete setup:"
  echo "   sudo apt update && sudo apt install -y fail2ban logwatch"
  echo "   sudo bash firewall/setup-fail2ban.sh"
  echo "   sudo bash firewall/setup-logwatch.sh"
  echo "   sudo bash firewall/setup-auto-updates.sh"
fi
echo ""
echo -e "${GREEN}Your server is now significantly more secure!${NC}" 