# AzureSphere — Enterprise Connectivity Diagnostic Platform

> **Validate real-world enterprise application connectivity between cloud hosts — before you deploy. Eliminate integration failures, reduce go-live risk, and accelerate enterprise cloud migrations.**

---

## Why AzureSphere?

Enterprise cloud migrations fail at integration — not infrastructure. Network Security Groups, Private Endpoints, DNS resolution, TLS certificate chains, and protocol-level handshakes all behave differently in Azure than on-premises. AzureSphere gives Cloud Architects and Platform Engineers a live, protocol-accurate diagnostic environment to **prove connectivity works** before middleware, databases, and integration platforms are deployed.

It simulates the exact conditions of a production enterprise landscape: a source host (VM A) that needs to reach a portfolio of destination services (VM B) across SQL, messaging, FTP, SAP, EDI, and custom TCP protocols — with real TLS inspection, real DNS resolution, and real AS2 message exchange.

### Business Benefits

| Challenge | AzureSphere Solution |
|---|---|
| **Migration risk** — connectivity failures discovered post-go-live | Validate every protocol and port before cutover |
| **NSG misconfiguration** — rules look correct but traffic is blocked | Real TCP connect tests confirm traffic flows end-to-end |
| **TLS failures** — expired or untrusted certificates in new environments | Full certificate chain inspection with security grading and expiry alerts |
| **DNS split-brain** — FQDNs resolve differently inside and outside Azure VNets | Split-brain detection and Azure Private DNS zone awareness |
| **SAP BTP integration readiness** — uncertain whether Integration Suite and Event Mesh are reachable | Dedicated SAP BTP tab tests all BTP service endpoints with live results |
| **AS2/EDI connectivity** — B2B integration requires end-to-end message delivery proof | Live AS2 exchange with MDN receipt confirmation |
| **Audit and compliance** — no record of pre-go-live connectivity validation | Exportable Test Log (CSV) captures every test with timestamp, result, and latency |

---

## Platform Architecture

```
Source Host (VM A)                         Destination Host (VM B)
┌──────────────────────────────┐           ┌──────────────────────────────┐
│  AzureSphere Dashboard       │──TCP────▶ │  SQL Server 2022    :1433    │
│  (TLS · https://VMA-IP)      │──TCP────▶ │  PostgreSQL 16      :5432    │
│                              │──FTP────▶ │  FTP Server         :21      │
│  Go Diagnostic Agent :8080   │──AMQP───▶ │  RabbitMQ 3.12      :5672    │
│  ├─ TCP connect + latency    │──TLS────▶ │  HTTPS/TLS          :8443    │
│  ├─ TLS handshake + cert     │──HANA───▶ │  SAP HANA           :30015   │
│  ├─ DNS resolution           │──HTTP───▶ │  webMethods IS      :5555    │
│  ├─ ICMP / TCP ping          │──SMB────▶ │  SMB / Azure Files  :445     │
│  ├─ AS2 message exchange     │──SFTP───▶ │  SFTP               :2222    │
│  └─ SAP BTP connectivity     │──BTP────▶ │  SAP BTP Suite      :8080    │
└──────────────────────────────┘──AMQP───▶ │  SAP Event Mesh     :5671    │
         ▲                                 └──────────────────────────────┘
         │                                              ▲
    Engineering Team                            Engineering Team
  https://VMA-IP                              https://VMB-IP
```

Both dashboards are served over HTTPS with auto-generated SSL certificates. No public internet access is required between VMs — all tests run across private Azure VNet connectivity.

---

## Screenshots

### Source Host — Digital Twin · Enterprise Connectivity Diagnostic

<img width="1172" height="845" alt="image" src="https://github.com/user-attachments/assets/a173a52e-1974-4bbf-a547-b9c7ba2d6312" />
<img width="1750" height="887" alt="image" src="https://github.com/user-attachments/assets/692976b2-39a0-4c32-a150-ba86d61070f9" />
<img width="1767" height="790" alt="image" src="https://github.com/user-attachments/assets/437857ed-3729-4dc1-9da6-af6ee14e12de" />
<img width="1776" height="567" alt="image" src="https://github.com/user-attachments/assets/04db2997-0735-42f6-a9bf-b9485c5f0041" />
<img width="820" height="915" alt="image" src="https://github.com/user-attachments/assets/332ec7db-c333-4c34-9b6a-d6da90202cc5" />
<img width="1405" height="910" alt="image" src="https://github.com/user-attachments/assets/faa9f950-9ec1-4140-b6e9-c26d0a884df4" />

### Destination Host — Enterprise Service Endpoint · Multi-Protocol Listener

<img width="1378" height="739" alt="image" src="https://github.com/user-attachments/assets/3674c21e-32a1-459d-b382-e5c3bc9e0287" />
<img width="1372" height="856" alt="image" src="https://github.com/user-attachments/assets/69e779b5-7aba-48fd-a89a-6ac984159575" />
<img width="1381" height="595" alt="image" src="https://github.com/user-attachments/assets/31698d97-e6ac-4566-a7bf-082f5df1f364" />

---

## Feature Reference

### Source Host Dashboard (VM A)

#### Connectivity Tab
Validates TCP-level reachability to any IP or FQDN and port with real latency measurement. Supports multi-target testing with persistent target cards showing pass/fail state and response time.

| Protocol | Default Port | Use Case |
|---|---|---|
| HTTPS | 443 | Web services, REST APIs |
| SFTP | 2222 | Secure file transfer |
| SQL Server | 1433 | Microsoft SQL Server, Azure SQL |
| RabbitMQ | 5672 | AMQP message broker |
| SMB | 445 | File shares, Azure Files |
| SAP HANA | 30015 | SAP HANA database |
| TCP | Custom | Any custom application port |

#### TLS / Certificate Inspector
Production-grade TLS analysis aligned with enterprise SSL audit standards:

- Security grading: **A** (strong) · **B** (advisory) · **C** (deprecated) · **F** (expired / critical)
- Full certificate chain: Leaf → Intermediate → Root CA
- Subject, Issuer, Thumbprint, Serial Number, Valid From/To, Days Remaining
- Subject Alternative Names (SANs)
- OS trust store validation
- Legacy TLS audit: TLS 1.0 / 1.1 / 1.2 / 1.3 detection
- Certificate downloads: `.pem` (leaf, chain, root)

#### DNS Tab
Enterprise DNS validation for hybrid and cloud environments:

- FQDN to IP resolution with latency measurement
- **Split-brain DNS detection** — identifies when internal and external resolution differ
- **Azure Private DNS zone awareness** — flags Azure-specific FQDNs (`.blob.core.windows.net`, `.privatelink.*`, etc.)
- Private vs public IP classification

#### Ping / Latency
- 4-packet ICMP ping with min/avg/max RTT and packet loss percentage
- Automatic fallback to TCP RTT when ICMP is blocked by NSG rules

#### AS2 Exchange Tab
Full AS2-over-HTTP B2B message exchange simulation:

- Compose and send AS2 messages to VM B with custom Subject and Body
- Pre-filled with a valid EDI/X12 sample payload
- MDN receipt rendered after send: Status, Disposition, Message-ID, Timestamp
- Confirms end-to-end AS2 delivery before connecting production EDI systems

#### SAP BTP Tab
Dedicated connectivity validation for SAP Business Technology Platform services:

| Service | Port | Protocol | Description |
|---|---|---|---|
| Integration Suite | 8080 | BTP/HTTP | OData, REST, SOAP iFlow endpoints |
| Event Mesh | 5671 | AMQP/TLS | Messaging service connectivity |
| CF API / OAuth | 443 | HTTPS | Cloud Foundry API, XSUAA token service |
| HANA Cloud | 30015 | HANA SQL | SAP HANA Cloud database port |
| Cloud Connector | 8443 | HTTPS Tunnel | SAP Cloud Connector reverse tunnel |

Each service test returns reachability status, latency, and full error detail.

#### Test Log
Persistent session log accessible from the header bar on every tab:

- Captures every test across all tabs: Connectivity, TLS, DNS, AS2, SAP BTP
- Columns: Timestamp · Test Type · Target · Port · Protocol · Result · Latency · Detail
- Live entry count badge on the header button
- **Export to CSV** — opens directly in Excel; suitable for migration sign-off documentation and audit trails
- Clear button for session reset

---

### Destination Host Dashboard (VM B)

#### Active Services Panel
Real-time view of all simulated service endpoints with connection hit counts and last-seen timestamps. Auto-refreshes every 5 seconds.

#### Live Connection Log
Scrollable, auto-refreshing log of all inbound connections from VM A. Confirms that traffic is arriving at the correct port and protocol. Includes pause/resume and clear controls.

#### Add New Service
Generate docker-compose configuration for any additional protocol persona inline — no manual file editing required.

#### AS2 Inbox
Real-time inbox of all AS2 messages received from VM A. Displays Message-ID, subject, sender, body, and timestamp. Auto-refreshes every 5 seconds.

---

## Supported Service Personas (VM B)

| # | Service | Protocol | Port | Simulates |
|---|---|---|---|---|
| 1 | SQL Server 2022 | SQL/TDS | 1433 | Microsoft SQL Server, Azure SQL Database |
| 2 | PostgreSQL 16 | PostgreSQL | 5432 | PostgreSQL, Azure Database for PostgreSQL |
| 3 | FTP Server | FTP | 21 | Legacy FTP file transfer |
| 4 | RabbitMQ 3.12 | AMQP 0-9-1 | 5672 | RabbitMQ, Azure Service Bus (AMQP) |
| 5 | SAP HANA | HANA SQL | 30015 | SAP HANA on-premises and cloud |
| 6 | webMethods IS | HTTP | 5555 | Software AG webMethods Integration Server |
| 7 | SMB / Azure Files | SMB | 445 | Windows file shares, Azure Files |
| 8 | Custom TCP App | TCP | 8888 | Any generic TCP application |
| 9 | SAP BTP Integration Suite | BTP/HTTP | 8080 | SAP Integration Suite iFlow endpoints |
| 10 | SAP Event Mesh | AMQP/TLS | 5671 | SAP Event Mesh messaging service |

Additional personas can be added without code changes — see [Adding a New Service Persona](#adding-a-new-service-persona).

---

## Quick Start

### Prerequisites

- Two Ubuntu 22.04 VMs in Azure (B1s or larger)
- Inbound NSG rules configured — see [Port Reference](#port-reference)
- Git installed on both VMs

### Deploy VM A (Source Host)

```bash
git clone https://github.com/HashimsGitHub/AzureSphere.git
cd AzureSphere
bash start-vma.sh
```

Open: `https://[VM-A-IP]`

### Deploy VM B (Destination Host)

```bash
git clone https://github.com/HashimsGitHub/AzureSphere.git
cd AzureSphere/simulator
bash start-vmb.sh
```

Open: `https://[VM-B-IP]`

Both scripts handle all dependencies, Docker setup, SSL certificate generation, and container orchestration automatically. No manual configuration required.

### Branch Deployments

To deploy a specific branch for testing or staging:

```bash
bash start-vma.sh --branch feature/my-branch
bash start-vmb.sh --branch feature/my-branch
```

---

## Repository Structure

```
AzureSphere/
├── index.html                    # VM A dashboard (source host)
├── docker-compose.yml            # VM A container orchestration
├── start-vma.sh                  # VM A one-command deploy script
├── start.sh                      # Interactive launcher
├── agent/
│   ├── main.go                   # Go diagnostic agent — TCP/TLS/DNS/ping/AS2
│   ├── go.mod
│   └── Dockerfile
└── simulator/
    ├── docker-compose.yml        # VM B container orchestration
    ├── start-vmb.sh              # VM B one-command deploy script
    ├── nginx/
    │   ├── conf/default.conf     # VM B nginx — API proxy config
    │   └── html/index.html       # VM B dashboard (destination host)
    └── personas/
        ├── main.go               # Go persona server — multi-protocol listeners + AS2
        ├── go.mod
        └── Dockerfile
```

---

## Port Reference

### VM A — Source Host Inbound Rules

| Port | Protocol | Purpose |
|---|---|---|
| 443 | TCP | AzureSphere dashboard (HTTPS) |
| 80 | TCP | HTTP → HTTPS redirect |
| 22 | TCP | SSH administration |
| 2222 | TCP | SFTP test endpoint |

### VM B — Destination Host Inbound Rules

| Port | Protocol | Purpose |
|---|---|---|
| 443 | TCP | AzureSphere dashboard (HTTPS) |
| 22 | TCP | SSH administration |
| 1433 | TCP | SQL Server persona |
| 5432 | TCP | PostgreSQL persona |
| 21 | TCP | FTP persona |
| 5672 | TCP | RabbitMQ persona |
| 30015 | TCP | SAP HANA persona |
| 5555 | TCP | webMethods IS persona |
| 2222 | TCP | SFTP persona |
| 8443 | TCP | HTTPS/TLS persona |
| 445 | TCP | SMB / Azure Files persona |
| 8888 | TCP | Custom TCP persona |
| 8080 | TCP | SAP BTP Integration Suite persona |
| 5671 | TCP | SAP Event Mesh persona |
| 9090 | TCP | Persona API + AS2 inbox (VM A source only) |

> **Security note:** Restrict port 9090 on VM B to VM A's private IP in the NSG. All other persona ports should be restricted to VM A's subnet.

---

## Adding a New Service Persona

Edit `simulator/docker-compose.yml` under `persona-api → environment`:

```yaml
PERSONA_11: "Oracle DB:TCP:1521:Oracle Database 19c Ready"
PERSONA_12: "Kafka Broker:TCP:9092:Kafka broker ready"
PERSONA_13: "Redis Cache:TCP:6379:+PONG"
PERSONA_14: "MongoDB:TCP:27017:MongoDB ready"
```

**Format:** `"Display Name:PROTOCOL:PORT:Optional Banner"`

**Supported protocols:** `SQL` · `POSTGRES` · `FTP` · `RABBITMQ` · `HANA` · `WEBMETHODS` · `SMB` · `BTP` · `AMQP` · `TCP`

Redeploy after adding:

```bash
cd ~/AzureSphere/simulator
sudo docker-compose build --no-cache persona-api
sudo docker-compose up -d --force-recreate persona-api
```

Alternatively, use the **Add New Service** panel in the VM B dashboard to generate the config snippet automatically.

---

## Agent API Reference (VM A)

The Go agent runs internally on port 8080 and is proxied via nginx at `https://[VM-A-IP]/api/`.

| Endpoint | Method | Parameters | Description |
|---|---|---|---|
| `/api/info` | GET | — | Agent version, hostname, OS, uptime |
| `/api/test/tcp` | GET/POST | `host`, `port` | TCP connect with latency measurement |
| `/api/test/tls` | GET/POST | `host`, `port` | TLS handshake and full certificate chain |
| `/api/test/dns` | GET/POST | `host` | DNS resolution with split-brain detection |
| `/api/test/ping` | GET/POST | `host` | ICMP ping (4 packets) with RTT statistics |
| `/api/as2/send` | POST | `host` (query) + JSON body | Send AS2 message to VM B |
| `/api/vmb/messages` | GET | `host` (query) | Retrieve VM B AS2 inbox |
| `/api/vmb/clear` | POST | `host` (query) | Clear VM B AS2 inbox |
| `/health` | GET | — | Agent health check |

**Usage examples:**

```bash
# TCP connectivity test
curl "http://[VM-A-IP]:8080/api/test/tcp?host=[VM-B-IP]&port=1433"

# TLS certificate inspection
curl "http://[VM-A-IP]:8080/api/test/tls?host=your-domain.com&port=443"

# DNS resolution
curl "http://[VM-A-IP]:8080/api/test/dns?host=storage.blob.core.windows.net"

# Send AS2 message to VM B
curl -X POST "http://[VM-A-IP]:8080/api/as2/send?host=[VM-B-IP]" \
  -H "Content-Type: application/json" \
  -d '{"from":"vma","to":"vmb","subject":"Connectivity Test","body":"ISA*00*...*~"}'
```

---

## Persona API Reference (VM B)

| Endpoint | Method | Description |
|---|---|---|
| `/api/status` | GET | Hostname, uptime, persona count, total connection count |
| `/api/personas` | GET | All active service personas with port and protocol |
| `/api/connections` | GET | Live inbound connection log (last 500 entries) |
| `/api/connections/reset` | POST | Clear the connection log |
| `/as2/receive` | POST | Accept AS2 message and return MDN receipt |
| `/as2/messages` | GET | List all received AS2 messages |
| `/as2/clear` | POST | Flush the AS2 inbox |
| `/health` | GET | Health check |

---

## AS2 Exchange — Technical Detail

AzureSphere implements AS2-over-HTTP message exchange between VM A and VM B, suitable for validating B2B and EDI integration paths in Azure before connecting production systems.

**Message flow:**

1. Engineer opens the **AS2 Exchange** tab on VM A
2. Enters VM B IP, Subject, and message Body (EDI/X12 sample pre-filled)
3. VM A's agent POSTs the message to `http://[VM-B-IP]:9090/as2/receive`
4. VM B stores the message and returns an MDN receipt (disposition, message-ID, timestamp)
5. The MDN receipt is displayed on VM A — confirming end-to-end delivery
6. VM B's **AS2 Inbox** panel shows all received messages in real time

---

## SSL Certificates

Both VMs auto-generate self-signed certificates (825-day validity) on first deployment. To replace with a CA-issued certificate:

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

**Dashboard shows "Agent offline"**
```bash
cd ~/AzureSphere
sudo docker-compose ps                  # confirm all containers are running
sudo docker-compose logs agent          # review agent startup errors
curl http://localhost:8080/api/info     # test agent directly
```

**VM B connection log empty after running tests**
Port 443 connects to the nginx dashboard container, not the persona API. Test against persona ports (1433, 5432, 5672, etc.) to generate entries in the live connection log.

**SAP BTP connectivity test returns an error**
Confirm ports 8080 and 5671 are open in VM B's NSG inbound rules and that the `persona-api` container is running:
```bash
cd ~/AzureSphere/simulator
sudo docker-compose ps
curl http://localhost:9090/api/personas
```

**AS2 returns 404 after redeploy**
The persona-api image may be cached from a prior build. Force a clean rebuild:
```bash
cd ~/AzureSphere/simulator
sudo docker-compose build --no-cache persona-api
sudo docker-compose down && sudo docker-compose up -d
```

**Docker networking fails after VM reset or cleanup**
If a cleanup script removes network interfaces:
```bash
sudo systemctl restart docker
docker network prune -f
```

---

## Related Tools

**[SSL-CheckTool](https://github.com/HashimsGitHub/SSL-CheckTool)** — PowerShell enterprise HTTPS diagnostic tool by the same author. AzureSphere's TLS inspector is architecturally aligned with SSL-CheckTool's staged approach: DNS → TCP → TLS handshake → trust validation → certificate chain → legacy TLS audit.

---

## Author

**Hashim Hilal** — Azure Architect

---

*AzureSphere is a read-only diagnostic platform. No configuration changes are made to target systems. All persona listeners are non-destructive TCP responders that accept connections and return protocol-appropriate banners.*
