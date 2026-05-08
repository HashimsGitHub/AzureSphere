#!/bin/bash
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AzureSphere VM A - Setup and Deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "[1/6] Installing dependencies..."
sudo apt update -y
sudo apt install -y docker.io docker-compose openssl git curl

echo ""
echo "[2/6] Starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo ""
echo "[3/6] Creating directory structure..."
mkdir -p nginx/conf nginx/certs nginx/html sftp/data agent

echo ""
echo "[4/6] Generating SSL certificate..."
HOSTNAME=$(hostname -f 2>/dev/null || hostname)
openssl req -x509 -nodes -days 825 \
  -newkey rsa:2048 \
  -keyout nginx/certs/server.key \
  -out nginx/certs/server.crt \
  -subj "/CN=azuresphere-vm/O=AzureSphere/OU=DiagnosticAgent" \
  -addext "subjectAltName=DNS:localhost,DNS:${HOSTNAME},IP:127.0.0.1"
echo "   Certificate generated for ${HOSTNAME}"

echo ""
echo "[5/6] Writing nginx config..."
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
echo "   nginx config written"

echo ""
echo "[6/6] Building and starting containers..."
cp index.html nginx/html/index.html
sudo docker-compose build agent
sudo docker-compose up -d
sudo docker-compose ps

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  VM A deployed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
IP=$(hostname -I | awk '{print $1}')
echo "  Dashboard : https://${IP}"
echo "  Agent API : http://${IP}:8080/api/info"
echo "  SFTP      : sftp -P 2222 testuser@${IP}"
echo "  SSH Admin : ssh -p 2222 azureuser@${IP}"
echo ""
EOF