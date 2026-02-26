# Azure Connectivity Lab 🚀

A production-ready Docker-based infrastructure solution providing secure HTTPS web serving and SFTP file transfer services on Azure VM.

## 📋 Overview

This project deploys a robust containerized environment with:
- **Nginx HTTPS Server** - Secure web serving on port 443 with SSL/TLS
- **SFTP Server** - Secure file transfer service on port 2222
- **Docker Compose** - Orchestrated container management

## STEPS 
Note: All Packages / Dependencies will be installed by the setup script

### 1. Clone the Repository

git clone https://github.com/HashimsGitHub/ServerTest_HTTPS_SFTP.git

cd connectivity-lab

### 2. Deploy the Services
#### Make the setup script executable
chmod +x setup.sh

### 3. Run the deployment script
./setup.sh

### 4. Verify Deployment
#### Check running containers
docker compose ps

#### View logs
docker compose logs -f

### 6. Test HTTPS connection
- Open in Browser https://<SERVER_IP>
- Accept Certificate Warning
- See the AzureSphere Dashboard


### 7. Test SFTP connection
sftp -P 2222 testuser@<SERVER_IP>
Password: testpassword


### 8. Stop Services
sudo docker compose down

### 9. Start Services
sudo docker compose up -d

