#!/bin/bash
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AzureSphere — VM A Setup & Deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "[1/7] Updating system packages..."
sudo apt update -y

echo ""
echo "[2/7] Installing dependencies..."
sudo apt install -y docker.io docker-compose openssl git curl

echo ""
echo "[3/7] Starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo ""
echo "[4/7] Creating directory structure..."
mkdir -p nginx/conf
mkdir -p nginx/certs
mkdir -p nginx/html
mkdir -p sftp/data
mkdir -p agent

echo ""
echo "[5/7] Generating self-signed SSL certificate..."
HOSTNAME=$(hostname -f 2>/dev/null || hostname)
openssl req -x509 -nodes -days 825 \
  -newkey rsa:2048 \
  -keyout nginx/certs/server.key \
  -out  nginx/certs/server.crt \
  -subj "/CN=azuresphere-vm/O=AzureSphere/OU=DiagnosticAgent" \
  -addext "subjectAltName=DNS:localhost,DNS:${HOSTNAME},IP:127.0.0.1"
echo "   ✓ Certificate valid for 825 days"

echo ""
echo "[6/7] Writing nginx config..."
cat > nginx/conf/default.conf << 'NGINXEOF'
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    location / {
        root  /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass         http://host.docker.internal:8080/api/;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 30s;
        add_header Access-Control-Allow-Origin  * always;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type" always;
        if ($request_method = OPTIONS) { return 204; }
    }

    location /health {
        proxy_pass http://host.docker.internal:8080/health;
    }
}

server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
NGINXEOF
echo "   ✓ nginx config written"

echo ""
echo "[7/7] Copying index.html and starting all containers..."
cp index.html nginx/html/index.html
sudo docker-compose build agent
sudo docker-compose up -d

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ VM A deployed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Dashboard : https://$(hostname -I | awk '{print $1}')"
echo "  Agent API : http://$(hostname -I | awk '{print $1}'):8080/api/info"
echo "  SFTP      : sftp -P 22 testuser@$(hostname -I | awk '{print $1}')"
echo "  SSH Admin : ssh -p 22222 azureuser@$(hostname -I | awk '{print $1}')"
echo ""
sudo docker-compose ps
EOF