#!/bin/bash
# ====================================================================
# Entrypoint - DMZ Web Server
# ====================================================================
set -e

echo "[*] Starting DMZ Web Server..."

# Start auditd
service auditd start || true
augenrules --load 2>/dev/null || true

# Configure Wazuh agent dengan environment variable
if [ -n "$WAZUH_MANAGER" ]; then
    sed -i "s|<address>.*</address>|<address>${WAZUH_MANAGER}</address>|g" /var/ossec/etc/ossec.conf
fi

# Auto-enroll agent ke manager
echo "[*] Registering Wazuh agent to ${WAZUH_MANAGER}..."
/var/ossec/bin/agent-auth -m "${WAZUH_MANAGER}" -A "${WAZUH_AGENT_NAME:-dmz-web}" -G "${WAZUH_AGENT_GROUP:-default}" 2>&1 || \
    echo "[!] Agent registration failed, will retry"

# Start Wazuh agent
echo "[*] Starting Wazuh agent..."
/var/ossec/bin/wazuh-control start

# Start Apache in foreground
echo "[*] Starting Apache web server..."
. /etc/apache2/envvars
exec apache2 -DFOREGROUND
