# AzureSphere — Enterprise Connectivity Diagnostic Platform

> **Deploy on any Azure VM (public or private IP) and validate real-world enterprise application connectivity between a source host and a destination host — across SQL, PostgreSQL, FTP, RabbitMQ, SAP HANA, webMethods, SMB, SFTP, HTTPS and more.**

---

## Overview

AzureSphere is a two-VM enterprise connectivity diagnostic platform built for Cloud Engineers. It simulates real-world enterprise application scenarios where VM A (source) needs to validate connectivity to VM B (destination) across multiple protocols and ports — exactly the kind of testing needed before deploying enterprise middleware, databases, and integration platforms in Azure.

```
Source Host (VM A)                    Destination Host (VM B)
┌─────────────────────────┐           ┌─────────────────────────┐
│  AzureSphere Dashboard  │──TCP────▶ │  SQL Server    :1433    │
│  (cyan theme)           │──TLS────▶ │  PostgreSQL    :5432    │
│                         │──FTP────▶ │  FTP Server    :21      │
│  Go Agent :8080         │──AMQP───▶ │  RabbitMQ      :5672    │
│  ├─ TCP test            │──HTTPS──▶ │  HTTPS/TLS     :8443    │
│  ├─ TLS inspect         │──HANA───▶ │  SAP HANA      :30015   │
│  ├─ DNS resolve         │──HTTP───▶ │  webMethods IS :5555    │
│  └─ ICMP ping           │──SMB────▶ │  SMB Share     :445     │
│                         │──SFTP───▶ │  SFTP          :2222    │
└─────────────────────────┘           └─────────────────────────┘
         ▲                                       ▲
         │                                       │
    VM C Browser                           VM C Browser
  https://VMA-IP                         https://VMB-IP
```

---

## Features

### Source Host Dashboard (VM A)
- **Connectivity testing** — real TCP connect with latency measurement to any IP/FQDN and port
- **TLS / Certificate Inspector** — full sslCheck.ps1 parity:
  - TLS version and cipher suite with security grading (A/B/C/F)
  - Complete certificate chain (Leaf → Intermediate → Root CA)
  - Subject, issuer, thumbprint, serial number, valid from/to, days remaining
  - Subject Alternative Names (SANs) grouped by root domain
  - Stage 3b real-world OS trust store validation
  - Legacy TLS audit (SSL 2.0, 3.0, TLS 1.0–1.3)
  - **Certificate downloads** — real `.pem` files, `chain_full.pem`, inspection report
- **DNS Resolution** — FQDN → IP with split-brain DNS detection and Azure Private DNS zone awareness
- **ICMP Ping** — 4-packet ping with min/avg/max RTT and packet loss
- **Test History Log** — timestamped log of all tests with JSON export
- Works on **any IP** (public, private, FQDN) — no hardcoded addresses

### Destination Host Dashboard (VM B)
- **Live Connection Log** — real inbound connections from VM A, auto-refreshing every 5 seconds
- **Active Services** — all listening endpoints with hit counts and last-seen timestamps
- **Add New Service** — generate docker-compose config for any new protocol/port
- **Log Reset** — server-side log wipe with pause/resume auto-refresh
- Supports 8 protocol personas out of the box, unlimited via config

### CI/CD Pipeline
- GitHub Actions deploys to **both VMs in parallel** on every `git push`
- Auto-clones repo if missing on VM
- Auto-generates SSL certificates on first deploy
- Zero manual steps after initial setup

---

## Repository Structure

```
AzureSphere/
├── index.html                    # VM A dashboard (cyan theme)
├── docker-compose.yml            # VM A containers
├── setup.sh                      # VM A one-command deploy
├── agent/
│   ├── main.go                   # Go backend agent (TCP/TLS/DNS/ping)
│   ├── go.mod
│   └── Dockerfile                # Multi-stage Go build — no Go on host needed
├── nginx/
│   └── conf/default.conf         # nginx config with /api/ proxy to agent
├── simulator/
│   ├── docker-compose.yml        # VM B containers
│   ├── setup.sh                  # VM B one-command deploy
│   ├── nginx/
│   │   ├── conf/default.conf     # VM B nginx with /api/ proxy to persona API
│   │   └── html/index.html       # VM B dashboard (amber theme)
│   └── personas/
│       ├── main.go               # Go persona server — multi-protocol TCP listeners
│       ├── go.mod
│       └── Dockerfile
└── .github/
    └── workflows/
        └── deploy.yml            # GitHub Actions — deploys VM A + VM B
```

---

## Quick Start

### Prerequisites
- Two Ubuntu VMs in Azure (or any cloud) — no Go installation required
- GitHub account with this repo forked or cloned
- SSH key pair for each VM

### VM A — Source Host

```bash
# Clone and deploy in one command
git clone https://github.com/HashimsGitHub/AzureSphere.git
cd AzureSphere
chmod +x setup.sh
./setup.sh
```

**Open:** `https://[VM-A-IP]`

### VM B — Destination Host

```bash
# Clone and deploy in one command
git clone https://github.com/HashimsGitHub/AzureSphere.git
cd AzureSphere/simulator
chmod +x setup.sh
./setup.sh
```

**Open:** `https://[VM-B-IP]`

---

## GitHub Actions Auto-Deploy

Every `git push` to `main` automatically deploys to both VMs.

### Required GitHub Secrets

Go to: **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Value |
|---|---|
| `GH_PAT` | GitHub Personal Access Token (repo scope) |
| `VM_A_HOST` | VM A public or private IP |
| `VM_A_USER` | VM A SSH username (e.g. `azureuser`) |
| `VM_SSH_KEY` | VM A SSH private key (full contents of `.pem` file) |
| `VM_B_HOST` | VM B public or private IP |
| `VM_B_USER` | VM B SSH username (e.g. `azureuser`) |
| `VM_B_SSH_KEY` | VM B SSH private key (full contents of `.pem` file) |

### VM A SSH Port

VM A runs SSH on port **22222** (port 22 is reserved for SFTP testing).

```bash
# SSH into VM A
ssh -i AzureSphere.pem -p 22222 azureuser@[VM-A-IP]

# SSH into VM B
ssh -i simulator_key.pem azureuser@[VM-B-IP]
```

---

## Port Reference

### VM A — Source Host

| Port | Service | Purpose |
|---|---|---|
| 443 | HTTPS (nginx) | AzureSphere dashboard |
| 80 | HTTP | Redirects to 443 |
| 22 | SFTP | Real SFTP endpoint for testing |
| 8080 | Go Agent | Internal API (proxied via nginx) |
| 22222 | SSH | VM admin access |

### VM B — Destination Host

| Port | Service | Protocol |
|---|---|---|
| 443 | Dashboard (nginx) | HTTPS |
| 1433 | SQL Server persona | TDS |
| 5432 | PostgreSQL persona | PostgreSQL |
| 21 | FTP persona | FTP |
| 5672 | RabbitMQ persona | AMQP 0-9-1 |
| 30015 | SAP HANA persona | HANA SQL |
| 5555 | webMethods IS persona | HTTP |
| 445 | SMB persona | SMB2 |
| 2222 | SFTP persona | SSH/SFTP |
| 8443 | HTTPS/TLS persona | TLS (real cert) |
| 8888 | Custom TCP persona | TCP |
| 9090 | Persona API | HTTP (internal) |
| 22 | SSH | VM admin access |

---

## Adding a New Service Persona (VM B)

Edit `simulator/docker-compose.yml` under `persona-api → environment`:

```yaml
PERSONA_9:  "Oracle DB:TCP:1521:Oracle Database 19c Ready"
PERSONA_10: "Kafka Broker:TCP:9092:Kafka broker ready"
PERSONA_11: "Redis:TCP:6379:+PONG"
PERSONA_12: "MongoDB:TCP:27017:MongoDB ready"
```

**Format:** `"Name:PROTOCOL:PORT:Optional Banner"`

**Supported protocols:** `SQL`, `POSTGRES`, `FTP`, `RABBITMQ`, `HANA`, `WEBMETHODS`, `SMB`, `TCP`

Then push — GitHub Actions will rebuild and redeploy VM B automatically:

```bash
git add simulator/docker-compose.yml
git commit -m "feat: add Oracle DB and Kafka personas"
git push
```

Or restart manually on VM B with zero downtime for other services:

```bash
sudo docker-compose restart persona-api
```

---

## Agent API Reference (VM A)

The Go agent exposes these endpoints at `http://[VM-A-IP]:8080` (also proxied via nginx at `/api/`):

| Endpoint | Method | Parameters | Description |
|---|---|---|---|
| `/api/info` | GET | — | Agent version, hostname, OS, uptime |
| `/api/test/tcp` | GET/POST | `host`, `port` | TCP connect with latency |
| `/api/test/tls` | GET/POST | `host`, `port` | TLS handshake + full cert chain |
| `/api/test/dns` | GET/POST | `host` | DNS resolution + split-brain detection |
| `/api/test/ping` | GET/POST | `host` | ICMP ping (4 packets) |
| `/health` | GET | — | Health check |

**Example:**

```bash
# Test TCP connectivity to VM B SQL Server
curl "http://[VM-A-IP]:8080/api/test/tcp?host=[VM-B-IP]&port=1433"

# Inspect TLS certificate
curl "http://[VM-A-IP]:8080/api/test/tls?host=[VM-B-IP]&port=8443"

# DNS resolution with split-brain detection
curl "http://[VM-A-IP]:8080/api/test/dns?host=storage.blob.core.windows.net"
```

---

## Persona API Reference (VM B)

| Endpoint | Method | Description |
|---|---|---|
| `/api/status` | GET | Hostname, uptime, persona count, total connections |
| `/api/personas` | GET | List of all active service personas |
| `/api/connections` | GET | Live connection log (last 500 entries) |
| `/api/connections/reset` | POST | Clear the connection log |
| `/health` | GET | Health check |

---

## NSG / Firewall Rules

### VM A inbound
| Port | Protocol | Source |
|---|---|---|
| 443 | TCP | VM C (browser) |
| 22 | TCP | Any (SFTP testing) |
| 22222 | TCP | Your admin IP |

### VM B inbound
| Port | Protocol | Source |
|---|---|---|
| 443 | TCP | VM C (browser) |
| 1433, 5432, 21, 5672, 30015, 5555, 445, 2222, 8443, 8888 | TCP | VM A |
| 22 | TCP | Your admin IP |

---

## SSL Certificates

Both VMs generate self-signed certificates on first deploy. These are valid for 825 days with a generic CN (`azuresphere-vm` / `azuresphere-vmb`) that works on any IP address.

To replace with a real certificate, copy your files to the nginx certs directory:

```bash
# VM A
cp your-cert.crt ~/AzureSphere/nginx/certs/server.crt
cp your-cert.key ~/AzureSphere/nginx/certs/server.key
sudo docker exec https-server nginx -s reload

# VM B
cp your-cert.crt ~/AzureSphere/simulator/nginx/certs/server.crt
cp your-cert.key ~/AzureSphere/simulator/nginx/certs/server.key
sudo docker exec vmb-dashboard nginx -s reload
```

---

## Related Tools

- **[SSL-CheckTool](https://github.com/HashimsGitHub/SSL-CheckTool)** — PowerShell enterprise HTTPS diagnostic tool by the same author. AzureSphere's TLS inspector is built on the same staged approach: DNS → TCP → TLS handshake → trust validation → cert chain → legacy TLS audit.

---

## Author

**Hashim Hilal**
Cloud Engineer · DXC Technology
[github.com/HashimsGitHub](https://github.com/HashimsGitHub)

---

*AzureSphere is a read-only diagnostic platform. No configuration changes are made to target systems. All persona listeners are non-destructive TCP responders.*
