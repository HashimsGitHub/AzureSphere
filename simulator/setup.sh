#!/bin/bash
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AzureSphere — VM B Target Simulator"
echo "  Setup & Deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "[1/6] Updating system & installing dependencies..."
sudo apt update -y
sudo apt install -y docker.io docker-compose openssl git curl

echo ""
echo "[2/6] Starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo ""
echo "[3/6] Creating directory structure..."
mkdir -p nginx/conf nginx/certs nginx/html personas sftp-data

echo ""
echo "[4/6] Generating SSL certificate..."
HOSTNAME=$(hostname -f 2>/dev/null || hostname)
openssl req -x509 -nodes -days 825 \
  -newkey rsa:2048 \
  -keyout nginx/certs/server.key \
  -out  nginx/certs/server.crt \
  -subj "/CN=azuresphere-vmb/O=AzureSphere/OU=TargetSimulator" \
  -addext "subjectAltName=DNS:localhost,DNS:${HOSTNAME},IP:127.0.0.1"
echo "  ✓ Certificate: CN=azuresphere-vmb (${HOSTNAME})"

echo ""
echo "[5/6] Syncing config files into place..."
echo '   Config files served from repo via Docker volume mounts'

echo ""
echo "[6/6] Building & starting all containers..."
sudo docker-compose build persona-api
sudo docker-compose up -d

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ VM B Simulator deployed successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Dashboard  : https://$(hostname -I | awk '{print $1}')"
echo "  SSH Admin  : ssh -p 2222 $(hostname -I | awk '{print $1}')"
echo "  Persona API: http://$(hostname -I | awk '{print $1}'):9090/api/status"
echo ""
echo "  Active containers:"
sudo docker-compose ps
echo ""
echo "  ── To add a new persona ──"
echo "  1. Edit docker-compose.yml → persona-api → environment"
echo "  2. Add: PERSONA_n: \"Name:PROTOCOL:PORT:Optional Banner\""
echo "  3. Run: sudo docker-compose restart persona-api"
echo ""