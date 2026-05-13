#!/bin/bash
set -e

# ══════════════════════════════════════════════════════════════
#  AzureSphere — VM B (Destination Host / Target Simulator)
#  Clones repo from GitHub, builds persona-server from source,
#  starts containers.
#  No GitHub Actions · No release tarballs · No secrets
# ══════════════════════════════════════════════════════════════

REPO="https://github.com/HashimsGitHub/AzureSphere.git"
INSTALL_DIR="$HOME/AzureSphere/simulator"
REPO_DIR="$HOME/AzureSphere"

# Optional branch override: bash start-vmb.sh --branch feature/sap-btp
BRANCH="main"
for arg in "$@"; do
  case $arg in
    --branch=*) BRANCH="${arg#*=}" ;;
    --branch)   shift; BRANCH="$1" ;;
  esac
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AzureSphere — Destination Host (VM B)"
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

if [ -d "${REPO_DIR}/.git" ]; then
  echo "  Repo already present — pulling branch: ${BRANCH}..."
  git -C "${REPO_DIR}" fetch origin
  git -C "${REPO_DIR}" checkout "${BRANCH}"
  git -C "${REPO_DIR}" reset --hard "origin/${BRANCH}"
else
  git clone --depth=1 --branch "${BRANCH}" "${REPO}" "${REPO_DIR}"
fi
echo "  ✓ Repository ready — branch: ${BRANCH} ($(git -C ${REPO_DIR} rev-parse --short HEAD))"

# ── [4/6] Directory structure ─────────────────────────────────
echo ""
echo "[4/6] Creating directory structure..."
mkdir -p "${INSTALL_DIR}/nginx/conf"
mkdir -p "${INSTALL_DIR}/nginx/certs"
mkdir -p "${INSTALL_DIR}/sftp-data"

# index.html, docker-compose.yml and personas/ are all already in place from the git clone

# Write nginx config inline (generated at deploy time with correct port)
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

    location /as2/ {
        proxy_pass         http://host.docker.internal:9090/as2/;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
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
echo "  ✓ nginx/conf/default.conf"

# docker-compose.yml and personas/ are already in place from the git clone
# (INSTALL_DIR is $HOME/AzureSphere/simulator — inside the cloned repo)
echo "  ✓ docker-compose.yml (from repo)"
echo "  ✓ personas/https-persona.conf (from repo)"

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

# ── [6/6] Build & start containers ───────────────────────────
echo ""
echo "[6/6] Building persona-server from source and starting containers..."
cd "${INSTALL_DIR}"

# persona-api uses 'build: ./personas' in docker-compose.yml
# Docker builds it fresh from the cloned Go source — no pre-built binary needed
# No docker-compose.override.yml required
sudo docker-compose build --no-cache persona-api
sudo docker-compose pull --quiet dashboard persona-https persona-sftp 2>/dev/null || true
sudo docker-compose up -d

# Wait for nginx then reload
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
echo "    8080  SAP BTP IS      5671  SAP Event Mesh"
echo ""
echo "  Active containers:"
sudo docker-compose ps
echo ""
echo "  Troubleshooting:"
echo "  sudo docker-compose logs persona-api"
echo "  curl http://localhost:9090/api/status"
echo ""
