#!/bin/bash
# Script to set up automatic security updates

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Function to check network connectivity
check_network() {
  echo "Checking network connectivity..."
  if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "Network connectivity confirmed."
    return 0
  else
    echo "Warning: Network connectivity issues detected."
    return 1
  fi
}

# Function to retry commands with network checks
retry_command() {
  local cmd="$1"
  local max_attempts=3
  local attempt=1
  local delay=10
  
  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt/$max_attempts: $cmd"
    if check_network; then
      if eval "$cmd"; then
        return 0
      fi
    fi
    echo "Command failed or network unavailable. Retrying in $delay seconds..."
    sleep $delay
    attempt=$((attempt + 1))
  done
  
  echo "Maximum attempts reached. Continuing with setup..."
  return 1
}

# Setup minimal configuration without package installation
setup_minimal_auto_updates() {
  echo "Setting up minimal auto-update configuration without package installation..."
  
  # Create the update script directory
  mkdir -p /usr/local/bin
  
  # Create a Docker image update script
  cat > /usr/local/bin/update-docker-images << EOF
#!/bin/bash
# Script to update Docker images

# Log file
LOG_FILE="/var/log/docker-updates.log"
DATE=\$(date +"%Y-%m-%d %H:%M:%S")

echo "====== Docker Image Update: \$DATE ======" >> \$LOG_FILE

# Check network connectivity
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
  echo "Network connectivity issues detected. Skipping updates." >> \$LOG_FILE
  exit 0
fi

# Pull new images for all running containers
echo "Pulling updated images for running containers..." >> \$LOG_FILE
for img in \$(docker ps --format '{{.Image}}'); do
    echo "Updating \$img" >> \$LOG_FILE
    docker pull \$img >> \$LOG_FILE 2>&1
done

# Record which services need to be updated (have new images)
echo "Services that need updating:" >> \$LOG_FILE
docker ps --format '{{.Names}} {{.Image}}' | while read container image; do
    local_image_id=\$(docker inspect --format='{{.Image}}' \$container)
    remote_image_id=\$(docker image inspect --format='{{.Id}}' \$image)
    
    if [ "\$local_image_id" != "\$remote_image_id" ]; then
        echo "  \$container (\$image)" >> \$LOG_FILE
    fi
done

echo "To update containers with new images, run: docker compose up -d" >> \$LOG_FILE
echo "=======================================" >> \$LOG_FILE
EOF

  # Make the Docker update script executable
  chmod +x /usr/local/bin/update-docker-images

  # Add the script to weekly cron jobs
  mkdir -p /etc/cron.weekly
  cat > /etc/cron.weekly/docker-image-updates << EOF
#!/bin/bash
/usr/local/bin/update-docker-images
EOF

  # Make the cron job executable
  chmod +x /etc/cron.weekly/docker-image-updates

  # Create a manual update script
  cat > /usr/local/bin/system-update << EOF
#!/bin/bash
# Comprehensive system update script

echo "Starting system update..."

# Check network connectivity
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
  echo "Warning: Network connectivity issues detected."
  echo "Skipping package updates, but will check Docker containers."
else
  echo "Updating package lists..."
  apt update

  echo "Performing system upgrade..."
  apt upgrade -y

  echo "Performing distribution upgrade..."
  apt dist-upgrade -y

  echo "Removing unused packages..."
  apt autoremove -y

  echo "Cleaning up..."
  apt clean
fi

echo "Updating Docker images..."
/usr/local/bin/update-docker-images

echo "System update complete!"
EOF

  # Make the manual update script executable
  chmod +x /usr/local/bin/system-update
  
  echo "Minimal auto-update setup complete."
  echo "When network connectivity is restored, run: sudo apt update && sudo apt install -y unattended-upgrades apt-listchanges"
}

echo "Setting up automatic security updates..."

# Check if packages can be installed
if ! check_network; then
  echo "Network issues detected. Setting up minimal auto-update configuration."
  setup_minimal_auto_updates
  exit 0
fi

# Install necessary packages
if ! retry_command "apt update && apt install -y unattended-upgrades apt-listchanges"; then
  echo "Failed to install packages. Setting up minimal auto-update configuration."
  setup_minimal_auto_updates
  exit 0
fi

# Configure unattended-upgrades
echo "Configuring unattended-upgrades..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
    "\${distro_id}:\${distro_codename}-updates";
};

// Remove unused automatically installed kernel-related packages
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Remove unused automatically installed dependency packages
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Automatically reboot when necessary
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Send email to this address for problems
//Unattended-Upgrade::Mail "root";
//Unattended-Upgrade::MailReport "on-change";

// Always install security updates
Unattended-Upgrade::MinimalSteps "true";

// Print debugging information
Unattended-Upgrade::Debug "false";

// Allow packages to be upgraded that require restart of services
Unattended-Upgrade::InstallOnShutdown "false";

// Split the upgrade into safe and unsafe packages
Unattended-Upgrade::SplitUpgrade "true";

// Package blacklist - packages that should never be automatically upgraded
Unattended-Upgrade::Package-Blacklist {
    // Database servers are often sensitive to upgrades - uncomment if needed
    // "mysql-server";
    // "postgresql";
};
EOF

# Enable unattended upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Create a Docker image update script
cat > /usr/local/bin/update-docker-images << EOF
#!/bin/bash
# Script to update Docker images

# Log file
LOG_FILE="/var/log/docker-updates.log"
DATE=\$(date +"%Y-%m-%d %H:%M:%S")

echo "====== Docker Image Update: \$DATE ======" >> \$LOG_FILE

# Check network connectivity
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
  echo "Network connectivity issues detected. Skipping updates." >> \$LOG_FILE
  exit 0
fi

# Pull new images for all running containers
echo "Pulling updated images for running containers..." >> \$LOG_FILE
for img in \$(docker ps --format '{{.Image}}'); do
    echo "Updating \$img" >> \$LOG_FILE
    docker pull \$img >> \$LOG_FILE 2>&1
done

# Record which services need to be updated (have new images)
echo "Services that need updating:" >> \$LOG_FILE
docker ps --format '{{.Names}} {{.Image}}' | while read container image; do
    local_image_id=\$(docker inspect --format='{{.Image}}' \$container)
    remote_image_id=\$(docker image inspect --format='{{.Id}}' \$image)
    
    if [ "\$local_image_id" != "\$remote_image_id" ]; then
        echo "  \$container (\$image)" >> \$LOG_FILE
    fi
done

echo "To update containers with new images, run: docker compose up -d" >> \$LOG_FILE
echo "=======================================" >> \$LOG_FILE
EOF

# Make the Docker update script executable
chmod +x /usr/local/bin/update-docker-images

# Add the script to weekly cron jobs
mkdir -p /etc/cron.weekly
cat > /etc/cron.weekly/docker-image-updates << EOF
#!/bin/bash
/usr/local/bin/update-docker-images
EOF

# Make the cron job executable
chmod +x /etc/cron.weekly/docker-image-updates

# Create a manual update script
cat > /usr/local/bin/system-update << EOF
#!/bin/bash
# Comprehensive system update script

echo "Starting system update..."

# Check network connectivity
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
  echo "Warning: Network connectivity issues detected."
  echo "Skipping package updates, but will check Docker containers."
else
  echo "Updating package lists..."
  apt update

  echo "Performing system upgrade..."
  apt upgrade -y

  echo "Performing distribution upgrade..."
  apt dist-upgrade -y

  echo "Removing unused packages..."
  apt autoremove -y

  echo "Cleaning up..."
  apt clean
fi

echo "Updating Docker images..."
/usr/local/bin/update-docker-images

echo "System update complete!"
EOF

# Make the manual update script executable
chmod +x /usr/local/bin/system-update

echo "Automatic security updates have been configured."
echo "System will automatically install security updates and clean up unused packages."
echo "Docker images will be updated weekly."
echo "You can manually update your system by running: sudo system-update" 