#!/bin/bash
set -e

echo "[+] Removing previous Redis installation (if any)..."
sudo systemctl stop redis-server || true
sudo apt purge -y redis-server || true
sudo rm -f /etc/redis/redis.conf
sudo rm -rf /var/lib/redis
sudo apt autoremove -y

echo "[+] Installing Redis, Lighttpd, and tcpdump..."
sudo apt update
sudo apt install -y redis-server lighttpd tcpdump

# Harden Redis before starting it
REDIS_CONF="/etc/redis/redis.conf"

# Set Redis to listen on all interfaces and disable protected mode
sudo sed -i 's/^# *bind .*/bind 0.0.0.0/' "$REDIS_CONF"
sudo sed -i 's/^bind .*/bind 0.0.0.0/' "$REDIS_CONF"
sudo sed -i 's/^# *protected-mode .*/protected-mode no/' "$REDIS_CONF"
sudo sed -i 's/^protected-mode .*/protected-mode no/' "$REDIS_CONF"

# Remove all existing rename-command lines
sudo sed -i '/^rename-command /d' "$REDIS_CONF"

# Append hardening rename-command lines (disable dangerous commands)
for cmd in CONFIG MODULE SAVE BGSAVE DEBUG SHUTDOWN; do
  echo "rename-command $cmd \"\"" | sudo tee -a "$REDIS_CONF" > /dev/null
done

# Enable and start Redis
sudo systemctl enable redis-server
sudo systemctl restart redis-server
echo "[+] Redis is running on port 6379"

# Set up Lighttpd with port 8080
echo "[+] Configuring Lighttpd on port 8080..."
sudo mkdir -p /var/www/html-8080
echo "<html><body><h1>Welcome!</h1></body></html>" | sudo tee /var/www/html-8080/index.html

sudo sed -i 's|^server.document-root.*|server.document-root = "/var/www/html-8080"|' /etc/lighttpd/lighttpd.conf
sudo sed -i 's|^server.port.*|server.port = 8080|' /etc/lighttpd/lighttpd.conf

# Validate and restart Lighttpd
sudo lighttpd -tt -f /etc/lighttpd/lighttpd.conf
sudo systemctl enable lighttpd
sudo systemctl restart lighttpd
echo "[+] Lighttpd is running on port 8080"

# Start tcpdump for Redis traffic
echo "[+] Starting tcpdump for Redis (port 6379)..."
sudo mkdir -p /var/log/chatbot
sudo nohup tcpdump -i any port 6379 -nn -s 0 -w /var/log/chatbot/redis_traffic.pcap > /dev/null 2>&1 &

echo "[✓] Services configured and Redis traffic capture started."
