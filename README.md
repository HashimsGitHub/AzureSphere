# AzureSphere — Enterprise Connectivity Diagnostic Platform

> **Validate real-world enterprise application connectivity between cloud hosts — before you deploy. Eliminate integration failures, reduce go-live risk, and accelerate enterprise cloud migrations.**

---

## Why AzureSphere?

Enterprise cloud migrations fail at integration — not infrastructure. Network Security Groups, Private Endpoints, DNS resolution, TLS certificate chains, and protocol-level handshakes all behave differently in Azure than on-premises. AzureSphere gives Cloud Architects and Platform Engineers a live, protocol-accurate diagnostic environment to **prove connectivity works** before middleware, databases, and integration platforms are deployed.

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
│  Go Diagnostic Agent         │──AMQP───▶ │  RabbitMQ 3.12      :5672    │
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

## What's Inside

### Source Host (VM A) — Diagnostic Command Centre

**Connectivity Testing**
Prove that every application port is reachable before go-live. Multi-target testing with persistent pass/fail cards and real latency measurement across HTTPS, SFTP, SQL, RabbitMQ, SMB, SAP HANA, and custom TCP.

**TLS / Certificate Intelligence**
Enterprise-grade TLS analysis with security grading (A through F), full certificate chain visibility (Leaf → Intermediate → Root CA), expiry countdown, Subject Alternative Names, and OS trust store validation. Export certificates as `.pem` files. Identify weak ciphers and deprecated TLS versions before they cause production incidents.

**DNS Validation**
Eliminate DNS as a source of migration failure. Detect split-brain DNS conditions where FQDNs resolve to different addresses inside and outside the Azure VNet. Identify Azure Private DNS zones automatically.

**SAP BTP Connectivity**
A dedicated tab purpose-built for SAP cloud migrations. Validate reachability to SAP Integration Suite, SAP Event Mesh, Cloud Foundry API, HANA Cloud, and SAP Cloud Connector — all from a single interface with live status cards and latency results per service.

**AS2 / EDI Exchange**
Prove end-to-end B2B message delivery before connecting production EDI systems. Send a real AS2 message to the destination host and receive a signed MDN acknowledgement — confirming the full integration path works.

**Test Log with CSV Export**
Every test run across every tab is captured automatically — Connectivity, TLS, DNS, AS2, SAP BTP. A live counter badge in the header shows activity at a glance. Export the full log to CSV for Excel analysis, migration sign-off documentation, and compliance audit trails.

---

### Destination Host (VM B) — Enterprise Service Simulator

**10 Protocol Personas — Running Simultaneously**

| Service | Protocol | Port | Simulates |
|---|---|---|---|
| SQL Server 2022 | SQL/TDS | 1433 | Microsoft SQL Server, Azure SQL Database |
| PostgreSQL 16 | PostgreSQL | 5432 | PostgreSQL, Azure Database for PostgreSQL |
| FTP Server | FTP | 21 | Legacy FTP file transfer |
| RabbitMQ 3.12 | AMQP 0-9-1 | 5672 | RabbitMQ, Azure Service Bus |
| SAP HANA | HANA SQL | 30015 | SAP HANA on-premises and cloud |
| webMethods IS | HTTP | 5555 | Software AG webMethods Integration Server |
| SMB / Azure Files | SMB | 445 | Windows file shares, Azure Files |
| Custom TCP App | TCP | 8888 | Any generic TCP application |
| SAP BTP Integration Suite | BTP/HTTP | 8080 | SAP Integration Suite iFlow endpoints |
| SAP Event Mesh | AMQP/TLS | 5671 | SAP Event Mesh messaging service |

**Live Connection Dashboard**
Real-time visibility into every inbound connection from the source host — protocol, source IP, port, and timestamp. Confirms that traffic is flowing and reaching the right service. Auto-refreshes every 5 seconds.

**AS2 Inbox**
A live inbox that captures every AS2 message received from the source host, with message ID, subject, sender, body, and timestamp. Confirms B2B message delivery end-to-end.

**Add New Service**
Extend the platform to any additional port or application without writing code. The built-in config generator produces ready-to-use docker-compose snippets for any custom persona.

---

## Supported Protocols

`SQL` · `PostgreSQL` · `FTP` · `AMQP / RabbitMQ` · `HANA` · `webMethods` · `SMB` · `SFTP` · `HTTPS / TLS` · `AS2` · `SAP BTP` · `SAP Event Mesh` · `Custom TCP`

---

## Quick Start

### Deploy VM A (Source Host)

```bash
git clone https://github.com/HashimsGitHub/AzureSphere.git
cd AzureSphere
bash start-vma.sh
```

Open `https://[VM-A-IP]`

### Deploy VM B (Destination Host)

```bash
git clone https://github.com/HashimsGitHub/AzureSphere.git
cd AzureSphere/simulator
bash start-vmb.sh
```

Open `https://[VM-B-IP]`

Both scripts are fully automated — dependencies, Docker, SSL certificates, and container orchestration are handled without any manual configuration.

---

## Prerequisites

- Two Ubuntu 22.04 VMs in Azure (B1s or larger)
- Azure NSG inbound rules open for the relevant ports on each VM
- Git installed on both VMs

---

## Port Reference

### VM A — Source Host

| Port | Purpose |
|---|---|
| 443 | AzureSphere dashboard (HTTPS) |
| 80 | HTTP → HTTPS redirect |
| 22 | SSH administration |
| 2222 | SFTP test endpoint |

### VM B — Destination Host

| Port | Service |
|---|---|
| 443 | AzureSphere dashboard (HTTPS) |
| 1433 | SQL Server |
| 5432 | PostgreSQL |
| 21 | FTP |
| 5672 | RabbitMQ |
| 30015 | SAP HANA |
| 5555 | webMethods IS |
| 2222 | SFTP |
| 8443 | HTTPS/TLS |
| 445 | SMB / Azure Files |
| 8888 | Custom TCP |
| 8080 | SAP BTP Integration Suite |
| 5671 | SAP Event Mesh |
| 9090 | Persona API + AS2 (VM A source only) |
| 22 | SSH administration |

---

## Related Tools

**[SSL-CheckTool](https://github.com/HashimsGitHub/SSL-CheckTool)** — PowerShell enterprise HTTPS diagnostic tool by the same author. AzureSphere's TLS inspector is architecturally aligned with SSL-CheckTool's staged approach: DNS → TCP → TLS handshake → trust validation → certificate chain → legacy TLS audit.

---

## Author

**Hashim Hilal** — Azure Architect

---

*AzureSphere is a read-only diagnostic platform. No configuration changes are made to target systems. All persona listeners are non-destructive TCP responders.*
