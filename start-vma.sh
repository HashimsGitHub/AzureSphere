#!/bin/bash
set -e

# ══════════════════════════════════════════════════════════════
#  AzureSphere — VM A (Source Host)
#  Clones repo from GitHub, builds agent from source, starts
#  containers. No GitHub Actions · No release tarballs · No secrets
# ══════════════════════════════════════════════════════════════

REPO="https://github.com/HashimsGitHub/AzureSphere.git"
INSTALL_DIR="$HOME/AzureSphere"

# Optional branch override: bash start-vma.sh --branch feature/sap-btp
BRANCH="main"
for arg in "$@"; do
  case $arg in
    --branch=*) BRANCH="${arg#*=}" ;;
    --branch)   shift; BRANCH="$1" ;;
  esac
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AzureSphere — Source Host (VM A)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── [1/6] Dependencies ────────────────────────────────────────
echo "[1/6] Installing dependencies..."
sudo apt-get update -y -qq
sudo apt-get install -y docker.io docker-compose openssl curl git 2>&1 \
  | grep -E "^(Setting up|Get:|Err:)" || true

# ── [2/6] Docker ──────────────────────────────────────────────
echo ""
echo "[2/6] Starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

# ── [3/6] Clone / update repo ─────────────────────────────────
echo ""
echo "[3/6] Fetching latest source from GitHub..."

if [ -d "${INSTALL_DIR}/.git" ]; then
  echo "  Repo already present — pulling branch: ${BRANCH}..."
  git -C "${INSTALL_DIR}" fetch origin
  git -C "${INSTALL_DIR}" checkout "${BRANCH}"
  git -C "${INSTALL_DIR}" reset --hard "origin/${BRANCH}"
else
  git clone --depth=1 --branch "${BRANCH}" "${REPO}" "${INSTALL_DIR}"
fi
echo "  ✓ Repository ready — branch: ${BRANCH} ($(git -C ${INSTALL_DIR} rev-parse --short HEAD))"

# ── [4/6] Directory structure ─────────────────────────────────
echo ""
echo "[4/6] Creating directory structure..."
mkdir -p "${INSTALL_DIR}/nginx/conf"
mkdir -p "${INSTALL_DIR}/nginx/certs"
mkdir -p "${INSTALL_DIR}/nginx/html"
mkdir -p "${INSTALL_DIR}/sftp/data"

# Always overwrite index.html from the checked-out branch (prevents stale cache from old deploys)
cp -f "${INSTALL_DIR}/index.html" "${INSTALL_DIR}/nginx/html/index.html"
echo "  ✓ nginx/html/index.html (branch: ${BRANCH})"

# Write nginx config inline (not stored in repo root, generated at deploy time)
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

    # SSE endpoint for UberRoute — requires buffering disabled and long timeout
    location /api/test/traceroute {
        proxy_pass         http://host.docker.internal:8080/api/test/traceroute;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_set_header   Connection        '';
        proxy_read_timeout 120s;
        proxy_buffering    off;
        proxy_cache        off;
        chunked_transfer_encoding on;
        add_header Access-Control-Allow-Origin  * always;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type" always;
        add_header X-Accel-Buffering no;
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

# ── [6/6] Build & start containers ───────────────────────────
echo ""
echo "[6/6] Building agent from source and starting containers..."
cd "${INSTALL_DIR}"

# agent service uses 'build: ./agent' in docker-compose.yml
# Docker builds it fresh from the cloned Go source — no pre-built binary needed
# No docker-compose.override.yml required
sudo docker-compose build --no-cache agent
sudo docker-compose pull --quiet https-server sftp-server 2>/dev/null || true
sudo docker-compose up -d

# Wait for nginx then reload
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
echo "  sudo docker-compose logs agent"
echo "  curl http://localhost:8080/api/info"
echo ""
