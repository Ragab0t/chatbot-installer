#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error

# Check if DNS name is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <DNS_NAME>"
    exit 1
fi

DNSNAME=$1
echo "[+] Setting up VM for DNS: $DNSNAME"

# Remove any old versions of Docker
echo "[+] Removing old Docker versions..."
sudo apt remove -y docker.io podman-docker || true

# Update system and install dependencies
echo "[+] Updating and installing dependencies..."
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# Add Docker’s official GPG key
echo "[+] Adding Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "[+] Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
echo "[+] Installing Docker..."
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Verify installation
echo "[+] Docker version:"
docker --version

# Add current user to docker group
sudo usermod -aG docker $USER

# Activate docker group (this works only in new sessions normally)
newgrp docker << EOF
echo "[+] Newgrp docker entered."
EOF

# Create log directory
echo "[+] Creating /var/log/chatbot..."
sudo mkdir -p /var/log/chatbot
sudo chown "$USER":"$USER" /var/log/chatbot

# Prepare SSL cert directory and generate self-signed certificate
echo "[+] Generating self-signed SSL certificates for $DNSNAME..."
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/selfsigned.key \
  -out /etc/nginx/ssl/selfsigned.crt \
  -subj "/C=US/ST=State/L=City/O=Org/CN=$DNSNAME"

# Create systemd service file
echo "[+] Creating chatbot.service..."
cat <<EOF | sudo tee /etc/systemd/system/chatbot.service > /dev/null
[Unit]
Description=Chatbot Docker Container
After=network.target docker.service
Requires=docker.service

[Service]
Restart=always
RestartSec=5
ExecStartPre=-/usr/bin/docker pull ragab0t/chatbot:latest

ExecStart=/usr/bin/docker run --name chatbot \
  -p 80:80 -p 443:443 -p 8501:8501 \
  -v /var/log/chatbot:/app/logs \
  -v /etc/letsencrypt:/etc/letsencrypt \
  -v /etc/nginx/ssl/:/etc/nginx/ssl \
  -e LOG_DIR=/app/logs \
  -e BACKEND=uat \
  -e DNSNAME=$DNSNAME \
  -e CERT_MODE=selfsigned \
  ragab0t/chatbot:latest

ExecStop=/usr/bin/docker stop chatbot
ExecStopPost=/usr/bin/docker rm chatbot

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable/start service
echo "[+] Enabling and starting chatbot.service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable chatbot.service
sudo systemctl start chatbot.service

# Confirm service status
echo "[+] Checking service status:"
sudo systemctl status chatbot.service

