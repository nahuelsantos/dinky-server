#!/bin/bash
# Script to install and configure Logwatch for log monitoring

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

echo "Installing Logwatch..."
apt update
apt install -y logwatch

# Create a directory for custom configuration
mkdir -p /etc/logwatch/conf/services

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
cat > /etc/cron.daily/00logwatch << EOF
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto root@localhost --detail high
EOF

# Make the cron job executable
chmod +x /etc/cron.daily/00logwatch

# Create a script to manually run Logwatch
echo "Creating convenience script for manual Logwatch runs..."
cat > /usr/local/bin/run-logwatch << EOF
#!/bin/bash
# Script to run Logwatch manually

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
cat > /etc/logwatch/conf/services/docker.conf << EOF
# Docker Log Configuration
Title = "Docker Logs"
LogFile = daemon
EOF

echo "Creating Docker service filter..."
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

echo "Logwatch installation and configuration complete."
echo "To run Logwatch manually: sudo run-logwatch"
echo "Daily reports will be emailed to root@localhost"
echo "To change email recipient, edit /etc/cron.daily/00logwatch" 