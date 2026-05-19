#!/bin/bash
# ====================================================================
# Demo Attack Script - Phase 1: Reconnaissance
# Run from Kali / security distribution
# ====================================================================

TARGET_IP="${TARGET_IP:-10.10.10.10}"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  PHASE 1: RECONNAISSANCE                                         ║"
echo "║  Target: ${TARGET_IP}                                             ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

echo "[*] Step 1: Ping sweep & port scan"
echo "    Command: nmap -sV -sC -p 80,22,3306 ${TARGET_IP}"
echo ""
nmap -sV -sC -p 80,22,3306 ${TARGET_IP}

echo ""
echo "[*] Step 2: Web service enumeration"
echo "    Command: curl -sI http://${TARGET_IP}/"
echo ""
curl -sI http://${TARGET_IP}/

echo ""
echo "[*] Step 3: Discover the diagnostic tool"
echo "    Command: curl -s http://${TARGET_IP}/ | grep -i 'tool\\|version'"
echo ""
curl -s http://${TARGET_IP}/ | grep -iE "tool|version|maintenance" | head -5

echo ""
echo "[+] RECON COMPLETE"
echo "    Findings:"
echo "    - Web server running on port 80 (Apache)"
echo "    - Network diagnostic tool detected at /"
echo "    - 'host' parameter in form looks suspicious"
echo ""
echo "    Next: Run ./02-exploit.sh"
