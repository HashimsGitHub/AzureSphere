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

# Copy nginx conf and dashboard HTML from bundle (exact repo files)
cp "${TMP}/nginx/conf/default.conf"              "${INSTALL_DIR}/nginx/conf/default.conf"
cp "${TMP}/nginx/html/index.html"                "${INSTALL_DIR}/nginx/html/index.html"
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
cat > "${INSTALL_DIR}/docker-compose.override.yml" << OVERRIDEEOF
services:
  persona-api:
    build: ~
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
echo ""