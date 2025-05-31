#!/bin/bash
# Security check script for Dinky server
# This script performs basic security checks and logs potential issues

LOG_FILE="/var/log/security-check.log"
HOSTNAME=$(hostname)
DATE=$(date +"%Y-%m-%d %H:%M:%S")

echo "=============== Security Check: $DATE ===============" | sudo tee -a $LOG_FILE

# Check UFW status
echo "Firewall Status:" | sudo tee -a $LOG_FILE
sudo ufw status | sudo tee -a $LOG_FILE

# Check failed SSH login attempts
echo -e "\nFailed SSH login attempts in the last 24 hours:" | sudo tee -a $LOG_FILE
sudo grep "Failed password" /var/log/auth.log | grep sshd | sudo tee -a $LOG_FILE

# Check for unusual open ports
echo -e "\nUnusual open ports:" | sudo tee -a $LOG_FILE
sudo netstat -tulpn | grep LISTEN | grep -v -E '(127.0.0.1|::1)' | sudo tee -a $LOG_FILE

# Check docker container status
echo -e "\nDocker container status:" | sudo tee -a $LOG_FILE
docker ps -a | sudo tee -a $LOG_FILE

# Check disk usage
echo -e "\nDisk usage:" | sudo tee -a $LOG_FILE
df -h | sudo tee -a $LOG_FILE

# Check system updates
echo -e "\nAvailable system updates:" | sudo tee -a $LOG_FILE
sudo apt update >/dev/null 2>&1
sudo apt list --upgradable | sudo tee -a $LOG_FILE

echo -e "\nSecurity check complete. Check $LOG_FILE for full report."

# Make script executable upon creation
chmod +x $0 