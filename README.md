# Cyber Range Demo - Network Traversal Hunt

Lab simulasi **Red Team vs Blue Team** dengan skenario *network traversal*. User akses lab via **security distribution VM** (Kali/Parrot) yang udah disediakan platform melalui Guacamole. Lab ini cuma menyediakan **target environment** + **Wazuh stack** sebagai SIEM monitoring.

## Arsitektur

```
┌──────────────────────────────────────────────────────────────────┐
│  PLATFORM EXTERNAL (Guacamole + Jump Boxes)                      │
│                                                                  │
│  [Red User] ──────────> [Kali/Parrot VM]   (Red attacker)        │
│  [Blue User] ─────────> [Kali/Parrot VM]   (Blue defender)       │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │
        ┌──────────────────────┴──────────────────────┐
        │                                             │
        │  THIS LAB (Container-based)                 │
        │                                             │
        │  ┌─────────────────────────────────────┐   │
        │  │  Wazuh Stack                        │   │
        │  │  - Manager (1514, 1515, 55000)      │   │
        │  │  - Indexer (9200)                   │   │
        │  │  - Dashboard (443)  ◄──── Blue UI   │   │
        │  └─────────────────────────────────────┘   │
        │                                             │
        │  ┌─────────────────────────────────────┐   │
        │  │  TARGET LAB                         │   │
        │  │                                     │   │
        │  │  ┌────────────┐  ┌──────────────┐  │   │
        │  │  │ dmz-web    │  │ internal-app │  │   │
        │  │  │ 10.10.10.10│  │ 172.20.0.20  │  │   │
        │  │  │ Apache+PHP │  │ SSH server   │  │   │
        │  │  └────────────┘  └──────────────┘  │   │
        │  │                          │          │   │
        │  │                  ┌──────▼───────┐   │   │
        │  │                  │ db-server    │   │   │
        │  │                  │ 172.20.0.30  │   │   │
        │  │                  │ MySQL        │   │   │
        │  │                  └──────────────┘   │   │
        │  └─────────────────────────────────────┘   │
        └─────────────────────────────────────────────┘
```

## Skenario Attack Chain

```
[Recon] → [Initial Access] → [Discovery] → [Lateral Movement] → [Cred Access] → [Collection]
   ↓             ↓                ↓                ↓                  ↓              ↓
  nmap      RCE via PHP      enumerate       SSH dengan        cat .env file   mysqldump
            cmd injection    /var/www         leaked key       database.yml
                                             ke internal
```

**MITRE ATT&CK Coverage:**
- T1046 - Network Service Discovery
- T1190 - Exploit Public-Facing Application
- T1059 - Command and Scripting Interpreter
- T1082 - System Information Discovery
- T1083 - File and Directory Discovery
- T1552 - Unsecured Credentials
- T1021.004 - SSH Lateral Movement
- T1003 - OS Credential Dumping
- T1005 - Data from Local System

## Quick Start

### Prerequisites

- Linux host dengan **Docker** + **Docker Compose v2**
- Resource minimum: **8 GB RAM**, **4 vCPU**, **40 GB disk**
- Permission: bisa `sudo sysctl` (buat tuning Wazuh Indexer)

### Setup (Sekali jalan, ~5-10 menit)

```bash
cd cyber-range-demo
./setup.sh
```

Script ini bakal:
1. Generate SSH keys buat lateral movement scenario
2. Generate Wazuh self-signed certificates
3. Build target container images
4. Start Wazuh stack (Manager + Indexer + Dashboard)
5. Start target lab containers
6. Auto-enroll Wazuh agents

### Verify Setup

```bash
docker compose ps
```

Semua container harus `healthy` atau `running`. Wazuh Indexer butuh ~1 menit ready.

### Akses Dashboard

Buka browser dari Blue VM (security distro) atau host:

- **URL:** `https://<host-ip>:443`
- **User:** `admin`
- **Password:** `SecretPassword`

### Run Demo Attack

Dari Red VM (Kali/Parrot):

```bash
# Phase 1 - Recon
TARGET_IP=10.10.10.10 ./scripts/attack/01-recon.sh

# Phase 2 - Exploit
TARGET_IP=10.10.10.10 ATTACKER_IP=10.10.10.99 ./scripts/attack/02-exploit.sh

# Phase 3 - Lateral (manual di reverse shell)
./scripts/attack/03-lateral.sh
```

## Network Configuration

| Network | Subnet | Purpose |
|---------|--------|---------|
| `red_path` | 10.10.10.0/24 | Red Team attack surface (Kali harus reachable ke sini) |
| `internal_net` | 172.20.0.0/24 | Lateral movement target network |
| `wazuh_net` | 172.30.0.0/24 | Wazuh stack + agent telemetry |
| `blue_access` | 172.40.0.0/24 | Dashboard access dari Blue VM |

## Container Inventory

| Container | Networks | Exposed Ports | Wazuh Agent |
|-----------|----------|---------------|-------------|
| `wazuh-manager` | wazuh, blue, internal, red | 1514, 1515, 514/udp, 55000 | n/a (server) |
| `wazuh-indexer` | wazuh | 9200 | n/a |
| `wazuh-dashboard` | wazuh, blue | 443 | n/a |
| `dmz-web` | red, internal, wazuh | 80 (via 10.10.10.10) | yes |
| `internal-app` | internal, wazuh | 22 (internal only) | yes |
| `db-server` | internal, wazuh | 3306 (internal only) | yes |

## Documentation

- **`docs/DEMO-WALKTHROUGH.md`** - Step-by-step demo presentation script
- **`docs/BLUE-PLAYBOOK.md`** - Blue team detection playbook
- **`docs/TROUBLESHOOTING.md`** - Common issues & solutions
- **`docs/ARCHITECTURE.md`** - Detail teknis arsitektur
- **`docs/INTEGRATION.md`** - Cara integrasi dengan platform Guacamole

## Cleanup

```bash
docker compose down -v
```

Semua container, volume, network bakal dihapus.

## Reset (Buat Demo Ulang)

```bash
# Quick reset - hapus alert history tapi keep config
docker compose restart

# Full reset - bersih total
docker compose down -v
./setup.sh
```

## Credentials Cheat Sheet

| Service | User | Password | Note |
|---------|------|----------|------|
| Wazuh Dashboard | admin | SecretPassword | Default demo cred |
| Wazuh API | wazuh-wui | MyS3cr37P450r.*- | Backend API |
| MySQL root | root | Pr0d_DB_2024! | DB admin |
| MySQL appuser | appuser | AppDB_P@ssw0rd_2024 | App user |
| SSH internal-app | webapp | (key-based) | Pakai leaked key |

⚠️ **WARNING**: Demo credentials only. Jangan dipake di production.

## License & Disclaimer

Lab ini sengaja vulnerable untuk **edukasi cybersecurity**. Jangan deploy ke jaringan publik.
