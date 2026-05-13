# AzureSphere — Enterprise Connectivity Diagnostic Platform

> **Validate, audit and document real-world enterprise application connectivity between cloud-hosted systems — across SQL, SAP, messaging, file transfer, EDI and custom protocols — before you go live.**

---

## Why AzureSphere?

Enterprise cloud migrations fail at the network layer more often than any other. Before your middleware, integration platform or database workload goes live, you need to know — with certainty — that every protocol, port and service endpoint is reachable, correctly configured and TLS-compliant from your source environment.

AzureSphere gives engineering and architecture teams a **production-grade connectivity diagnostic platform** that can be deployed in minutes on any two Azure VMs. It validates the full communication path between a source host and a destination host, logs every result, and produces audit-ready evidence of connectivity status across your enterprise protocol stack.

No agents to license. No SaaS dependency. No configuration changes to target systems. Pure open-source, self-hosted, and built for Cloud Engineers who need answers fast.

---

## What It Does

AzureSphere operates across two VMs — a **Source Host (VM A)** that runs active diagnostics, and a **Destination Host (VM B)** that simulates enterprise service endpoints and captures inbound connection evidence.

```
Source Host (VM A)                         Destination Host (VM B)
┌──────────────────────────────┐           ┌──────────────────────────────┐
│   AzureSphere Dashboard      │──TCP─────▶│  SQL Server 2022   :1433     │
│   Enterprise Diagnostics     │──TCP─────▶│  PostgreSQL 16     :5432     │
│                              │──FTP─────▶│  FTP Server        :21       │
│   Go Diagnostic Agent :8080  │──AMQP────▶│  RabbitMQ 3.12     :5672     │
│   ├─ TCP connectivity test   │──HTTPS───▶│  HTTPS / TLS       :8443     │
│   ├─ TLS / certificate audit │──HANA────▶│  SAP HANA          :30015    │
│   ├─ DNS resolution + FQDN   │──HTTP────▶│  webMethods IS     :5555     │
│   ├─ ICMP / TCP ping         │──SMB─────▶│  SMB / Azure Files :445      │
│   ├─ AS2 EDI exchange        │──SFTP────▶│  SFTP              :2222     │
│   └─ SAP BTP connectivity    │──BTP─────▶│  SAP BTP IS        :8080     │
└──────────────────────────────┘──AMQP────▶│  SAP Event Mesh    :5671     │
          ▲                                 └──────────────────────────────┘
          │                                              ▲
     Browser / Engineer                          Browser / Engineer
   https://VMA-IP                               https://VMB-IP
```

---

## Business Benefits

### De-Risk Migration Projects
Identify connectivity blockers — blocked ports, misconfigured NSGs, DNS resolution failures, expired or untrusted certificates — before your workloads go live. AzureSphere gives your team confidence that the network path is valid end-to-end, not just at the firewall level.

### Accelerate Enterprise Integration Testing
Test the exact protocol and port combination your middleware, ERP or integration platform will use. AzureSphere simulates SQL Server, SAP HANA, RabbitMQ, webMethods, SAP BTP and more — so your integration team can validate connectivity without waiting for target systems to be provisioned.

### Generate Audit Evidence
Every test — TCP, TLS, DNS, AS2, SAP BTP — is captured in the Test Log with timestamps, latency, protocol, result and detail. Export to CSV for inclusion in migration readiness reports, security review packs or project sign-off documentation.

### Validate SAP Connectivity End-to-End
Purpose-built support for SAP HANA (port 30015), SAP BTP Integration Suite (port 8080), SAP Event Mesh AMQP (port 5671) and SAP Cloud Foundry API (port 443). Test every layer of your SAP landscape from a single dashboard before go-live.

### Prove B2B / EDI Readiness
Built-in AS2 message exchange between VM A and VM B validates your B2B integration path with full MDN receipt acknowledgement — the same handshake used in production EDI workflows between trading partners.

### Zero Licensing Cost
Fully open-source. Deploy on any Azure VM (B1s or larger). No per-seat licensing, no SaaS subscription, no vendor dependency.

---

## Platform Architecture

AzureSphere is a two-container platform deployed independently on each VM, connected only by the network paths under test.

**VM A — Source Host**
- **nginx** (HTTPS) — serves the AzureSphere dashboard on port 443
- **Go Diagnostic Agent** — performs TCP, TLS, DNS, ICMP and AS2 tests against VM B; proxied via nginx at `/api/`

**VM B — Destination Host**
- **nginx** (HTTPS) — serves the VM B monitoring dashboard on port 443
- **Go Persona Server** — multi-protocol listener that simulates 10 enterprise service endpoints simultaneously, logs every inbound connection, and handles AS2 message receipt

Both VMs run entirely in Docker with no external dependencies beyond the GitHub repository.

---

## Feature Reference

### VM A — Source Host Dashboard

#### Connectivity Tab
Real TCP connectivity tests with latency measurement against any IP address or FQDN and port. Protocol presets auto-fill the correct port:

| Protocol | Port | What It Validates |
|---|---|---|
| HTTPS | 443 | Web and API endpoint reachability |
| SFTP | 2222 | Secure file transfer path |
| SQL Server | 1433 | Database TCP connectivity |
| RabbitMQ | 5672 | Message broker reachability |
| SMB | 445 | File share / Azure Files connectivity |
| SAP HANA | 30015 | HANA database SQL port |
| TCP (custom) | Any | Any arbitrary TCP endpoint |

Test results are added to the **Test Log** automatically with timestamp, protocol, latency and pass/fail status.

#### TLS / Certificate Inspector
Full certificate chain inspection with security grading, giving teams a complete picture of TLS health before go-live:

- Security grade (A / B / C / F) based on TLS version, cipher suite and certificate status
- TLS version negotiated (1.0 / 1.1 / 1.2 / 1.3) and cipher suite
- Full certificate chain: Leaf → Intermediate → Root CA
- Subject, issuer, thumbprint, serial number, valid from/to, days remaining
- Subject Alternative Names (SANs)
- OS trust store validation (trusted / untrusted)
- Legacy TLS audit (checks TLS 1.0 and 1.1 exposure)
- Certificate downloads — individual `.pem` files and full chain bundle

#### DNS Tab
FQDN resolution with enterprise-aware analysis:

- DNS resolution latency
- All resolved IP addresses
- Split-brain DNS detection (public vs. private resolution mismatch)
- Azure Private DNS zone identification
- Private vs. public endpoint classification

#### SAP BTP Tab
Dedicated SAP Business Technology Platform connectivity testing across all BTP service layers:

| Service | Port | Protocol |
|---|---|---|
| Integration Suite (iFlow) | 8080 | HTTP/BTP |
| Event Mesh | 5671 | AMQP/TLS |
| Cloud Foundry API / OAuth | 443 | HTTPS |
| HANA Cloud | 30015 | HANA SQL |

Each service has a live status card showing reachability and latency. All BTP test results flow into the Test Log.

#### AS2 Exchange Tab
End-to-end AS2 message exchange to validate B2B / EDI integration readiness:

- Compose AS2 messages with custom Subject and Body
- Pre-filled with a valid EDI/X12 sample payload
- Sends to VM B's AS2 inbox over HTTP with full AS2 envelope
- MDN receipt (disposition, message-ID, timestamp) displayed immediately
- Confirms the full B2B handshake path is operational

#### Test Log (Header)
Unified log of every test run across all tabs, accessible from the header bar at any time:

- Captures: Connectivity, TLS/Cert, DNS, AS2 Exchange, SAP BTP
- Columns: Timestamp, Test Type, Target, Port, Protocol, Result, Latency, Detail
- Live entry count badge on the header button
- Export to **CSV** for inclusion in reports and audit packs
- Clear log between test sessions

---

### VM B — Destination Host Dashboard

#### Active Services Panel
Real-time view of all 10 simulated enterprise service endpoints:

| Service | Port | Protocol |
|---|---|---|
| SQL Server 2022 | 1433 | TDS |
| PostgreSQL 16 | 5432 | PostgreSQL wire |
| FTP Server | 21 | FTP |
| RabbitMQ 3.12 | 5672 | AMQP 0-9-1 |
| SAP HANA | 30015 | HANA SQL |
| webMethods IS | 5555 | HTTP |
| SMB / Azure Files | 445 | SMB |
| Custom TCP App | 8888 | TCP |
| SAP BTP Integration Suite | 8080 | HTTP/BTP |
| SAP Event Mesh | 5671 | AMQP |

Each service card shows connection hit count and last-seen timestamp, updating every 5 seconds.

#### Live Connection Log
Scrollable, auto-refreshing log of every inbound connection received from VM A — timestamped, protocol-labelled and source IP captured. Provides independent confirmation of connectivity from the destination side.

#### AS2 Inbox
Live inbox of all AS2 messages received from VM A, with full message detail and MDN acknowledgement status. Auto-refreshes every 5 seconds.

#### Add New Service
Generate a ready-to-paste `docker-compose.yml` snippet for any additional protocol or port — inline, without leaving the dashboard.

---

## Screenshots

### VM A — Source Host Dashboard
<img width="1172" height="845" alt="image" src="https://github.com/user-attachments/assets/a173a52e-1974-4bbf-a547-b9c7ba2d6312" />
<img width="1750" height="887" alt="image" src="https://github.com/user-attachments/assets/692976b2-39a0-4c32-a150-ba86d61070f9" />
<img width="1767" height="790" alt="image" src="https://github.com/user-attachments/assets/437857ed-3729-4dc1-9da6-af6ee14e12de" />
<img width="1776" height="567" alt="image" src="https://github.com/user-attachments/assets/04db2997-0735-42f6-a9bf-b9485c5f0041" />
<img width="820" height="915" alt="image" src="https://github.com/user-attachments/assets/332ec7db-c333-4c34-9b6a-d6da90202cc5" />
<img width="1405" height="910" alt="image" src="https://github.com/user-attachments/assets/faa9f950-9ec1-4140-b6e9-c26d0a884df4" />

### VM B — Destination Host Dashboard
<img width="1378" height="739" alt="image" src="https://github.com/user-attachments/assets/3674c21e-32a1-459d-b382-e5c3bc9e0287" />
<img width="1372" height="856" alt="image" src="https://github.com/user-attachments/assets/69e779b5-7aba-48fd-a89a-6ac984159575" />
<img width="1381" height="595" alt="image" src="https://github.com/user-attachments/assets/31698d97-e6ac-4566-a7bf-082f5df1f364" />

---

## Quick Start

### Prerequisites

- Two Ubuntu VMs in Azure (B1s or larger)
- Inbound NSG rules configured — see [Port Reference](#port-reference) below
- Git installed on each VM

### Deploy VM A — Source Host

```bash
git clone https://github.com/HashimsGitHub/AzureSphere.git
cd AzureSphere
bash start-vma.sh
```

Open: `https://[VM-A-IP]`

### Deploy VM B — Destination Host

```bash
git clone https://github.com/HashimsGitHub/AzureSphere.git
cd AzureSphere/simulator
bash start-vmb.sh
```

Open: `https://[VM-B-IP]`

Both scripts handle all dependencies, Docker setup, SSL certificate generation and container startup automatically. A fresh VM goes from zero to running in under 5 minutes.

---

## Repository Structure

```
AzureSphere/
├── index.html                      # VM A dashboard
├── docker-compose.yml              # VM A containers (nginx + agent + sftp)
├── start-vma.sh                    # VM A one-command deploy script
├── agent/
│   ├── main.go                     # Go diagnostic agent — TCP/TLS/DNS/ping/AS2
│   ├── go.mod
│   └── Dockerfile
└── simulator/
    ├── docker-compose.yml          # VM B containers (nginx + persona server + sftp)
    ├── start-vmb.sh                # VM B one-command deploy script
    ├── nginx/
    │   ├── conf/default.conf       # VM B nginx config
    │   └── html/index.html         # VM B dashboard
    └── personas/
        ├── main.go                 # Go persona server — multi-protocol listeners + AS2 inbox
        ├── go.mod
        └── Dockerfile
```

---

## Port Reference

### VM A — Source Host (NSG Inbound Rules)

| Port | Protocol | Purpose |
|---|---|---|
| 443 | TCP | AzureSphere dashboard (HTTPS) |
| 80 | TCP | HTTP → HTTPS redirect |
| 2222 | TCP | SFTP test endpoint |
| 22 | TCP | SSH administration |

### VM B — Destination Host (NSG Inbound Rules)

| Port | Protocol | Simulated Service |
|---|---|---|
| 443 | TCP | VM B monitoring dashboard (HTTPS) |
| 1433 | TCP | SQL Server 2022 |
| 5432 | TCP | PostgreSQL 16 |
| 21 | TCP | FTP Server |
| 5672 | TCP | RabbitMQ 3.12 |
| 30015 | TCP | SAP HANA |
| 5555 | TCP | webMethods Integration Server |
| 2222 | TCP | SFTP |
| 8443 | TCP | HTTPS / TLS persona |
| 445 | TCP | SMB / Azure Files |
| 8080 | TCP | SAP BTP Integration Suite |
| 5671 | TCP | SAP Event Mesh (AMQP) |
| 8888 | TCP | Custom TCP application |
| 9090 | TCP | Persona API + AS2 inbox |
| 22 | TCP | SSH administration |

---

## Adding Custom Service Personas (VM B)

Extend VM B to simulate any additional protocol or service by adding `PERSONA_n` entries to `simulator/docker-compose.yml`:

```yaml
environment:
  PERSONA_11: "Oracle DB:TCP:1521:Oracle Database 19c Ready"
  PERSONA_12: "Kafka Broker:TCP:9092:Kafka broker ready"
  PERSONA_13: "Redis:TCP:6379:+PONG"
  PERSONA_14: "MongoDB:TCP:27017:MongoDB ready"
```

**Format:** `"Display Name:PROTOCOL:PORT:Optional Banner"`

**Supported protocols:** `SQL`, `POSTGRES`, `FTP`, `RABBITMQ`, `HANA`, `WEBMETHODS`, `SMB`, `BTP`, `AMQP`, `TCP`

Redeploy VM B after changes:

```bash
cd ~/AzureSphere/simulator
sudo docker-compose build --no-cache persona-api
sudo docker-compose up -d
```

---

## AS2 Exchange — B2B Integration Validation

AzureSphere implements a lightweight AS2-over-HTTP message exchange between VM A and VM B, validating the full B2B integration path used in production EDI workflows.

### How It Works

1. On VM A, open the **AS2 Exchange** tab
2. Enter VM B's IP, a Subject and message Body (EDI/X12 997 sample pre-filled)
3. Click **Send AS2 Message**
4. VM A's agent POSTs the message to VM B's `/as2/receive` endpoint
5. VM B stores the message and returns a signed **MDN receipt** (disposition, message-ID, timestamp)
6. The MDN receipt is displayed on VM A immediately
7. On VM B's dashboard, the **AS2 Inbox** shows all received messages in real time

### AS2 Endpoints (VM B — port 9090)

| Endpoint | Method | Description |
|---|---|---|
| `/as2/receive` | POST | Receive AS2 message, return MDN receipt |
| `/as2/messages` | GET | List all received messages |
| `/as2/clear` | POST | Clear the AS2 inbox |

---

## Agent API Reference (VM A)

The Go diagnostic agent runs at `http://[VM-A-IP]:8080` and is proxied via nginx at `https://[VM-A-IP]/api/`.

| Endpoint | Method | Parameters | Description |
|---|---|---|---|
| `/api/info` | GET | — | Agent version, hostname, OS, uptime |
| `/api/test/tcp` | POST | `host`, `port` | TCP connect with latency measurement |
| `/api/test/tls` | POST | `host`, `port` | TLS handshake + full certificate chain |
| `/api/test/dns` | POST | `host` | DNS resolution + split-brain detection |
| `/api/test/ping` | POST | `host` | ICMP ping (4 packets) with fallback to TCP RTT |
| `/api/as2/send` | POST | `host` (query) | Send AS2 message to VM B |
| `/api/vmb/messages` | GET | `host` (query) | Proxy VM B AS2 inbox |
| `/api/vmb/clear` | POST | `host` (query) | Clear VM B AS2 inbox |
| `/health` | GET | — | Health check |

**Examples:**

```bash
# TCP connectivity test
curl "https://[VM-A-IP]/api/test/tcp?host=[VM-B-IP]&port=1433"

# TLS certificate inspection
curl "https://[VM-A-IP]/api/test/tls?host=storage.blob.core.windows.net&port=443"

# DNS resolution
curl "https://[VM-A-IP]/api/test/dns?host=storage.blob.core.windows.net"

# Send AS2 message
curl -X POST "https://[VM-A-IP]/api/as2/send?host=[VM-B-IP]" \
  -H "Content-Type: application/json" \
  -d '{"from":"vma","to":"vmb","subject":"Connectivity Validation","body":"ISA*00*...*~"}'
```

---

## Persona API Reference (VM B)

| Endpoint | Method | Description |
|---|---|---|
| `/api/status` | GET | Hostname, uptime, persona count, total connections |
| `/api/personas` | GET | All active service personas with protocol and port |
| `/api/connections` | GET | Live connection log (last 500 entries) |
| `/api/connections/reset` | POST | Clear the connection log |
| `/as2/receive` | POST | Receive AS2 message, return MDN |
| `/as2/messages` | GET | List received AS2 messages |
| `/as2/clear` | POST | Clear AS2 inbox |
| `/health` | GET | Health check |

---

## SSL Certificates

Both VMs auto-generate self-signed certificates on first deploy (825-day validity). To replace with a CA-issued certificate:

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

**Dashboard shows "Agent Offline"**
```bash
cd ~/AzureSphere
sudo docker-compose ps
sudo docker-compose logs agent
curl http://localhost:8080/api/info
```

**VM B connection log empty after running tests**
Port 443 connects to the nginx dashboard, not the persona API — this is expected. Test against persona ports (1433, 5432, 8080, etc.) to generate connection log entries.

**Docker networking error after VM reset**
```bash
sudo systemctl restart docker
cd ~/AzureSphere/simulator
sudo docker-compose up -d
```

**Persona containers not starting after redeploy**
```bash
cd ~/AzureSphere/simulator
sudo docker-compose build --no-cache persona-api
sudo docker-compose down && sudo docker-compose up -d
```

**SAP BTP tests returning JSON parse errors**
Confirm VM B is running and port 8080 is open in the Azure NSG inbound rules for VM B.

---

## Security Posture

AzureSphere is a **read-only diagnostic platform**. It makes no configuration changes to any target system. All VM B persona listeners are non-destructive TCP responders that accept a connection, send a protocol-appropriate banner, and close. No data is written to target systems and no credentials are stored or transmitted.

Recommended deployment pattern: spin up both VMs in a **dedicated diagnostic subnet** within your Azure VNet, run your connectivity validation, export the Test Log CSV, then deallocate the VMs. Total infrastructure cost for a validation exercise is typically under $2.

---

## Related Tools

**[SSL-CheckTool](https://github.com/HashimsGitHub/SSL-CheckTool)** — PowerShell enterprise HTTPS diagnostic tool by the same author. AzureSphere's TLS inspector is built on the same staged validation approach: DNS resolution → TCP connectivity → TLS handshake → OS trust validation → certificate chain → legacy TLS audit.

---

## Author

**Hashim Hilal** — Azure Architect

---

*AzureSphere is open source and provided as-is for diagnostic and validation purposes. It is not a monitoring platform and does not retain data between sessions.*
