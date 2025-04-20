#!/bin/bash
# Script to secure SSH access by enforcing key-based authentication

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Function to backup files before modifying
backup_file() {
  if [ -f "$1" ]; then
    cp "$1" "$1.backup.$(date +%Y%m%d%H%M%S)"
    echo "Backed up $1"
  fi
}

echo "Securing SSH server configuration..."

# Backup SSH config
backup_file /etc/ssh/sshd_config

# Configure SSH to be more secure
echo "Modifying SSH configuration..."
cat > /etc/ssh/sshd_config.d/secure_ssh.conf << EOF
# Secure SSH Configuration

# Disable password authentication
PasswordAuthentication no

# Disable root login
PermitRootLogin no

# Disable empty passwords
PermitEmptyPasswords no

# Use modern protocol
Protocol 2

# Only use strong ciphers and algorithms
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# Limit login attempts
MaxAuthTries 3

# Only allow specified users (uncomment and add user names)
# AllowUsers your_username

# Idle timeout (disconnect after 15 minutes of inactivity)
ClientAliveInterval 300
ClientAliveCountMax 3
EOF

echo "Before we apply these changes, please ensure you have added your SSH public key to authorized_keys."
echo "Otherwise, you could be locked out of your server."
read -p "Have you added your SSH public key to ~/.ssh/authorized_keys? (y/n): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Please add your SSH public key first and then run this script again."
  exit 1
fi

# Create instructional info
echo "Checking for SSH keys..."
if [ ! -d ~/.ssh ]; then
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
fi

if [ ! -f ~/.ssh/authorized_keys ]; then
  touch ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  echo ""
  echo "Your authorized_keys file was not found and has been created."
  echo "Please add your public SSH key to ~/.ssh/authorized_keys before restarting SSH."
  echo ""
  echo "On your local machine, run:"
  echo "  cat ~/.ssh/id_rsa.pub | ssh user@your-server \"cat >> ~/.ssh/authorized_keys\""
  echo ""
  echo "If you don't have an SSH key pair, create one with:"
  echo "  ssh-keygen -t ed25519 -C \"your_email@example.com\""
  echo ""
  exit 1
fi

# Test SSH configuration before applying
echo "Testing new SSH configuration..."
sshd -t
if [ $? -ne 0 ]; then
  echo "Error in SSH configuration. Please check and fix before continuing."
  exit 1
fi

# Restart SSH service
echo "Restarting SSH service to apply changes..."
systemctl restart sshd

echo "SSH configuration has been updated to enforce key-based authentication."
echo "Password authentication is now disabled."
echo "Please keep your private key secure - it's now the only way to access your server." 