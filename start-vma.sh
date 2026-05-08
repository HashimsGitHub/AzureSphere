#!/bin/bash
set -e

# ══════════════════════════════════════════════════════════════
#  AzureSphere — VM A (Source Host)
#  Downloads release tarball, extracts assets, starts containers
#  No GitHub Actions · No secrets · No code changes
# ══════════════════════════════════════════════════════════════

REPO="HashimsGitHub/AzureSphere"
RELEASE_URL="https://github.com/${REPO}/releases/latest/download/azuresphere-vma.tar.gz"
INSTALL_DIR="$HOME/AzureSphere"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AzureSphere — Source Host (VM A)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── [1/6] Dependencies ────────────────────────────────────────
echo "[1/6] Installing dependencies..."
sudo apt-get update -y -qq
sudo apt-get install -y docker.io docker-compose openssl curl tar 2>&1 \
  | grep -E "^(Setting up|Get:|Err:)" || true

# ── [2/6] Docker ──────────────────────────────────────────────
echo ""
echo "[2/6] Starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

# ── [3/6] Download & extract release bundle ───────────────────
echo ""
echo "[3/6] Downloading release bundle..."

mkdir -p "${INSTALL_DIR}"
TMP=$(mktemp -d)
trap 'rm -rf "${TMP}"' EXIT

curl -fsSL --progress-bar "${RELEASE_URL}" -o "${TMP}/azuresphere-vma.tar.gz" \
  || { echo "  ✗ Failed to download release from ${RELEASE_URL}"; exit 1; }

echo "  Extracting..."
tar -xzf "${TMP}/azuresphere-vma.tar.gz" -C "${TMP}" --strip-components=1

# Copy all assets into install dir — preserving exact repo layout
cp "${TMP}/index.html"              "${INSTALL_DIR}/index.html"
cp "${TMP}/docker-compose.yml"      "${INSTALL_DIR}/docker-compose.yml"
mkdir -p "${INSTALL_DIR}/agent"
cp "${TMP}/agent/agent"             "${INSTALL_DIR}/agent/agent"
chmod +x "${INSTALL_DIR}/agent/agent"
mkdir -p "${INSTALL_DIR}/sftp/data"
echo "  ✓ Assets extracted"

# ── [4/6] Directory structure ─────────────────────────────────
echo ""
echo "[4/6] Creating directory structure..."
mkdir -p "${INSTALL_DIR}/nginx/conf"
mkdir -p "${INSTALL_DIR}/nginx/certs"
mkdir -p "${INSTALL_DIR}/nginx/html"

# Copy dashboard HTML into nginx serving dir (mirrors deploy.yml step)
cp "${INSTALL_DIR}/index.html" "${INSTALL_DIR}/nginx/html/index.html"
echo "  ✓ nginx/html/index.html"

# ── [5/6] SSL certificate ─────────────────────────────────────
echo ""
echo "[5/6] Generating SSL certificate..."

if [ ! -f "${INSTALL_DIR}/nginx/certs/server.crt" ]; then
  VMHOSTNAME=$(hostname -f 2>/dev/null || hostname)
  openssl req -x509 -nodes -days 825 \
    -newkey rsa:2048 \
    -keyout "${INSTALL_DIR}/nginx/certs/server.key" \
    -out    "${INSTALL_DIR}/nginx/certs/server.crt" \
    -subj   "/CN=azuresphere-vm/O=AzureSphere/OU=DiagnosticAgent" \
    -addext "subjectAltName=DNS:localhost,DNS:${VMHOSTNAME},IP:127.0.0.1" \
    2>/dev/null
  echo "  ✓ Certificate generated for ${VMHOSTNAME}"
else
  echo "  ✓ Existing certificate found — skipping"
fi

# Write nginx config (mirrors deploy.yml step exactly)
cat > "${INSTALL_DIR}/nginx/conf/default.conf" << 'NGINXEOF'
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
echo "  ✓ nginx/conf/default.conf"

# ── [6/6] Start containers ────────────────────────────────────
echo ""
echo "[6/6] Starting containers..."
cd "${INSTALL_DIR}"

# Override docker-compose agent service to use pre-built binary
# instead of building from source — all other services unchanged
cat > "${INSTALL_DIR}/docker-compose.override.yml" << OVERRIDEEOF
services:
  agent:
    build: ~
    image: alpine:3.19
    entrypoint: ["/app/agent"]
    volumes:
      - ${INSTALL_DIR}/agent/agent:/app/agent:ro
OVERRIDEEOF

sudo docker-compose pull --quiet 2>/dev/null || true
sudo docker-compose up -d

# Wait for nginx then reload (mirrors deploy.yml logic exactly)
echo ""
echo "  Waiting for nginx to be ready..."
for i in $(seq 1 15); do
  if sudo docker exec https-server nginx -t 2>/dev/null; then
    sudo docker exec https-server nginx -s reload
    echo "  ✓ nginx reloaded"
    break
  fi
  echo "    attempt ${i}/15 — waiting..."
  sleep 2
done

# ── Summary ───────────────────────────────────────────────────
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ VM A deployed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Dashboard : https://${IP}"
echo "  Agent API : http://${IP}:8080/api/info"
echo "  SFTP      : sftp -P 2222 testuser@${IP}  (pass: password)"
echo ""
echo "  Active containers:"
sudo docker-compose ps
echo ""
echo "  Troubleshooting:"
echo "  sudo docker-compose -f ${INSTALL_DIR}/docker-compose.yml logs agent"
echo "  curl http://localhost:8080/api/info"
echo ""