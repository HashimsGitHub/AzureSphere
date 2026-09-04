#!/usr/bin/env bash
set -Eeuo pipefail

# Local-repository deployment for VM B. Fedora and Debian/Ubuntu compatible.
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
echo "  AzureSphere VM B - Setup and Deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "[1/5] Installing dependencies..."; install_deps
echo "[2/5] Starting Docker..."; sudo systemctl enable --now docker

if command -v firewall-cmd >/dev/null 2>&1 && sudo systemctl is-active --quiet firewalld; then
  for port in 80 443 9090 1433 5432 21 5672 30015 5555 445 8888 8080 5671 8443 2222; do
    sudo firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null
  done
  sudo firewall-cmd --reload >/dev/null
fi

echo "[3/5] Creating directories..."
mkdir -p nginx/conf nginx/certs sftp-data

echo "[4/5] Generating SSL certificate..."
HOST=$(hostname -f 2>/dev/null || hostname)
if [[ ! -f nginx/certs/server.crt ]]; then
  openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
    -keyout nginx/certs/server.key -out nginx/certs/server.crt \
    -subj "/CN=azuresphere-vmb/O=AzureSphere/OU=TargetSimulator" \
    -addext "subjectAltName=DNS:localhost,DNS:${HOST},IP:127.0.0.1" >/dev/null 2>&1
fi

echo "[5/5] Building and starting containers..."
compose build persona-api
compose up -d
compose ps
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "Dashboard: https://${IP:-127.0.0.1}"
echo "Persona API: http://${IP:-127.0.0.1}:9090/api/status"
