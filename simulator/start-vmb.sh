#!/bin/bash
set -e

# ══════════════════════════════════════════════════════════════
#  AzureSphere — VM B (Destination Host / Target Simulator)
#  Downloads release tarball, extracts assets, starts containers
#  No GitHub Actions · No secrets · No code changes
# ══════════════════════════════════════════════════════════════

REPO="HashimsGitHub/AzureSphere"
RELEASE_URL="https://github.com/${REPO}/releases/latest/download/azuresphere-vmb.tar.gz"
INSTALL_DIR="$HOME/AzureSphere/simulator"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AzureSphere — Destination Host (VM B)"
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

curl -fsSL --progress-bar "${RELEASE_URL}" -o "${TMP}/azuresphere-vmb.tar.gz" \
  || { echo "  ✗ Failed to download release from ${RELEASE_URL}"; exit 1; }

echo "  Extracting..."
tar -xzf "${TMP}/azuresphere-vmb.tar.gz" -C "${TMP}" --strip-components=1

# Copy all assets — preserving exact simulator/ repo layout
cp "${TMP}/docker-compose.yml"                   "${INSTALL_DIR}/docker-compose.yml"
mkdir -p "${INSTALL_DIR}/personas"
cp "${TMP}/personas/persona-server"              "${INSTALL_DIR}/personas/persona-server"
cp "${TMP}/personas/https-persona.conf"          "${INSTALL_DIR}/personas/https-persona.conf"
chmod +x "${INSTALL_DIR}/personas/persona-server"
mkdir -p "${INSTALL_DIR}/sftp-data"
echo "  ✓ Assets extracted"

# ── [4/6] Directory structure ─────────────────────────────────
echo ""
echo "[4/6] Creating directory structure..."
mkdir -p "${INSTALL_DIR}/nginx/conf"
mkdir -p "${INSTALL_DIR}/nginx/certs"
mkdir -p "${INSTALL_DIR}/nginx/html"

# FIX: nginx/conf/default.conf and nginx/html/index.html are not included
# in the release tarball — write them inline instead of copying from TMP
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
        proxy_pass         http://host.docker.internal:9090/api/;
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
        proxy_pass http://host.docker.internal:9090/health;
    }
}

server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
NGINXEOF

cat > "${INSTALL_DIR}/nginx/html/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AzureSphere — VM B</title>
  <style>
    body { font-family: sans-serif; background: #0f172a; color: #e2e8f0; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
    .card { background: #1e293b; border-radius: 12px; padding: 2rem 3rem; text-align: center; box-shadow: 0 4px 24px rgba(0,0,0,0.4); }
    h1 { color: #38bdf8; margin-bottom: 0.5rem; }
    p  { color: #94a3b8; }
  </style>
</head>
<body>
  <div class="card">
    <h1>AzureSphere</h1>
    <p>Destination Host — VM B</p>
    <p>Persona API: <code>http://&lt;host&gt;:9090/api/status</code></p>
  </div>
</body>
</html>
HTMLEOF

echo "  ✓ nginx config and dashboard HTML"

# ── [5/6] SSL certificate ─────────────────────────────────────
echo ""
echo "[5/6] Generating SSL certificate..."

if [ ! -f "${INSTALL_DIR}/nginx/certs/server.crt" ]; then
  VMHOSTNAME=$(hostname -f 2>/dev/null || hostname)
  openssl req -x509 -nodes -days 825 \
    -newkey rsa:2048 \
    -keyout "${INSTALL_DIR}/nginx/certs/server.key" \
    -out    "${INSTALL_DIR}/nginx/certs/server.crt" \
    -subj   "/CN=azuresphere-vmb/O=AzureSphere/OU=TargetSimulator" \
    -addext "subjectAltName=DNS:localhost,DNS:${VMHOSTNAME},IP:127.0.0.1" \
    2>/dev/null
  echo "  ✓ Certificate generated for ${VMHOSTNAME}"
else
  echo "  ✓ Existing certificate found — skipping"
fi

# ── [6/6] Start containers ────────────────────────────────────
echo ""
echo "[6/6] Starting containers..."
cd "${INSTALL_DIR}"

# Override docker-compose persona-api service to use pre-built binary
# instead of building from source — all other services unchanged
# FIX: removed 'build: ~' (null is invalid); omitting build key causes
# Docker Compose to use the image: value instead, which is correct behaviour
cat > "${INSTALL_DIR}/docker-compose.override.yml" << OVERRIDEEOF
services:
  persona-api:
    image: alpine:3.19
    entrypoint: ["/app/persona-server"]
    volumes:
      - ${INSTALL_DIR}/personas/persona-server:/app/persona-server:ro
OVERRIDEEOF

sudo docker-compose pull --quiet 2>/dev/null || true
sudo docker-compose up -d

# Wait for nginx then reload (mirrors deploy.yml logic exactly)
echo ""
echo "  Waiting for nginx to be ready..."
for i in $(seq 1 15); do
  if sudo docker exec vmb-dashboard nginx -t 2>/dev/null; then
    sudo docker exec vmb-dashboard nginx -s reload
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
echo "  ✓ VM B deployed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Dashboard   : https://${IP}"
echo "  Persona API : http://${IP}:9090/api/status"
echo "  SFTP        : sftp -P 2222 sftpuser@${IP}  (pass: SftpPass123)"
echo ""
echo "  Active persona ports:"
echo "    1433  SQL Server      5432  PostgreSQL"
echo "    21    FTP             5672  RabbitMQ"
echo "    30015 SAP HANA        5555  webMethods IS"
echo "    8443  HTTPS/TLS       2222  SFTP"
echo "    8888  Custom TCP      9090  Persona API + AS2"
echo ""
echo "  Active containers:"
sudo docker-compose ps
echo ""
echo "  Troubleshooting:"
echo "  sudo docker-compose -f ${INSTALL_DIR}/docker-compose.yml logs persona-api"
echo "  curl http://localhost:9090/api/status"
