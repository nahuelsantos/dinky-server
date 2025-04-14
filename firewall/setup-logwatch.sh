#!/bin/bash
# Script to install and configure Logwatch for log monitoring

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Function to retry commands with network connectivity checks
retry_with_network_check() {
  local max_attempts=5
  local attempt=1
  local delay=10
  local command="$@"
  
  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt of $max_attempts: $command"
    
    # Check network connectivity to a reliable server
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
      echo "Network connectivity confirmed."
      
      # Execute the command
      if eval "$command"; then
        return 0
      else
        echo "Command failed. Retrying in $delay seconds..."
      fi
    else
      echo "Network connectivity issue detected. Retrying in $delay seconds..."
    fi
    
    sleep $delay
    attempt=$((attempt + 1))
  done
  
  echo "Maximum attempts reached. Moving on with limited functionality."
  return 1
}

# Create minimal Logwatch configuration without installation
setup_minimal_logwatch() {
  echo "Setting up minimal Logwatch configuration without package installation..."
  
  # Create required directories
  mkdir -p /etc/logwatch/conf
  mkdir -p /etc/logwatch/conf/services
  mkdir -p /etc/logwatch/conf/logfiles
  mkdir -p /etc/logwatch/scripts/services
  mkdir -p /var/cache/logwatch
  
  # Set up basic configuration
  cat > /etc/logwatch/conf/logwatch.conf << EOF
# Logwatch Configuration - Minimal Setup

# Output format (mail, stdout, or file)
Output = stdout
# Output format detail level
Detail = High
# Range (Yesterday, Today, All)
Range = Yesterday
# Format of report (text, html)
Format = text
# Whether to display the help text
Help = No
EOF

  # Create a simple wrapper script
  cat > /usr/local/bin/run-logwatch << EOF
#!/bin/bash
echo "Minimal Logwatch setup. Full functionality requires package installation."
echo "Run 'apt install -y logwatch' when network connectivity is restored."
cat /etc/logwatch/conf/logwatch.conf
echo "System log summary:"
grep -E 'error|warning|fail' /var/log/syslog | tail -20
EOF

  chmod +x /usr/local/bin/run-logwatch

  echo "Minimal Logwatch setup complete. To install full functionality later, run:"
  echo "  sudo apt update && sudo apt install -y logwatch"
}

echo "Installing Logwatch..."
if ! retry_with_network_check "apt update && apt install -y logwatch"; then
  echo "Network issues detected. Setting up minimal Logwatch configuration."
  setup_minimal_logwatch
else
  echo "Logwatch installation successful."
fi

# Create directories in case they weren't created during installation
mkdir -p /etc/logwatch/conf/services
mkdir -p /etc/logwatch/scripts/services

# Configure Logwatch
echo "Configuring Logwatch..."
cat > /etc/logwatch/conf/logwatch.conf << EOF
# Logwatch Configuration

# Output format (mail, stdout, or file)
Output = stdout
# Output format detail level (Low, Med, High, or a number)
Detail = High
# What service(s) to include
Service = All
# Which logfiles to include
LogFile = All
# Range (Yesterday, Today, All)
Range = Yesterday
# Format of report (text, html)
Format = text
# Whether to display the help text
Help = No
# Temp directory
TmpDir = /tmp
# Where to save the report if Output = file
# Filename = /tmp/logwatch.txt
# Whether to send the report by mail
# MailTo = root@localhost
# Subject of email
# MailFrom = Logwatch
# Subject of email
# Subject = Logwatch Report for \$HOSTNAME
EOF

# Create daily cron job to run Logwatch
echo "Setting up Logwatch daily run via cron..."
mkdir -p /etc/cron.daily
cat > /etc/cron.daily/00logwatch << EOF
#!/bin/bash
if command -v logwatch >/dev/null 2>&1; then
  /usr/sbin/logwatch --output mail --mailto root@localhost --detail high
else
  echo "Logwatch not installed. Please install with: apt install -y logwatch"
fi
EOF

# Make the cron job executable
chmod +x /etc/cron.daily/00logwatch

# Create a script to manually run Logwatch
echo "Creating convenience script for manual Logwatch runs..."
cat > /usr/local/bin/run-logwatch << EOF
#!/bin/bash
# Script to run Logwatch manually

if ! command -v logwatch >/dev/null 2>&1; then
  echo "Logwatch not installed. Please install with: apt install -y logwatch"
  echo "Running minimal log check instead:"
  grep -E 'error|warning|fail' /var/log/syslog | tail -20
  exit 1
fi

# Default values
DETAIL="High"
RANGE="Yesterday"
OUTPUT="stdout"
SERVICE="All"

# Parse command-line options
while getopts "d:r:o:s:h" opt; do
  case \$opt in
    d) DETAIL="\$OPTARG" ;;
    r) RANGE="\$OPTARG" ;;
    o) OUTPUT="\$OPTARG" ;;
    s) SERVICE="\$OPTARG" ;;
    h)
      echo "Usage: \$0 [-d detail] [-r range] [-o output] [-s service]"
      echo "  -d detail  : Detail level (Low, Med, High)"
      echo "  -r range   : Time range (Today, Yesterday, All)"
      echo "  -o output  : Output type (stdout, mail, file)"
      echo "  -s service : Service to analyze (All, or specific service)"
      echo "Example: \$0 -d High -r Yesterday -s sshd"
      exit 0
      ;;
    \?) echo "Invalid option: -\$OPTARG" >&2; exit 1 ;;
  esac
done

# Run Logwatch with specified options
/usr/sbin/logwatch --detail \$DETAIL --range \$RANGE --output \$OUTPUT --service \$SERVICE
EOF

# Make the manual run script executable
chmod +x /usr/local/bin/run-logwatch

echo "Creating Docker service definition for Logwatch..."
mkdir -p /etc/logwatch/conf/services
cat > /etc/logwatch/conf/services/docker.conf << EOF
# Docker Log Configuration
Title = "Docker Logs"
LogFile = daemon
EOF

echo "Creating Docker service filter..."
mkdir -p /etc/logwatch/scripts/services
cat > /etc/logwatch/scripts/services/docker << EOF
#!/usr/bin/perl -w
# Process Docker logs

use strict;

my \$Detail = \$ENV{'LOGWATCH_DETAIL_LEVEL'} || 0;
my %Containers;
my %Actions;

while (my \$ThisLine = <STDIN>) {
   if (\$ThisLine =~ /docker/) {
      if (\$ThisLine =~ /container (\w+).*image=([^ ]+).*name=([^ ]+)/) {
         my \$id = \$1;
         my \$image = \$2;
         my \$name = \$3;
         
         if (\$ThisLine =~ /(created|started|stopped|died|destroyed)/) {
            my \$action = \$1;
            \$Actions{\$action}++;
            if (\$Detail >= 5) {
               \$Containers{\$name}{\$action}++;
            }
         }
      }
   }
}

if (keys %Actions) {
   print "Docker Container Activity:\n";
   foreach my \$action (sort keys %Actions) {
      print "   \$action: \$Actions{\$action} time" . (\$Actions{\$action} == 1 ? "" : "s") . "\n";
   }
   
   if (\$Detail >= 5 and keys %Containers) {
      print "\nDetailed Container Activity:\n";
      foreach my \$container (sort keys %Containers) {
         print "   \$container:\n";
         foreach my \$action (sort keys %{\$Containers{\$container}}) {
            print "      \$action: \$Containers{\$container}{\$action} time" . 
                 (\$Containers{\$container}{\$action} == 1 ? "" : "s") . "\n";
         }
      }
   }
}
EOF

# Make the Docker service script executable
chmod +x /etc/logwatch/scripts/services/docker

echo "Logwatch configuration complete."
if command -v logwatch >/dev/null 2>&1; then
  echo "Full Logwatch installation is available."
else
  echo "Minimal Logwatch configuration is in place."
  echo "Install the full package later with: sudo apt update && sudo apt install -y logwatch"
fi
echo "To run Logwatch manually: sudo run-logwatch"
echo "Daily reports will be emailed to root@localhost if mail is configured"
echo "To change email recipient, edit /etc/cron.daily/00logwatch" 