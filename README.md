# Azure Connectivity Lab 🚀

A production-ready Docker-based infrastructure solution providing secure HTTPS web serving and SFTP file transfer services on Azure VM.

## 📋 Overview

This project deploys a robust containerized environment with:
- **Nginx HTTPS Server** - Secure web serving on port 443 with SSL/TLS
- **SFTP Server** - Secure file transfer service on port 2222
- **Docker Compose** - Orchestrated container management

## 🏗 Architecture

┌─────────────────────────────────────┐
│ Azure VM (20.11.10.72) │
│ ┌───────────────┐ ┌──────────────┐ │
│ │ Nginx HTTPS │ │ SFTP Server│ │
│ │ Port 443 │ │ Port 2222 │ │
│ └───────────────┘ └──────────────┘ │
│ Docker Compose │
└─────────────────────────────────────┘


## 🔧 Prerequisites

- Docker Engine (version 20.10+)
- Docker Compose (version 2.0+)
- Git
- SSL certificates (for HTTPS)
- OpenSSH client (for SFTP access)

## 🚀 Quick Start

### 1. Clone the Repository

git clone <your-repository-url>
cd connectivity-lab

### 2. Configure Environment
Create a .env file with your configuration:
 
# Server Configuration
SERVER_IP=20.11.10.72
SFTP_PORT=2222
SFTP_USER=testuser
SFTP_PASSWORD=testpassword

# SSL Configuration (if using custom certificates)
SSL_CERT_PATH=./certs/cert.pem
SSL_KEY_PATH=./certs/key.pem

### 3. Deploy the Services
# Make the setup script executable
chmod +x setup.sh

# Run the deployment script
./setup.sh

### 4. Verify Deployment
# Check running containers
docker compose ps

# View logs
docker compose logs -f

# Test HTTPS connection
curl -k https://20.11.10.72

# Test SFTP connection
sftp -P 2222 testuser@20.11.10.72
# Password: testpassword


### Stop Services
sudo docker compose down

### Start Services
sudo docker compose up -d

