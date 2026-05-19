#!/bin/bash
# ====================================================================
# One-shot setup script - bikin lab dari nol sampe ready
# ====================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║   CYBER RANGE DEMO - SETUP                                       ║"
echo "║   Network Traversal Hunt Scenario                                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# ===== Step 1: Check prerequisites =====
echo "[*] Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "[!] Docker tidak ditemukan. Install dulu: https://docs.docker.com/engine/install/"
    exit 1
fi

if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "[!] Docker Compose tidak ditemukan."
    exit 1
fi

echo "[+] Docker tersedia"

# Detect docker compose command
if docker compose version &> /dev/null; then
    DC="docker compose"
else
    DC="docker-compose"
fi

# ===== Step 2: System tuning untuk Wazuh Indexer =====
echo ""
echo "[*] Applying system tuning untuk Wazuh Indexer..."
echo "    (butuh sudo - skip kalau gak bisa)"

if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
    sudo sysctl -w vm.max_map_count=262144 2>/dev/null || true
    echo "[+] vm.max_map_count = 262144"
else
    echo "[!] Skip sysctl (no sudo). Run manual:"
    echo "    sudo sysctl -w vm.max_map_count=262144"
fi

# ===== Step 3: Generate SSH keys untuk lateral movement =====
echo ""
echo "[*] Generating SSH keys untuk lateral movement scenario..."

SSH_KEY_DIR="${SCRIPT_DIR}/targets/dmz-web/ssh_keys"
INTERNAL_SSH_DIR="${SCRIPT_DIR}/targets/internal-app/ssh_keys"

mkdir -p "${SSH_KEY_DIR}" "${INTERNAL_SSH_DIR}"

if [ ! -f "${SSH_KEY_DIR}/id_rsa" ]; then
    ssh-keygen -t rsa -b 2048 -f "${SSH_KEY_DIR}/id_rsa" -N "" -C "webapp@dmz-web" -q
    echo "[+] SSH keypair generated"
fi

# Copy public key ke internal-app authorized_keys location
cp "${SSH_KEY_DIR}/id_rsa.pub" "${INTERNAL_SSH_DIR}/id_rsa.pub"
echo "[+] Public key disalin ke internal-app"

# ===== Step 4: Generate Wazuh certificates =====
echo ""
echo "[*] Generating Wazuh certificates..."

if [ ! -f "${SCRIPT_DIR}/certs/root-ca.pem" ]; then
    bash "${SCRIPT_DIR}/generate-certs.sh"
else
    echo "[+] Certificates udah ada, skip generation"
fi

# ===== Step 5: Build images =====
echo ""
echo "[*] Building target container images (lama, sabar...)..."
$DC build

# ===== Step 6: Start Wazuh stack first =====
echo ""
echo "[*] Starting Wazuh stack..."
$DC up -d wazuh-indexer

echo "[*] Waiting for Wazuh Indexer to be ready (30s)..."
sleep 30

$DC up -d wazuh-manager wazuh-dashboard

echo "[*] Waiting for Wazuh stack stabilize (45s)..."
sleep 45

# ===== Step 7: Configure custom rules =====
echo ""
echo "[*] Loading custom rules into Wazuh Manager..."

# Copy custom rules ke manager rules folder
docker exec wazuh-manager bash -c "
  cp /var/ossec/etc/rules.custom/local_rules.xml /var/ossec/etc/rules/local_rules.xml 2>/dev/null || true
  /var/ossec/bin/wazuh-control restart
" 2>/dev/null || echo "[!] Custom rules will be loaded on next manager restart"

# ===== Step 8: Start target lab =====
echo ""
echo "[*] Starting target lab containers..."
$DC up -d dmz-web internal-app db-server

echo "[*] Waiting for targets to register agents (30s)..."
sleep 30

# ===== Step 9: Status check =====
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║   SETUP COMPLETE                                                 ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "[*] Container status:"
$DC ps

echo ""
echo "[*] Wazuh Manager - registered agents:"
docker exec wazuh-manager /var/ossec/bin/agent_control -lc 2>/dev/null || echo "    (manager belum ready, coba lagi nanti)"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "ACCESS INFO"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "BLUE TEAM:"
echo "  Wazuh Dashboard : https://<host-ip>:443"
echo "  Username        : admin"
echo "  Password        : SecretPassword"
echo ""
echo "RED TEAM (dari Kali/Parrot):"
echo "  DMZ Web Target  : http://<host-ip-or-10.10.10.10>"
echo "  Attack scripts  : ./scripts/attack/"
echo ""
echo "TARGETS NETWORK:"
echo "  dmz-web         : 10.10.10.10 (red_path) | 172.20.0.10 (internal)"
echo "  internal-app    : 172.20.0.20 (internal only)"
echo "  db-server       : 172.20.0.30 (internal only)"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "NEXT STEPS"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "1. Buka dashboard di browser"
echo "2. Run attack: ./scripts/attack/01-recon.sh"
echo "3. Lihat alerts real-time di Wazuh Dashboard"
echo ""
echo "Lihat docs/DEMO-WALKTHROUGH.md buat skenario lengkap"
echo ""
