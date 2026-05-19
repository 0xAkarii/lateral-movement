#!/bin/bash
# ====================================================================
# Entrypoint - Internal App Server
# ====================================================================
set -e

echo "[*] Starting Internal App Server..."

# Generate SSH host keys kalau belum ada
ssh-keygen -A 2>/dev/null || true

# Start auditd
service auditd start || true
augenrules --load 2>/dev/null || true

# Configure Wazuh agent
if [ -n "$WAZUH_MANAGER" ]; then
    sed -i "s|<address>.*</address>|<address>${WAZUH_MANAGER}</address>|g" /var/ossec/etc/ossec.conf
fi

# Auto-enroll agent
echo "[*] Registering Wazuh agent to ${WAZUH_MANAGER}..."
/var/ossec/bin/agent-auth -m "${WAZUH_MANAGER}" -A "${WAZUH_AGENT_NAME:-internal-app}" -G "${WAZUH_AGENT_GROUP:-default}" 2>&1 || \
    echo "[!] Agent registration failed, will retry"

# Start Wazuh agent
echo "[*] Starting Wazuh agent..."
/var/ossec/bin/wazuh-control start

# Start SSH daemon in foreground
echo "[*] Starting SSH server..."
exec /usr/sbin/sshd -D -e
