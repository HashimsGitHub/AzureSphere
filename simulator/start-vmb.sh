#!/usr/bin/env bash
set -Eeuo pipefail

# ══════════════════════════════════════════════════════════════
#  AzureSphere — VM B (Destination Host / Target Simulator)
#  Fedora + Debian/Ubuntu compatible deployment script.
# ══════════════════════════════════════════════════════════════

REPO="https://github.com/HashimsGitHub/AzureSphere.git"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
INSTALL_DIR="$SCRIPT_DIR"
BRANCH="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch=*) BRANCH="${1#*=}"; shift ;;
    --branch)   BRANCH="${2:?Missing branch name after --branch}"; shift 2 ;;
    *)          echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

log() { printf '\n%s\n' "$*"; }

install_dependencies() {
  if command -v dnf >/dev/null 2>&1; then
    echo "  Detected Fedora/RHEL-family system (dnf)."
    sudo dnf -y install ca-certificates curl git openssl

    if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
      echo "  Installing Docker Engine + Compose plugin from Docker's Fedora repository..."
      sudo curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo \
        -o /etc/yum.repos.d/docker-ce.repo
      if ! sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        echo "  Docker CE packages were unavailable; trying Fedora's Moby packages..."
        sudo dnf -y install moby-engine docker-compose || {
          echo "ERROR: Could not install Docker/Compose on this Fedora host." >&2
          exit 1
        }
      fi
    fi
  elif command -v apt-get >/dev/null 2>&1; then
    echo "  Detected Debian/Ubuntu-family system (apt)."
    sudo apt-get update -y -qq
    sudo apt-get install -y docker.io docker-compose-v2 openssl curl git 2>/dev/null || \
      sudo apt-get install -y docker.io docker-compose openssl curl git
  else
    echo "ERROR: Supported package manager not found. Fedora (dnf) or Debian/Ubuntu (apt) is required." >&2
    exit 1
  fi
}

compose() {
  if sudo docker compose version >/dev/null 2>&1; then
    sudo docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    sudo docker-compose "$@"
  else
    echo "ERROR: Docker Compose is not installed." >&2
    exit 1
  fi
}

open_firewall_ports() {
  local ports=(80 443 9090 1433 5432 21 5672 30015 5555 445 8888 8080 5671 8443 2222)
  if command -v firewall-cmd >/dev/null 2>&1 && sudo systemctl is-active --quiet firewalld; then
    echo "  Configuring firewalld for VM B service personas..."
    for port in "${ports[@]}"; do
      sudo firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null
    done
    sudo firewall-cmd --reload >/dev/null
    echo "  ✓ firewalld rules applied"
  else
    echo "  firewalld is not active — no local firewall changes required"
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AzureSphere — Destination Host (VM B)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

log "[1/7] Installing dependencies..."
install_dependencies

log "[2/7] Starting Docker..."
sudo systemctl enable --now docker
sudo docker info >/dev/null
echo "  ✓ Docker is running"

log "[3/7] Configuring host firewall..."
open_firewall_ports

log "[4/7] Preparing AzureSphere source..."
if [[ -f "${INSTALL_DIR}/docker-compose.yml" && -d "${INSTALL_DIR}/personas" ]]; then
  echo "  ✓ Using local source: ${INSTALL_DIR}"
  if [[ -d "${REPO_DIR}/.git" ]]; then
    echo "  ✓ Git checkout: $(git -C "${REPO_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo local) ($(git -C "${REPO_DIR}" rev-parse --short HEAD 2>/dev/null || echo uncommitted))"
  fi
else
  REPO_DIR="$HOME/AzureSphere"
  INSTALL_DIR="${REPO_DIR}/simulator"
  echo "  Local source not found — cloning branch: ${BRANCH}..."
  git clone --depth=1 --branch "${BRANCH}" "${REPO}" "${REPO_DIR}"
  echo "  ✓ Repository cloned to ${REPO_DIR}"
fi

log "[5/7] Creating directory structure and nginx config..."
mkdir -p "${INSTALL_DIR}/nginx/conf" "${INSTALL_DIR}/nginx/certs" "${INSTALL_DIR}/sftp-data"

cat > "${INSTALL_DIR}/nginx/conf/default.conf" <<'NGINXEOF'
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

echo "  ✓ nginx configuration ready"

log "[6/7] Generating SSL certificate..."
if [[ ! -f "${INSTALL_DIR}/nginx/certs/server.crt" ]]; then
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

log "[7/7] Building persona-server and starting containers..."
cd "${INSTALL_DIR}"
compose build --no-cache persona-api
compose pull --quiet dashboard persona-https persona-sftp 2>/dev/null || true
compose up -d

for i in $(seq 1 15); do
  if sudo docker exec vmb-dashboard nginx -t >/dev/null 2>&1; then
    sudo docker exec vmb-dashboard nginx -s reload >/dev/null 2>&1 || true
    echo "  ✓ nginx is ready"
    break
  fi
  echo "    nginx attempt ${i}/15 — waiting..."
  sleep 2
done

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
IP=${IP:-127.0.0.1}

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
echo "    445   SMB             8443  HTTPS/TLS"
echo "    2222  SFTP            8888  Custom TCP"
echo "    9090  Persona API     8080  SAP BTP IS"
echo "    5671  SAP Event Mesh"
echo ""
echo "  Active containers:"
compose ps
echo ""
echo "  Troubleshooting:"
echo "  sudo docker compose logs persona-api"
echo "  curl http://localhost:9090/api/status"
echo ""
echo "  NOTE: Also allow required ports in your cloud NSG/security group."
