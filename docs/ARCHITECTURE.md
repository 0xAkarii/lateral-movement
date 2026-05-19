# Architecture Documentation

## Overview

Cyber range ini didesain dengan **separation of concerns**:

1. **User Access Layer** (di-handle platform Guacamole) - di luar scope lab
2. **Security Distribution VMs** (Kali/Parrot) - tooling Red & Blue user
3. **SIEM Layer** (Wazuh stack) - container, deployable di lab
4. **Target Layer** (vulnerable services) - container, scenario-specific

Pattern ini **separate skenario dari tooling**, sehingga sama tooling Red/Blue, banyak skenario bisa dibuat.

## Container Topology

```
                          [HOST DOCKER ENGINE]
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
   [WAZUH STACK]            [TARGET LAB]              [NETWORKS]
        │                         │                         │
   ├─wazuh-manager           ├─dmz-web                 ├─red_path
   ├─wazuh-indexer           ├─internal-app            ├─internal_net
   └─wazuh-dashboard         └─db-server               ├─wazuh_net
                                                       └─blue_access
```

## Network Design Rationale

### Why Multiple Networks?

**Real-world security principle:** segmentation. Mirror production architecture.

| Network | Purpose | Reachability |
|---------|---------|--------------|
| `red_path` | DMZ exposed to attacker | dmz-web ONLY (mimicking external-facing service) |
| `internal_net` | Internal corporate network | dmz-web, internal-app, db-server (lateral movement) |
| `wazuh_net` | Out-of-band telemetry channel | All targets push log here, isolated dari attack path |
| `blue_access` | Dashboard access | Wazuh manager + dashboard, accessible from blue VM |

### Attack Path Visualization

```
                                    ┌────────────────┐
                                    │  attacker      │
                                    │ (Kali via      │
                                    │  Guacamole)    │
                                    └────────┬───────┘
                                             │
                                  red_path   │ (10.10.10.0/24)
                                             ▼
                                    ┌────────────────┐
                                    │   dmz-web      │
                                    │  10.10.10.10   │
                                    │  172.20.0.10   │
                                    └────────┬───────┘
                                             │
                              internal_net   │ (172.20.0.0/24)
                                             │
                          ┌──────────────────┴──────────────────┐
                          │                                     │
                          ▼                                     ▼
                  ┌────────────────┐                  ┌────────────────┐
                  │  internal-app  │                  │   db-server    │
                  │  172.20.0.20   │                  │  172.20.0.30   │
                  └────────┬───────┘                  └────────┬───────┘
                           │                                   │
                           │       wazuh_net (172.30.0.0/24)   │
                           └──────────────┬────────────────────┘
                                          │
                                          ▼
                                 ┌────────────────┐
                                 │ wazuh-manager  │
                                 │ wazuh-indexer  │
                                 │ wazuh-dashboard│
                                 └────────────────┘
                                          │
                              blue_access  │ (172.40.0.0/24)
                                           │
                                           ▼
                                 ┌────────────────┐
                                 │  blue analyst  │
                                 │ (Parrot via    │
                                 │  Guacamole)    │
                                 └────────────────┘
```

### Why dmz-web Punya 4 Networks?

dmz-web join ke `red_path`, `internal_net`, `wazuh_net`, dan implicit access. Reasoning:

- `red_path` - exposed to attacker
- `internal_net` - bridge ke internal (realistic DMZ)
- `wazuh_net` - kirim log ke manager

internal-app dan db-server **gak punya** akses `red_path` - artinya attacker harus pivot via dmz-web (lateral movement). Ini design intentional untuk skenario.

---

## Wazuh Stack Architecture

### Component Roles

```
                      ┌─────────────┐
                      │   Agent     │
                      │ (di target) │
                      └──────┬──────┘
                             │ TCP 1514 (encrypted)
                             ▼
                      ┌─────────────┐
                      │  Manager    │
                      │ - decoder   │
                      │ - rules     │
                      │ - correlate │
                      └──────┬──────┘
                             │ filebeat → indexer
                             ▼
                      ┌─────────────┐
                      │  Indexer    │
                      │ (Opensearch)│
                      └──────┬──────┘
                             │ REST API
                             ▼
                      ┌─────────────┐
                      │  Dashboard  │
                      │  (Kibana)   │
                      └─────────────┘
```

### Data Flow

1. **Event generation** - Auditd / log file di target
2. **Local processing** - Wazuh agent baca, format, kirim
3. **Manager analysis** - decoder parse, rule match, generate alert
4. **Indexing** - filebeat ship ke indexer, store as JSON document
5. **Visualization** - Dashboard query indexer, render UI

### Custom Rule Pipeline

```
Raw Log                    Decoder                    Rule
"sshd: accept"     →       parse user/srcip    →     if pattern match → alert level X
                            extract fields
```

Custom rules di `wazuh/custom-rules/local_rules.xml`:
- Range: 100100-100199
- Mapped to MITRE ATT&CK
- Levels: 5 (info) → 15 (critical)

---

## Container Image Strategy

### Base Image Decisions

**Ubuntu 22.04** dipakai karena:
- Wazuh agent official package available
- Auditd well-supported
- Familiar untuk demo audience
- Stable LTS

**Alternative (future):** Alpine + custom Wazuh agent build = smaller image, faster startup.

### Multi-stage Build (Optional Optimization)

Saat ini single-stage build. Future bisa multi-stage:

```dockerfile
# Stage 1: Build dependencies
FROM ubuntu:22.04 as builder
RUN apt-get update && apt-get install -y build-deps
RUN compile_app

# Stage 2: Runtime
FROM ubuntu:22.04
COPY --from=builder /opt/app /opt/app
```

Benefit: smaller final image, faster pull saat scaling.

### Image Build Time

| Image | Build Time | Image Size |
|-------|-----------|-----------|
| dmz-web | ~3 min | ~350 MB |
| internal-app | ~3 min | ~320 MB |
| db-server | ~5 min | ~520 MB |
| wazuh stack | (pull only) | ~2 GB total |

**Optimization:** Pre-build images dan push ke registry private buat speed up deployment.

---

## Wazuh Agent Auto-Enrollment

### Mechanism

```
Container Start
      ↓
Read $WAZUH_MANAGER env var
      ↓
Modify /var/ossec/etc/ossec.conf (replace address)
      ↓
Run /var/ossec/bin/agent-auth -m <manager> -A <name> -G <groups>
      ↓
Manager (authd on port 1515) issues client.keys
      ↓
Agent starts, connects to manager port 1514
      ↓
Begin log streaming
```

### Per-Container Identity

Setiap container punya unique `WAZUH_AGENT_NAME`:
- `dmz-web`
- `internal-app`
- `db-server`

Group assignment buat policy:
- `scenario-net-traversal` - common rules untuk skenario
- `dmz` / `internal` / `database` - role-based config

---

## Volume & Persistence

### Persistent Volumes

| Volume | Purpose | Reset Behavior |
|--------|---------|----------------|
| `wazuh_etc` | Manager config | Persist on restart, wipe on `down -v` |
| `wazuh_logs` | Manager logs | Persist |
| `wazuh_indexer_data` | Index data | Persist (BIG) |
| `filebeat_var` | Filebeat state | Persist |

### Why Bind Mounts vs Named Volumes?

**Bind mounts** (`./wazuh/custom-rules:/var/ossec/etc/rules.custom`):
- Editable from host
- Easy buat development/iteration
- Pakai buat config files

**Named volumes** (`wazuh_indexer_data`):
- Better performance (overlay vs bind)
- Less permission issues
- Pakai buat data persistence

---

## Security Considerations

### Lab vs Production

⚠️ **Lab ini SENGAJA insecure**:
- Default credentials di banyak tempat
- SSH key sengaja "leaked"
- Vulnerable web app (command injection)
- Service health checker bisa diakal
- Self-signed certs

### Production Hardening Checklist (Future)

Kalau pattern ini dipakai buat real lab:

- [ ] Generate proper certs dari trusted CA
- [ ] Random unique credentials per session
- [ ] Network policy enforcement (Kubernetes)
- [ ] Resource limits per container
- [ ] Log shipping ke external SIEM (multi-tenant aware)
- [ ] Secrets management (Vault, K8s secrets)
- [ ] Image scanning (Trivy, Grype)
- [ ] Egress firewall (block C2 to real internet)

---

## Resource Sizing

### Minimum (Demo)
- 8 GB RAM, 4 vCPU, 40 GB disk
- Single host
- 1-2 user concurrent

### Recommended (10 user)
- 32 GB RAM, 8 vCPU, 200 GB SSD
- Single host
- Dedicate 16 GB ke Wazuh Indexer

### Per-Component Estimate

| Component | RAM | CPU |
|-----------|-----|-----|
| wazuh-manager | 512 MB - 1 GB | 0.5 |
| wazuh-indexer | 2 GB (heap) + 1 GB (overhead) | 1 |
| wazuh-dashboard | 512 MB | 0.3 |
| dmz-web | 256 MB | 0.2 |
| internal-app | 256 MB | 0.2 |
| db-server | 512 MB | 0.3 |
| **TOTAL** | ~5 GB | ~2.5 |

Buffer 50% buat OS dan headroom = **8 GB minimum**.

---

## Future Extensions

### Multi-Scenario Support

Pattern: 1 docker-compose per skenario, share Wazuh stack:

```
scenarios/
├── 01-network-traversal/
│   ├── docker-compose.yml
│   ├── targets/
│   └── rules/
├── 02-supply-chain-attack/
└── 03-ransomware-simulation/
```

### Multi-Tenant (Production)

Untuk 20+ user concurrent:
- Pisahkan Wazuh Indexer ke dedicated host
- Per-session blue VM dengan filter view
- Index template `wazuh-alerts-session-${ID}`
- RBAC per session di OpenSearch

### Scoring Engine Integration

Service tambahan:
- `scoring-api` - Flask app, validate flag/IOC
- `service-checker` - HTTP health check, deduct points
- `flag-rotator` - cron job rotate flags every N minutes
