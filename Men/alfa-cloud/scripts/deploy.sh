#!/bin/bash
echo "Starting deployment..."

# Update package lists
sudo apt update

# Install Node.js and npm
sudo apt install -y nodejs npm

# Install SQLite3
sudo apt install -y sqlite3 libsqlite3-dev

# Install BadVPN
sudo apt install -y badvpn

# Install Stunnel
sudo apt install -y stunnel4

# Setup backend dependencies
cd backend
npm install
cd ..

# Initialize database
node scripts/initialize_db.js

# Configure Stunnel automatically
bash scripts/setup_stunnel.sh

# Configure firewall ports
bash scripts/manage_ports.sh

# Start backend with PM2
pm2 start backend/server.js --name alfa-cloud

echo "Deployment completed successfully!"
