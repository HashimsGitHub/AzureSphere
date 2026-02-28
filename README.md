# AzureSphere | Server Connectivity Tool 🚀

A Docker-based infrastructure solution providing secure HTTPS web serving and SFTP file transfer services on Azure Ubuntu VM.

## 📋 Overview

This project deploys a robust containerized environment with:
- **Nginx HTTPS Server** - Secure web serving on port 443 with SSL/TLS
- **SFTP Server** - Secure file transfer service on port 2222
- **Docker Compose** - Orchestrated container management

<img width="1177" height="992" alt="image" src="https://github.com/user-attachments/assets/7166932e-7ec7-4220-bbed-a7f84085645f" />

## Notes: 

- All Packages / Dependencies will be installed by the setup.sh script

- Azure NSG: Please allow access on Ports 80, 443, 22 and 2222

- Dashboard has simulated Data 

## Steps
### 1. Clone the Repository
```bash
git clone https://github.com/HashimsGitHub/ServerTest_HTTPS_SFTP.git connectivity-lab
```
```bash
cd connectivity-lab
```

### 2. Deploy the Services
#### Make the setup script executable
```bash
chmod +x setup.sh
```
### 3. Run the deployment script
```bash
./setup.sh
```
### 4. Verify Deployment
#### Check running containers
```bash
docker compose ps
```
#### View logs
```bash
docker compose logs -f
```
### 5. Test HTTPS connection
- Open in Browser https://<SERVER_IP>
- Accept Certificate Warning
- See the AzureSphere Dashboard


### 6. Test SFTP connection

sftp -P 2222 testuser@<SERVER_IP>

SFTP_Password: password


### 7. Stop Services
```bash
sudo docker-compose down
```
### 8. Start Services
```bash
sudo docker-compose up -d
```
