#!/bin/bash
# Script to set up automatic security updates

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

echo "Setting up automatic security updates..."

# Install necessary packages
apt update
apt install -y unattended-upgrades apt-listchanges

# Configure unattended-upgrades
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

echo "To update containers with new images, run: docker-compose up -d" >> \$LOG_FILE
echo "=======================================" >> \$LOG_FILE
EOF

# Make the Docker update script executable
chmod +x /usr/local/bin/update-docker-images

# Add the script to weekly cron jobs
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