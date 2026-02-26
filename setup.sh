#!/bin/bash

echo "Updating system..."
sudo apt update -y

echo "Installing required packages..."
sudo apt install -y docker.io docker-compose openssl git

echo "Starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo "Creating directory structure..."
mkdir -p nginx/conf
mkdir -p nginx/certs
mkdir -p nginx/html
mkdir -p sftp/data

echo "Creating Welcome HTML page..."
cat <<EOF > nginx/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Welcome</title>
</head>
<body style="text-align:center; margin-top:100px; font-family:Arial;">
    <h1>✅ HTTPS is Working on Port 443</h1>
    <p>Server IP: $(curl -s ifconfig.me)</p>
</body>
</html>
EOF

echo "Generating self-signed SSL certificate..."
openssl req -x509 -nodes -days 365 \
-newkey rsa:2048 \
-keyout nginx/certs/server.key \
-out nginx/certs/server.crt \
-subj "/CN=$(curl -s ifconfig.me)"

echo "Creating Nginx config..."
cat <<EOF > nginx/conf/default.conf
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;

    location / {
        root   /usr/share/nginx/html;
        index  index.html;
    }
}
EOF

echo "Creating test SFTP file..."
echo "This is a test file from SFTP container" > sftp/data/testfile.txt

echo "Starting Docker containers..."
sudo docker compose up -d

echo "Deployment Complete!"
echo "Test HTTPS: https://$(curl -s ifconfig.me)"
echo "Test SFTP: sftp -P 2222 testuser@$(curl -s ifconfig.me)"
