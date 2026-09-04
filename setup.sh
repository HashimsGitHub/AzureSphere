#!/usr/bin/env bash
set -Eeuo pipefail

# Local-repository deployment for VM A. Fedora and Debian/Ubuntu compatible.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

compose() {
  if sudo docker compose version >/dev/null 2>&1; then sudo docker compose "$@";
  elif command -v docker-compose >/dev/null 2>&1; then sudo docker-compose "$@";
  else echo "ERROR: Docker Compose is not installed." >&2; exit 1; fi
}

install_deps() {
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf -y install ca-certificates curl git openssl
    if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
      sudo curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
      sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || \
        sudo dnf -y install moby-engine docker-compose
    fi
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y docker.io docker-compose-v2 openssl git curl 2>/dev/null || \
      sudo apt-get install -y docker.io docker-compose openssl git curl
  else
    echo "ERROR: Fedora (dnf) or Debian/Ubuntu (apt) is required." >&2; exit 1
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AzureSphere VM A - Setup and Deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "[1/6] Installing dependencies..."; install_deps
echo "[2/6] Starting Docker..."; sudo systemctl enable --now docker

if command -v firewall-cmd >/dev/null 2>&1 && sudo systemctl is-active --quiet firewalld; then
  sudo firewall-cmd --permanent --add-service=http >/dev/null
  sudo firewall-cmd --permanent --add-service=https >/dev/null
  sudo firewall-cmd --permanent --add-port=8080/tcp >/dev/null
  sudo firewall-cmd --reload >/dev/null
fi

echo "[3/6] Creating directory structure..."
mkdir -p nginx/conf nginx/certs nginx/html
cp -f index.html nginx/html/index.html

echo "[4/6] Generating SSL certificate..."
HOST=$(hostname -f 2>/dev/null || hostname)
if [[ ! -f nginx/certs/server.crt ]]; then
  openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
    -keyout nginx/certs/server.key -out nginx/certs/server.crt \
    -subj "/CN=azuresphere-vm/O=AzureSphere/OU=DiagnosticAgent" \
    -addext "subjectAltName=DNS:localhost,DNS:${HOST},IP:127.0.0.1" >/dev/null 2>&1
fi

echo "[5/6] Writing nginx config..."
cat > nginx/conf/default.conf <<'NGINXEOF'
server {
    listen 443 ssl;
    server_name _;
    ssl_certificate /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    location / { root /usr/share/nginx/html; index index.html; try_files $uri $uri/ /index.html; }
    location /api/ { proxy_pass http://host.docker.internal:8080/api/; proxy_http_version 1.1; proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr; proxy_read_timeout 30s; }
    location /health { proxy_pass http://host.docker.internal:8080/health; }
}
server { listen 80; server_name _; return 301 https://$host$request_uri; }
NGINXEOF

echo "[6/6] Building and starting containers..."
compose build agent
compose up -d
compose ps
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "Dashboard: https://${IP:-127.0.0.1}"
echo "Agent API: http://${IP:-127.0.0.1}:8080/api/info"
