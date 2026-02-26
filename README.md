# Connectivity Dashboard

A Docker-based application to monitor **HTTPS** and **SFTP** connectivity, and display server stats and Brisbane weather.

This setup provides:

- A **Welcome webpage** with real-time HTTP and SFTP traffic stats.
- **SFTP access** for file uploads/downloads.
- Continuous monitoring of connectivity.
- Fully containerized with Docker and Docker Compose.

---

## Repository Structure
onnectivity-dashboard/
│
├─ index.html # Welcome webpage
├─ Dockerfile # Web dashboard container
├─ docker-compose.yml
├─ sftp_data/ # Data folder for SFTP container
├─ README.md
└─ (other scripts if needed)

## Quick Start

### 1. Clone the repository

git clone https://github.com/yourusername/connectivity-dashboard.git
cd connectivity-dashboard

### 2. Build and run the containers
sudo docker-compose up -d

### 3. Access the Web Dashboard
https://20.11.10.72

### 4. Connect via SFTP
sftp -P 2222 testuser@20.11.10.72
Password: testpassword

### Stopping the Containers
sudo docker-compose down
