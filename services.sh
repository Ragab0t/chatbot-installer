!/bin/bash

set -e

echo "[+] Installing Redis and Lighttpd..."

# Update and install packages
sudo apt update
sudo apt install -y redis-server lighttpd

# Enable and start Redis
sudo systemctl enable redis-server
sudo systemctl start redis-server
echo "[+] Redis is running on port 6379"

# Set up Lighttpd with custom port 8080
echo "[+] Configuring Lighttpd to use port 8080..."

sudo mkdir -p /var/www/html-8080
echo "<html><body><h1>Welcome to the fake panel!</h1></body></html>" | sudo tee /var/www/html-8080/index.html

# Replace server.document-root and port in lighttpd config
sudo sed -i 's|^server.document-root.*|server.document-root = "/var/www/html-8080"|' /etc/lighttpd/lighttpd.conf
sudo sed -i 's|^server.port.*|server.port = 8080|' /etc/lighttpd/lighttpd.conf

# Validate config before starting
echo "[+] Validating Lighttpd config..."
sudo lighttpd -tt -f /etc/lighttpd/lighttpd.conf

# Enable and restart Lighttpd
sudo systemctl enable lighttpd
sudo systemctl restart lighttpd

echo "[+] Lighttpd is running on port 8080"
