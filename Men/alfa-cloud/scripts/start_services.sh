#!/bin/bash

echo "Starting ALFA-CLOUD services..."

# Start backend server
pm2 start backend/server.js --name alfa-cloud-backend

# Start proxy status checker
pm2 start scripts/proxy_status_checker.js --name proxy-checker

# Start BadVPN service
bash scripts/start_badvpn.sh

# Start Stunnel service
bash scripts/start_stunnel.sh

echo "All services started successfully!"