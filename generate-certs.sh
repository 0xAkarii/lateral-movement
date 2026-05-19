#!/bin/bash
# ====================================================================
# Generate Wazuh certificates for the demo stack
# Uses official Wazuh certs-tool to create self-signed certs
# ====================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"
WORK_DIR="$(mktemp -d)"

echo "[*] Generating Wazuh certificates..."
echo "[*] Output: ${CERTS_DIR}"

# Create config for certs-tool
cat > "${WORK_DIR}/config.yml" <<'EOF'
nodes:
  indexer:
    - name: wazuh-indexer
      ip: wazuh-indexer
  server:
    - name: wazuh-manager
      ip: wazuh-manager
  dashboard:
    - name: wazuh-dashboard
      ip: wazuh-dashboard
EOF

# Download certs-tool from Wazuh
echo "[*] Downloading certs-tool..."
curl -sO https://packages.wazuh.com/4.7/wazuh-certs-tool.sh
chmod +x wazuh-certs-tool.sh

# Move to working directory
mv wazuh-certs-tool.sh "${WORK_DIR}/"

# Generate certificates
cd "${WORK_DIR}"
cp config.yml ./config.yml

# Run certs tool
bash ./wazuh-certs-tool.sh -A

# Move generated certs to target location
echo "[*] Copying certificates to ${CERTS_DIR}"
mkdir -p "${CERTS_DIR}"

# wazuh-certificates folder is created by tool
if [ -d "wazuh-certificates" ]; then
    cp -r wazuh-certificates/* "${CERTS_DIR}/"
fi

# Cleanup
cd - > /dev/null
rm -rf "${WORK_DIR}"

# Set proper permissions
chmod 644 "${CERTS_DIR}"/*.pem 2>/dev/null || true
chmod 600 "${CERTS_DIR}"/*-key.pem 2>/dev/null || true

echo ""
echo "[+] Certificates generated successfully!"
echo "[+] Files in ${CERTS_DIR}:"
ls -la "${CERTS_DIR}/"
