#!/bin/bash
# ====================================================================
# Run full attack chain end-to-end (semi-automated buat demo)
# WARNING: butuh listener manual di terminal lain
# ====================================================================

TARGET_IP="${TARGET_IP:-10.10.10.10}"
ATTACKER_IP="${ATTACKER_IP:-10.10.10.99}"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  CYBER RANGE - FULL ATTACK CHAIN DEMO                            ║"
echo "║  Network Traversal Hunt Scenario                                 ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

read -p "[?] Press ENTER untuk start Phase 1 (Recon)..."
bash "$(dirname "$0")/01-recon.sh"

read -p "[?] Press ENTER untuk start Phase 2 (Initial Access)..."
bash "$(dirname "$0")/02-exploit.sh"

read -p "[?] Press ENTER untuk lanjut ke Phase 3 (Lateral Movement)..."
bash "$(dirname "$0")/03-lateral.sh"

echo ""
echo "[+] Demo selesai. Buka Wazuh Dashboard buat liat alert yang ke-trigger."
echo "    URL: https://<host>:443"
echo "    User: admin / SecretPassword"
