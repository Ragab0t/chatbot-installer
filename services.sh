#!/bin/bash
set -e

echo "[+] Installing Redis and Lighttpd..."

# Update and install packages
sudo apt update
sudo apt install -y redis-server lighttpd tcpdump

# Enable and start Redis
sudo systemctl enable redis-server
sudo systemctl start redis-server
echo "[+] Redis is running on port 6379"

# Harden Redis: disable dangerous commands
REDIS_CONF="/etc/redis/redis.conf"
sudo sed -i 's/^# *rename-command CONFIG .*/rename-command CONFIG ""/' $REDIS_CONF
sudo sed -i 's/^# *rename-command MODULE .*/rename-command MODULE ""/' $REDIS_CONF
sudo sed -i 's/^# *rename-command SAVE .*/rename-command SAVE ""/' $REDIS_CONF
sudo sed -i 's/^# *rename-command BGSAVE .*/rename-command BGSAVE ""/' $REDIS_CONF
sudo sed -i 's/^# *rename-command SHUTDOWN .*/rename-command SHUTDOWN ""/' $REDIS_CONF
sudo sed -i 's/^# *rename-command DEBUG .*/rename-command DEBUG ""/' $REDIS_CONF
sudo systemctl restart redis-server

# Set up Lighttpd with port 8080
echo "[+] Configuring Lighttpd on port 8080..."
sudo mkdir -p /var/www/html-8080
echo "<html><body><h1>Welcome to the HR Chatbot!</h1></body></html>" | sudo tee /var/www/html-8080/index.html

sudo sed -i 's|^server.document-root.*|server.document-root = "/var/www/html-8080"|' /etc/lighttpd/lighttpd.conf
sudo sed -i 's|^server.port.*|server.port = 8080|' /etc/lighttpd/lighttpd.conf

# Validate and restart Lighttpd
sudo lighttpd -tt -f /etc/lighttpd/lighttpd.conf
sudo systemctl enable lighttpd
sudo systemctl restart lighttpd
echo "[+] Lighttpd is running on port 8080"

# Start tcpdump for Redis traffic
echo "[+] Starting tcpdump for Redis (port 6379)..."
sudo nohup tcpdump -i any port 6379 -nn -s 0 -w /var/log/redis_traffic.pcap > /dev/null 2>&1 &

echo "[✓] Services configured and Redis traffic capture started."
