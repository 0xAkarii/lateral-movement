# Blue Team Detection Playbook

Panduan buat Blue Team analyst saat menjalankan skenario network traversal hunt.

## Mindset

Lo adalah **SOC Analyst + Threat Hunter + Incident Responder**. Tujuan:

1. **Detect** attack secepat mungkin
2. **Investigate** scope kompromi
3. **Contain** tanpa matiin service legit
4. **Evict** attacker
5. **Report** dengan timeline akurat

## Phase 1: Detection - Initial Recon

### Indicator
- Massive port scan dari single IP
- Web access log dengan unusual user-agent

### Hunt Query (Wazuh Discover)
```
data.srcip:10.10.10.99 OR data.srcip:NOT 192.168.0.0/16
```

### Action
- Note source IP attacker
- Submit ke scoring API: `IOC: <attacker_ip>`
- Standby buat phase berikutnya

---

## Phase 2: Detection - Initial Access (RCE)

### Indicator
- Web access log: parameter aneh (`cmd=`, `;id`, `|nc`)
- Auditd alert: shell spawn dari `apache2` / `nginx` parent
- Wazuh rule: 100110, 100111, 100120, 100121

### Hunt Query
```
rule.groups:initial_access AND agent.name:dmz-web
```

Atau cari command injection patterns:
```
data.url:*cmd=* OR data.url:*;id* OR data.url:*\\.\\./*
```

### Hunt Process Tree
```
rule.id:100120 OR rule.id:100121
```

Klik alert → liat field:
- `data.audit.ppid` → parent process (harus apache/nginx)
- `data.audit.exe` → child process (bash, nc, dll)
- `data.audit.cmdline` → full command

### Action

**True positive confirmed:**

1. **Block source IP** di firewall:
   ```bash
   # SSH ke host
   sudo iptables -A INPUT -s <attacker_ip> -j DROP
   ```

2. **Submit alert ID** ke scoring (kalau implemented)

3. **DON'T** matiin web server - service health checker kasih penalty

---

## Phase 3: Detection - Lateral Movement

### Indicator
- SSH login dari DMZ host ke internal
- File access: `/etc/shadow`, SSH keys, config files
- Wazuh rule: 100150, 100151, 100152

### Hunt Query - SSH from DMZ
```
data.srcip:10.10.10.0/24 AND data.dstport:22
```

### Hunt Query - Sensitive File Access
```
rule.groups:credential_access OR rule.id:100141
```

### Hunt Query - Process Spawn dari www-data
```
data.audit.uid:33 AND data.audit.exe:"/usr/bin/ssh"
```

### Action

1. **Identify lateral target**
   - Cek tujuan SSH connection
   - List affected agent
   
2. **Isolate compromised host (DMZ)**
   ```bash
   # Disconnect dari internal network (tetep up di red_path)
   docker network disconnect cyber-range-demo_internal_net dmz-web
   ```
   
   ⚠️ **Pertimbangan:** Service masih jalan, tapi gak bisa pivot lagi

3. **Reset credential**
   - Webapp SSH key compromised
   - Rotate kalau ini real production

---

## Phase 4: Detection - Data Exfiltration

### Indicator
- mysqldump dari internal-app ke db-server
- Database query massal
- Wazuh rule: 100160, 100161

### Hunt Query
```
rule.groups:collection OR rule.groups:exfiltration
```

### Hunt Query - DB Access Pattern
```
agent.name:db-server AND data.audit.exe:"/usr/bin/mysqldump"
```

### Action

1. **Block DB access dari internal-app**
   ```bash
   docker network disconnect cyber-range-demo_internal_net internal-app
   ```

2. **Audit DB user activity**
   ```bash
   docker exec db-server mysql -uroot -pPr0d_DB_2024! \
     -e "SELECT user, host, current_connections FROM performance_schema.accounts;"
   ```

3. **Document exfiltrated data scope**
   - Tabel mana yang diakses?
   - Berapa baris data?
   - Sensitif level?

---

## Phase 5: Eviction & Eradication

### Hunt Persistence Mechanism

**Crontab anomalies:**
```
data.audit.exe:"/usr/bin/crontab"
```

**Service modification:**
```
data.audit.key:"persistence" OR data.audit.exe:"/bin/systemctl"
```

**Authorized_keys modification:**
```
syscheck.path:*authorized_keys* AND syscheck.event:*
```

### Manual Hunt di Container

```bash
# Check cron
docker exec dmz-web crontab -l
docker exec dmz-web cat /etc/crontab
docker exec dmz-web ls -la /etc/cron.*

# Check active connection
docker exec dmz-web ss -tulpn

# Check process tree
docker exec dmz-web ps auxf

# Check authorized_keys
docker exec internal-app cat /home/webapp/.ssh/authorized_keys

# Check for in-memory only process
docker exec dmz-web bash -c 'ls /proc/*/exe 2>/dev/null | xargs -I{} ls -la {} | grep deleted'
```

### Eviction Action

1. Kill malicious process
2. Remove backdoor (cron, systemd, authorized_keys baru)
3. Reset compromised credentials
4. Verify clean state via Velociraptor / manual scan

---

## Phase 6: Reporting

### Incident Report Template

```markdown
# Incident Report: Network Traversal Attack
**Date:** YYYY-MM-DD
**Analyst:** <your name>
**Severity:** Critical

## Executive Summary
- Attacker exploited command injection di dmz-web
- Achieved RCE, lateral movement ke internal-app via SSH
- Accessed customer database, exfiltrated data

## Timeline
| Time | Event | Source |
|------|-------|--------|
| HH:MM | Recon (nmap) | Suricata/Wazuh |
| HH:MM | RCE exploit | Rule 100110 |
| HH:MM | Reverse shell | Rule 100121 |
| HH:MM | SSH lateral | Rule 100150 |
| HH:MM | DB access | Rule 100161 |
| HH:MM | Containment | Manual action |

## IOC
- Attacker IP: <ip>
- Compromised user: webapp
- Persistence: <if found>

## Affected Assets
- dmz-web (initial)
- internal-app (lateral)
- db-server (data accessed)

## MITRE ATT&CK Mapping
- T1190 - Exploit Public-Facing Application
- T1059 - Command and Scripting Interpreter
- T1021.004 - SSH Lateral Movement
- T1003 - Credential Access
- T1005 - Data from Local System

## Containment Actions Taken
- Blocked attacker IP at firewall
- Disconnected dmz-web from internal network
- Rotated webapp SSH credentials

## Recommendations
1. Patch command injection vulnerability di /var/www/html/index.php
2. Remove leaked SSH key dari /var/www/html/
3. Implement network segmentation (DMZ ≠ internal direct)
4. Enable MFA untuk SSH
5. Implement DLP buat database access
```

---

## Useful Wazuh Dashboard Views

### Saved Searches buat Hunt

1. **All Critical Alerts**
   ```
   rule.level:>=12
   ```

2. **Network Traversal Scenario Alerts**
   ```
   rule.groups:network-traversal
   ```

3. **Per-Agent Activity**
   ```
   agent.name:dmz-web
   ```

4. **MITRE Tactic Filter**
   ```
   rule.mitre.tactic:"Lateral Movement"
   ```

### Dashboard Visualization

Bikin custom dashboard dengan:
- **Pie chart**: alert per rule.groups
- **Bar chart**: alert per agent
- **Timeline**: alert volume over time
- **Heat map**: MITRE technique coverage
- **Data table**: top 20 source IPs

## SOC Tier Levels

| Tier | Skill | Tugas di Skenario |
|------|-------|-------------------|
| **L1** | Triage | Filter alert, identify true/false positive |
| **L2** | Investigation | Hunt across log, correlate event, build timeline |
| **L3** | IR + Hunt | Containment decision, eviction, post-incident report |

Skenario ini cover **L1 → L3** workflow.
