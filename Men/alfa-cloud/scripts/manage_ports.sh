#!/bin/bash

echo "Setting up firewall rules..."

# Open ports for BadVPN
sudo ufw allow 7300/tcp

# Open ports for Stunnel
sudo ufw allow 443/tcp

# Open ports for Proxy Modes
sudo ufw allow 8080/tcp
sudo ufw allow 3128/tcp

# Reload firewall rules
sudo ufw reload

echo "Ports configured successfully!"