#!/bin/bash
set -e

REDIS_PASSWORD="Super\$ecretPass123!"  # ← CHANGE THIS TO A STRONG VALUE

echo "[+] Installing Redis, Lighttpd, and tcpdump..."
sudo apt update
sudo apt install -y redis-server lighttpd tcpdump

REDIS_CONF="/etc/redis/redis.conf"

echo "[+] Configuring Redis..."
# Set Redis to listen on all interfaces and disable protected mode
sudo sed -i 's/^# *bind .*/bind 0.0.0.0/' "$REDIS_CONF"
sudo sed -i 's/^bind .*/bind 0.0.0.0/' "$REDIS_CONF"
sudo sed -i 's/^# *protected-mode .*/protected-mode no/' "$REDIS_CONF"
sudo sed -i 's/^protected-mode .*/protected-mode no/' "$REDIS_CONF"

# Remove old rename-command lines
sudo sed -i '/^rename-command /d' "$REDIS_CONF"

# Disable dangerous commands
for cmd in CONFIG MODULE SAVE BGSAVE DEBUG SHUTDOWN; do
  echo "rename-command $cmd \"\"" | sudo tee -a "$REDIS_CONF" > /dev/null
done

# Set a password
if grep -q '^# *requirepass' "$REDIS_CONF"; then
  sudo sed -i "s/^# *requirepass .*/requirepass \"$REDIS_PASSWORD\"/" "$REDIS_CONF"
else
  echo "requirepass \"$REDIS_PASSWORD\"" | sudo tee -a "$REDIS_CONF" > /dev/null
fi

# Restart Redis
sudo systemctl enable redis-server
sudo systemctl restart redis-server
echo "[+] Redis secured and running on port 6379"

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

echo "[+] Starting tcpdump for Redis (port 6379)..."
sudo mkdir -p /var/log/chatbot
sudo nohup tcpdump -i any port 6379 -nn -s 0 -w /var/log/chatbot/redis_traffic.pcap > /dev/null 2>&1 &

echo "[✓] Services configured and Redis traffic capture started."
