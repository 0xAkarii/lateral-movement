#!/bin/bash
# ====================================================================
# Entrypoint - Database Server
# ====================================================================
set -e

echo "[*] Starting Database Server..."

# Start auditd
service auditd start || true
augenrules --load 2>/dev/null || true

# Configure Wazuh agent
if [ -n "$WAZUH_MANAGER" ]; then
    sed -i "s|<address>.*</address>|<address>${WAZUH_MANAGER}</address>|g" /var/ossec/etc/ossec.conf
fi

# Initialize MySQL kalau belum ada data
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[*] Initializing MySQL..."
    mysqld --initialize-insecure --user=mysql

    # Start MySQL temporarily
    mysqld --user=mysql --skip-networking &
    MYSQL_PID=$!
    sleep 5

    # Set root password
    mysql -uroot <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD:-Pr0d_DB_2024!}';
CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD:-Pr0d_DB_2024!}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

CREATE USER 'appuser'@'%' IDENTIFIED BY 'AppDB_P@ssw0rd_2024';
CREATE DATABASE IF NOT EXISTS customers;
CREATE DATABASE IF NOT EXISTS analytics;
GRANT ALL PRIVILEGES ON customers.* TO 'appuser'@'%';
GRANT SELECT ON analytics.* TO 'appuser'@'%';

CREATE USER 'readonly'@'%' IDENTIFIED BY 'ReadOnly_2024';
GRANT SELECT ON analytics.* TO 'readonly'@'%';

FLUSH PRIVILEGES;
EOF

    # Run init scripts
    for sql_file in /docker-entrypoint-initdb.d/*.sql; do
        if [ -f "$sql_file" ]; then
            echo "[*] Running: $sql_file"
            mysql -uroot -p"${MYSQL_ROOT_PASSWORD:-Pr0d_DB_2024!}" < "$sql_file"
        fi
    done

    # Stop temporary MySQL
    kill $MYSQL_PID
    wait $MYSQL_PID 2>/dev/null || true
    sleep 2
fi

# Auto-enroll Wazuh agent
echo "[*] Registering Wazuh agent to ${WAZUH_MANAGER}..."
/var/ossec/bin/agent-auth -m "${WAZUH_MANAGER}" -A "${WAZUH_AGENT_NAME:-db-server}" -G "${WAZUH_AGENT_GROUP:-default}" 2>&1 || \
    echo "[!] Agent registration failed, will retry"

# Start Wazuh agent
echo "[*] Starting Wazuh agent..."
/var/ossec/bin/wazuh-control start

# Start MySQL in foreground
echo "[*] Starting MySQL server..."
exec mysqld --user=mysql
