# AzureSphere — Enterprise Connectivity Diagnostic Platform

> **Deploy on any Azure VM and validate real-world enterprise application connectivity between a source host and a destination host — across SQL, PostgreSQL, FTP, RabbitMQ, SAP HANA, webMethods, SMB, SFTP, HTTPS, AS2 and more.**

---

## Overview

AzureSphere is a two-VM enterprise connectivity diagnostic platform built for Cloud Engineers. It simulates real-world enterprise application scenarios where VM A (source) needs to validate connectivity to VM B (destination) across multiple protocols and ports — exactly the kind of testing needed before deploying enterprise middleware, databases, and integration platforms in Azure.

It also supports **AS2 message exchange** between both VMs, simulating real EDI/B2B integration workflows with full MDN receipt acknowledgement.

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
│  ├─ ICMP ping           │──SFTP───▶ │  SFTP          :2222    │
│  └─ AS2 exchange        │──AS2────▶ │  AS2 Inbox     :9090    │
└─────────────────────────┘           └─────────────────────────┘
         ▲                                       ▲
         │                                       │
    Browser                                 Browser
  https://VMA-IP                         https://VMB-IP
```

---

## Screenshots

<!-- Screenshots will be added here -->

---

## Features

### Source Host Dashboard (VM A)

**Connectivity Tab**
- Real TCP connect with latency measurement to any IP/FQDN and port
- Protocol buttons: HTTPS, SFTP, SQL, RabbitMQ, SMB, SAP HANA, PostgreSQL, webMethods, TCP
- Test history log with timestamps and JSON export

**TLS / Certificate Inspector**
- TLS version and cipher suite with security grading (A/B/C/F)
- Complete certificate chain (Leaf → Intermediate → Root CA)
- Subject, issuer, thumbprint, serial number, valid from/to, days remaining
- Subject Alternative Names (SANs)
- Real-world OS trust store validation
- Legacy TLS audit (TLS 1.0 – 1.3)
- Certificate downloads — `.pem` files and full chain

**DNS Tab**
- FQDN → IP resolution with latency
- Split-brain DNS detection
- Azure Private DNS zone awareness

**Ping Tab**
- 4-packet ICMP ping with min/avg/max RTT and packet loss
- Falls back to TCP RTT if ICMP is blocked

**AS2 Exchange Tab**
- Compose and send AS2 messages to VM B with custom Subject and Body
- Pre-filled with EDI/X12 sample payload
- MDN receipt displayed after send — Status, Disposition, Message-ID, timestamp
- Full AS2 message exchange over HTTP with VM B acknowledgement

### Destination Host Dashboard (VM B)

- **Live Connection Log** — real inbound connections from VM A, fixed height with scrollbar, auto-refreshing every 5 seconds
- **Active Services** — all listening endpoints with hit counts and last-seen timestamps
- **Add New Service** — generate docker-compose config for any new protocol/port inline
- **AS2 Inbox** — live inbox showing all AS2 messages received from VM A, positioned below connection log, auto-refreshes every 5 seconds, with Clear button

### CI/CD Pipeline

- GitHub Actions deploys to **both VMs in parallel** on every `git push`
- `--no-cache` build ensures every deploy runs fresh Go compilation
- Auto-clones repo on fresh VM if not present
- Auto-generates SSL certificates on first deploy
- nginx config written by Action on every deploy — never stale

---

## Repository Structure

```
AzureSphere/
├── index.html                    # VM A dashboard (cyan theme)
├── docker-compose.yml            # VM A containers
├── setup.sh                      # VM A one-command bootstrap
├── .gitattributes                # Enforces LF line endings for Linux compat
├── agent/
│   ├── main.go                   # Go agent — TCP/TLS/DNS/ping/AS2 proxy
│   ├── go.mod
│   └── Dockerfile
├── simulator/
│   ├── docker-compose.yml        # VM B containers
│   ├── setup.sh                  # VM B one-command bootstrap
│   ├── nginx/
│   │   ├── conf/default.conf     # VM B nginx — proxies /api/ and /as2/ to persona API
│   │   └── html/index.html       # VM B dashboard (amber theme)
│   └── personas/
│       ├── main.go               # Go persona server — multi-protocol listeners + AS2 inbox
│       ├── go.mod
│       └── Dockerfile
└── .github/
    └── workflows/
        └── deploy.yml            # GitHub Actions — parallel deploy to VM A + VM B
```

---

## Quick Start

### Prerequisites

- Two Ubuntu VMs in Azure (or any cloud) — B1s or larger
- GitHub account with this repo forked
- SSH key pair for each VM
- Azure NSG inbound rules — see Port Reference below

### VM A — Source Host

```bash
git clone https://github.com/HashimsGitHub/AzureSphere.git
cd AzureSphere
chmod +x setup.sh
./setup.sh
```

**Open:** `https://[VM-A-IP]`

### VM B — Destination Host

```bash
git clone https://github.com/HashimsGitHub/AzureSphere.git
cd AzureSphere/simulator
chmod +x setup.sh
./setup.sh
```

**Open:** `https://[VM-B-IP]`

---

## GitHub Actions Auto-Deploy

Every `git push` to `main` automatically deploys to both VMs. After provisioning new VMs, update the two host secrets and push any commit — Actions handles the rest.

### Required GitHub Secrets

**Settings → Secrets and variables → Actions → New repository secret**

| Secret | Value |
|---|---|
| `GH_PAT` | GitHub Personal Access Token (repo scope) |
| `VM_A_HOST` | VM A public IP |
| `VM_A_USER` | VM A SSH username (e.g. `azureuser`) |
| `VM_SSH_KEY` | VM A SSH private key (full `.pem` contents) |
| `VM_B_HOST` | VM B public IP |
| `VM_B_USER` | VM B SSH username (e.g. `azureuser`) |
| `VM_B_SSH_KEY` | VM B SSH private key (full `.pem` contents) |

> **Note:** When provisioning new VMs, only `VM_A_HOST` and `VM_B_HOST` need updating. All other secrets remain the same.

### SSH Access

```bash
# VM A — SSH on port 22 (SFTP container uses port 2222)
ssh -i AzureSphere.pem azureuser@[VM-A-IP]

# VM B
ssh -i simulator_key.pem azureuser@[VM-B-IP]
```

---

## Port Reference

### VM A — Source Host

| Port | Service | Notes |
|---|---|---|
| 443 | HTTPS (nginx) | AzureSphere dashboard |
| 80 | HTTP | Redirects to 443 |
| 2222 | SFTP | Real SFTP endpoint for testing |
| 8080 | Go Agent | Internal — proxied via nginx at `/api/` |
| 22 | SSH | VM admin access |

### VM B — Destination Host

| Port | Service | Protocol |
|---|---|---|
| 443 | Dashboard (nginx) | HTTPS |
| 1433 | SQL Server persona | TDS |
| 5432 | PostgreSQL persona | PostgreSQL wire |
| 21 | FTP persona | FTP |
| 5672 | RabbitMQ persona | AMQP 0-9-1 |
| 30015 | SAP HANA persona | HANA SQL |
| 5555 | webMethods IS persona | HTTP |
| 2222 | SFTP persona | SSH/SFTP |
| 8443 | HTTPS/TLS persona | TLS (real cert) |
| 8888 | Custom TCP persona | TCP |
| 9090 | Persona API + AS2 | HTTP (internal) |
| 22 | SSH | VM admin access |

---

## AS2 Exchange

AzureSphere implements a lightweight AS2-over-HTTP message exchange between VM A and VM B.

### How it works

1. On VM A, open the **AS2 Exchange** tab
2. Enter VM B's IP, a Subject and message Body (EDI/X12 sample pre-filled)
3. Click **Send AS2 Message**
4. VM A's agent POSTs the message to VM B's `/as2/receive` endpoint on port 9090
5. VM B stores the message and returns an **MDN receipt** (disposition, message-ID, timestamp)
6. The MDN receipt is displayed on VM A immediately
7. On VM B's dashboard, the **AS2 Inbox** panel shows all received messages in real time

### AS2 Endpoints (VM B — port 9090)

| Endpoint | Method | Description |
|---|---|---|
| `/as2/receive` | POST | Receive AS2 message, return MDN receipt |
| `/as2/messages` | GET | List all received messages |
| `/as2/clear` | POST | Clear the AS2 inbox |

---

## Agent API Reference (VM A)

The Go agent runs at `http://[VM-A-IP]:8080` and is proxied via nginx at `https://[VM-A-IP]/api/`.

| Endpoint | Method | Parameters | Description |
|---|---|---|---|
| `/api/info` | GET | — | Agent version, hostname, OS, uptime |
| `/api/test/tcp` | GET | `host`, `port` | TCP connect with latency |
| `/api/test/tls` | GET | `host`, `port` | TLS handshake + full cert chain |
| `/api/test/dns` | GET | `host` | DNS resolution + split-brain detection |
| `/api/test/ping` | GET | `host` | ICMP ping (4 packets) |
| `/api/as2/send` | POST | `host` (query) | Send AS2 message to VM B |
| `/api/vmb/messages` | GET | `host` (query) | Proxy VM B AS2 inbox |
| `/api/vmb/clear` | POST | `host` (query) | Clear VM B AS2 inbox |
| `/health` | GET | — | Health check |

**Examples:**

```bash
# TCP connectivity test
curl "http://[VM-A-IP]:8080/api/test/tcp?host=[VM-B-IP]&port=1433"

# TLS certificate inspection
curl "http://[VM-A-IP]:8080/api/test/tls?host=google.com&port=443"

# DNS resolution
curl "http://[VM-A-IP]:8080/api/test/dns?host=storage.blob.core.windows.net"

# Send AS2 message
curl -X POST "http://[VM-A-IP]:8080/api/as2/send?host=[VM-B-IP]" \
  -H "Content-Type: application/json" \
  -d '{"from":"vma","to":"vmb","subject":"Test","body":"ISA*00*...*~"}'
```

---

## Persona API Reference (VM B)

| Endpoint | Method | Description |
|---|---|---|
| `/api/status` | GET | Hostname, uptime, persona count, total connections |
| `/api/personas` | GET | List of all active service personas |
| `/api/connections` | GET | Live connection log (last 500 entries) |
| `/api/connections/reset` | POST | Clear the connection log |
| `/as2/receive` | POST | Receive AS2 message, return MDN |
| `/as2/messages` | GET | List received AS2 messages |
| `/as2/clear` | POST | Clear AS2 inbox |
| `/health` | GET | Health check |

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

Push to deploy automatically:

```bash
git add simulator/docker-compose.yml
git commit -m "feat: add Oracle DB and Kafka personas"
git push
```

---

## NSG / Firewall Rules

### VM A inbound

| Port | Protocol | Source |
|---|---|---|
| 443 | TCP | Any (browser access) |
| 80 | TCP | Any (redirects to 443) |
| 22 | TCP | Any (SSH admin) |
| 2222 | TCP | Any (SFTP testing) |

### VM B inbound

| Port | Protocol | Source |
|---|---|---|
| 443 | TCP | Any (browser access) |
| 22 | TCP | Any (SSH admin) |
| 1433, 5432, 21, 5672, 30015, 5555, 2222, 8443, 8888 | TCP | VM A |
| 9090 | TCP | VM A (Persona API + AS2) |

---

## SSL Certificates

Both VMs auto-generate self-signed certificates on first deploy (825-day validity). To replace with a real certificate:

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

## Troubleshooting

**GitHub Actions RED after VM reprovisioning**
Update `VM_A_HOST` and/or `VM_B_HOST` secrets with the new IPs, then re-run the Action.

**Dashboard shows "Agent offline"**
```bash
sudo docker-compose ps          # check all containers running
sudo docker-compose logs agent  # check agent startup errors
curl http://localhost:8080/api/info  # test agent directly
```

**VM B connection log empty after connectivity test**
Port 443 connects to nginx (dashboard), not the persona API — this is expected. Test against persona ports (1433, 5432, etc.) to see entries in the connection log.

**AS2 404 after redeploy**
Docker may have used a cached image. Force rebuild:
```bash
sudo docker-compose build --no-cache persona-api
sudo docker-compose down && sudo docker-compose up -d
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
