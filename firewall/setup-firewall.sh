#!/bin/bash

# Reset firewall to default settings
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH from your local network only
sudo ufw allow from 192.168.3.0/24 to any port 22 proto tcp

# Allow access to Portainer UI from your local network only
sudo ufw allow from 192.168.3.0/24 to any port 9000 proto tcp

# Allow access to Traefik dashboard from your local network only
sudo ufw allow from 192.168.3.0/24 to any port 8080 proto tcp

# Enable edge agent communication from local network only
sudo ufw allow from 192.168.3.0/24 to any port 8000 proto tcp

# Allow Pi-hole DNS service (both TCP and UDP) from local network
sudo ufw allow from 192.168.3.0/24 to any port 53 proto tcp
sudo ufw allow from 192.168.3.0/24 to any port 53 proto udp

# Allow Pi-hole web interface from local network only
sudo ufw allow from 192.168.3.0/24 to any port 8081 proto tcp

# Allow HTTP(S) for Traefik to handle external requests
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Rate limit SSH connections to prevent brute force attacks
sudo ufw limit ssh

# Enable the firewall
sudo ufw enable

# Show firewall status
sudo ufw status verbose