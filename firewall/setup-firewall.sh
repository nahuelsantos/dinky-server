#!/bin/bash

 # Reset firewall to default settings
 sudo ufw default deny incoming
 sudo ufw default allow outgoing

 # Allow SSH from your local network
 sudo ufw allow from 192.168.3.0/24 to any port 22 proto tcp

 # Allow access to Portainer UI from your local network
 sudo ufw allow from 192.168.3.0/24 to any port 9000 proto tcp

 # Allow access to Traefik dashboard from your local network
 sudo ufw allow from 192.168.3.0/24 to any port 8080 proto tcp

 #Enable edge agent communication
 sudo ufw allow from 192.168.3.0/24 to any port 8000 proto tcp

 # Enable the firewall
 sudo ufw enable

 # Show firewall status
 sudo ufw status verbose