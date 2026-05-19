# Integration dengan Platform Guacamole

Cara integrasi lab ini dengan platform Guacamole + jump box yang udah lu punya.

## Asumsi Platform Existing

```
[User Browser] → [Guacamole] → [Jump Box VMs (Kali/Parrot)]
```

Lu udah punya:
- Guacamole web gateway running
- VM Kali untuk Red Team user
- VM Parrot (atau Kali) untuk Blue Team user
- Networking antara Guacamole ↔ jump box VM udah jalan

## Tugas Integrasi

Lab cyber range butuh **3 koneksi network** ke ekosistem Guacamole:

1. **Red VM → DMZ Target** (`red_path` network)
2. **Blue VM → Wazuh Dashboard** (`blue_access` network)
3. **Optional: Blue VM → Wazuh API** (kalau pakai OpenCTI atau integration lain)

## Network Integration Options

### Option 1: Same Docker Host (Simplest)

Kalau Guacamole + Jump Box VMs jalan di **host yang sama** dengan lab containers:

**Setup:**
1. Buat Docker bridge network khusus buat connect ke VM
2. Attach VM ke bridge network via libvirt/QEMU

**Pros:** Setup simple, no routing complexity
**Cons:** Single host bottleneck

**Sample libvirt XML for VM:**
```xml
<interface type='bridge'>
  <source bridge='docker_red_path'/>
  <model type='virtio'/>
</interface>
```

### Option 2: Separate Hosts dengan VLAN/Routing

Lab di host A, Guacamole/VM di host B:

```
[Host B: Guacamole]                    [Host A: Lab]
    │                                       │
    ├── Kali VM (10.10.10.99)               ├── dmz-web (10.10.10.10)
    │                                       │
    └── Parrot VM (172.40.0.50)             └── wazuh-dashboard (172.40.0.30)
                                                
              Connected via L3 routing or VLAN trunk
```

**Setup:**
1. Pastikan Host A's `red_path` subnet (10.10.10.0/24) reachable dari Host B
2. Setup static route atau VLAN trunk
3. Kali VM di Host B configured dengan IP di range 10.10.10.0/24

**Pros:** Scalable, isolasi resource
**Cons:** Networking lebih kompleks

### Option 3: Macvlan (Kalau VM dan Container Mau Sama-sama Akses Physical Network)

```yaml
networks:
  red_path:
    driver: macvlan
    driver_opts:
      parent: eth0
    ipam:
      config:
        - subnet: 192.168.10.0/24
```

Container dapat IP dari physical network, sama dengan VM.

**Pros:** Container & VM at same L2 level
**Cons:** Butuh control penuh atas physical network

## Step-by-Step Integration

### Step 1: Identify Existing Network

Cek konfigurasi platform existing:

```bash
# Di host Guacamole
ip addr show
ip route
docker network ls    # kalau Guacamole pakai docker
virsh net-list       # kalau pakai libvirt
```

Identify:
- Subnet apa yang dipakai jump box VMs
- Apakah ada bridge network yang bisa dipakai

### Step 2: Modify docker-compose.yml

Sesuaikan subnet di `docker-compose.yml`:

```yaml
networks:
  red_path:
    driver: bridge
    ipam:
      config:
        - subnet: 10.10.10.0/24    # ← cocok dengan jump box VMs Kali subnet
        
  blue_access:
    driver: bridge
    ipam:
      config:
        - subnet: 172.40.0.0/24    # ← cocok dengan Parrot VM subnet
```

### Step 3: Static IP Assignment

Set IP fix buat targets supaya gampang di-reference dari jump box VM:

```yaml
services:
  dmz-web:
    networks:
      red_path:
        ipv4_address: 10.10.10.10    # Red VM bisa langsung target ini
        
  wazuh-dashboard:
    networks:
      blue_access:
        ipv4_address: 172.40.0.30    # Blue VM bisa akses dashboard
```

### Step 4: Routing/Bridge Setup

**Option A: Bridge container network ke physical:**

```bash
# Connect Docker bridge ke physical interface
sudo brctl addif docker_red_path eth1

# Atau pakai macvlan yang udah dijelasin di atas
```

**Option B: NAT/Port forwarding:**

```bash
# Forward port 80 dari host ke dmz-web
# (compose udah handle ini via "ports" section)
```

### Step 5: Test Connectivity

Dari Red VM (Kali) di Guacamole:
```bash
ping 10.10.10.10
curl http://10.10.10.10
nmap -sV 10.10.10.10
```

Dari Blue VM (Parrot):
```bash
ping 172.40.0.30
curl -k https://172.40.0.30:443
```

### Step 6: Pre-Install Tools di Jump Box

Pastikan jump box VMs udah punya tools yang dibutuhkan:

**Red VM (Kali):**
- nmap (default Kali)
- curl, wget (default)
- netcat (default)
- python3 (default)
- git clone repo lab → akses scripts/attack/

```bash
# Di Kali VM
git clone <repo-url> ~/cyber-range-demo
cd ~/cyber-range-demo/scripts/attack/
ls *.sh
```

**Blue VM (Parrot/Kali):**
- Browser (default)
- curl, jq (default)
- wireshark/tshark (default)
- bookmark Wazuh Dashboard URL

## Sample Guacamole Connection Config

### Red Team Connection
```
Name: Red Team - Network Traversal Lab
Protocol: RDP / SSH / VNC (sesuai jump box)
Host: <red-vm-ip>
Port: 3389/22/5900

Notes for User:
- Target: http://10.10.10.10
- Attack scripts: ~/cyber-range-demo/scripts/attack/
- Listener IP: 10.10.10.99 (your IP)
```

### Blue Team Connection
```
Name: Blue Team - SOC Console
Protocol: RDP / SSH / VNC

Notes for User:
- Wazuh Dashboard: https://172.40.0.30:443
- Credentials: admin / SecretPassword
- Hunt scripts: ~/cyber-range-demo/scripts/hunt/
```

## Multi-Session Considerations

Untuk multi-user (≥10), lu butuh **per-session lab**:

**Pattern:** Spawn lab dengan unique session ID

```bash
# Wrapper script di platform side
SESSION_ID="user-${USER_ID}-${TIMESTAMP}"

# Spawn lab dengan project name unique
docker compose -p "${SESSION_ID}" \
  -f docker-compose.yml \
  --env-file ".env.${SESSION_ID}" \
  up -d

# Generate unique IP range per session
# Inject ke .env.${SESSION_ID}:
# RED_PATH_SUBNET=10.${OCTET}.10.0/24
# BLUE_ACCESS_SUBNET=172.40.${OCTET}.0/24
```

Lalu update Guacamole connection dynamically:
```python
# pseudo
guacamole_api.create_connection(
    name=f"Red Team - {session_id}",
    target_ip=f"10.{octet}.10.99",
    user=user_email
)
```

## Network Troubleshooting

### Red VM gak bisa reach dmz-web

```bash
# Dari Red VM
ping -c 3 10.10.10.10

# Kalau timeout:
ip route                              # cek default route
traceroute 10.10.10.10                # cek hop
sudo iptables -L                      # cek firewall

# Dari host lab
sudo iptables -L DOCKER-USER          # cek docker firewall
docker network inspect cyber-range-demo_red_path
```

### Blue VM gak bisa akses Dashboard

```bash
# Dari Blue VM
curl -kv https://172.40.0.30:443 2>&1 | head -20

# Common issue: TLS cert expired or untrusted
# Solution: tambah --insecure / -k flag, atau import CA
```

### Wazuh Agent gak konek dari container

```bash
# Cek dari target container
docker exec dmz-web ping -c 3 wazuh-manager
docker exec dmz-web nc -zv 172.30.0.10 1514

# Kalau fail, cek wazuh_net network
docker network inspect cyber-range-demo_wazuh_net
```

## Security Considerations

⚠️ **Important untuk multi-tenant deployment:**

1. **Network isolation per session** - jangan biarkan session A bisa reach session B
2. **Resource quota** - prevent 1 user consume all resource
3. **Egress firewall** - block container to internet (kecuali yang perlu)
4. **Cleanup script** - auto-destroy session setelah expire
5. **Audit logging** - track siapa spawn lab kapan

## Sample Egress Firewall Rules

```bash
# Block container ke real internet (allow LAN only)
iptables -I DOCKER-USER -d 0.0.0.0/0 -j DROP
iptables -I DOCKER-USER -d 192.168.0.0/16 -j ACCEPT
iptables -I DOCKER-USER -d 10.0.0.0/8 -j ACCEPT
iptables -I DOCKER-USER -d 172.16.0.0/12 -j ACCEPT
```

⚠️ **Caveat:** Wazuh agent install pas first run butuh internet (apt repo). Pre-bake image biar runtime gak butuh internet.
