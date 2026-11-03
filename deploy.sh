#!/bin/bash
# ==============================================================================
# ARMSS Creator Monetization Platform - Production Deployment Script for Ubuntu
# ==============================================================================

set -e

echo "==========================================================="
echo " Starting ARMSS Platform Deployment on Ubuntu Server..."
echo "==========================================================="

# 1. Verify Docker and Docker Compose
if ! command -v docker &> /dev/null; then
    echo "[!] Docker not found. Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    echo "[✓] Docker installed successfully."
fi

# 2. Ensure Storage & Media Directories Exist on Host
echo "[*] Creating persistent storage directories..."
mkdir -p backend/data/masters
mkdir -p backend/data/hls
mkdir -p backend/data/thumbnails
mkdir -p backend/data/logos
mkdir -p backend/logs

# Set permissive permissions for container writes
chmod -R 775 backend/data backend/logs

# 3. Handle Production Environment Configuration
if [ ! -f .env ]; then
    if [ -f .env.production.example ]; then
        echo "[*] Initializing .env from .env.production.example..."
        cp .env.production.example .env
        echo "[!] Please review .env and update production passwords."
    fi
fi

# 4. Build and Launch Containers
echo "[*] Building and starting containers with docker compose..."
docker compose down --remove-orphans || true
docker compose up -d --build

# 5. Wait for Services Health Check
echo "[*] Waiting for MySQL and Backend API to initialize..."
sleep 10

# 6. Verify Deployment Health
echo "[*] Testing API health status..."
HEALTH_RESPONSE=$(curl -s http://127.0.0.1:8085/api/health || echo "failed")
echo "Health Endpoint: $HEALTH_RESPONSE"

echo "==========================================================="
echo " [✓] ARMSS Platform Deployment Complete!"
echo " Web Application:  http://<server-ip> (Port 80/8080)"
echo " Backend API:      http://<server-ip>:8085/api"
echo " MySQL Internal:   127.0.0.1:3306"
echo "==========================================================="

