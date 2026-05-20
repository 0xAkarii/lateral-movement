# Walkthrough Blue Team

Semua task disubmit sebagai flag. Format: `FLAG{...}`.

Blue Team basic mengakses DC langsung via RDP dan hunting di Event Viewer / PowerShell.

## Akses

```text
Target   : 10.10.10.10
Username : CORP\Administrator
Password : P@ssw0rd!Lab
```

Dari Windows:

```text
mstsc.exe
```

Dari Linux:

```bash
xfreerdp /u:'CORP\Administrator' /p:'P@ssw0rd!Lab' /v:10.10.10.10 /cert:ignore
```

Buka:

```text
Event Viewer -> Windows Logs -> Security
```

Atau buka PowerShell as Administrator.

## Query Dasar 4769

Gunakan query ini untuk mayoritas task:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4769; StartTime=(Get-Date).AddHours(-24)} |
  ForEach-Object {
    [PSCustomObject]@{
      Time    = $_.TimeCreated
      User    = $_.Properties[0].Value
      Service = $_.Properties[2].Value
      EncType = $_.Properties[5].Value
      IP      = $_.Properties[6].Value
    }
  } | Format-Table -Auto
```

## BT-F01: Event ID Utama

Task: temukan Event ID utama untuk request Kerberos service ticket.

Manual:

```text
Event Viewer -> Security -> Filter Current Log -> 4769
```

Finding:

```text
4769 - A Kerberos service ticket was requested
```

Submit flag:

```text
FLAG{4769}
```

## BT-F02: Attacker User

Task: temukan user attacker.

Query:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4769; StartTime=(Get-Date).AddHours(-24)} |
  ForEach-Object {
    [PSCustomObject]@{
      User    = $_.Properties[0].Value
      Service = $_.Properties[2].Value
      IP      = $_.Properties[6].Value
    }
  } |
  Group-Object User |
  Sort-Object Count -Descending |
  Select-Object Name, Count
```

Finding:

```text
jdoe
```

Submit flag:

```text
FLAG{jdoe}
```

## BT-F03: Source IP

Task: temukan IP attacker.

Query:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4769; StartTime=(Get-Date).AddHours(-24)} |
  ForEach-Object {
    [PSCustomObject]@{
      User = $_.Properties[0].Value
      IP   = $_.Properties[6].Value
    }
  } |
  Group-Object User, IP |
  Sort-Object Count -Descending |
  Select-Object Name, Count
```

Finding:

```text
10.10.10.50
```

Submit flag:

```text
FLAG{10.10.10.50}
```

## BT-F04: Web Service Account Target

Task: temukan service account web yang ditargetkan.

Query:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4769; StartTime=(Get-Date).AddHours(-24)} |
  ForEach-Object {
    [PSCustomObject]@{
      User    = $_.Properties[0].Value
      Service = $_.Properties[2].Value
      EncType = $_.Properties[5].Value
      IP      = $_.Properties[6].Value
    }
  } |
  Where-Object { $_.User -eq 'jdoe' -and $_.Service -notlike '*$' -and $_.Service -ne 'krbtgt' } |
  Select-Object Service -Unique
```

Finding:

```text
svc_web
```

Submit flag:

```text
FLAG{svc_web}
```

## BT-F05: RC4 Encryption Type

Task: temukan encryption type RC4.

Query:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4769; StartTime=(Get-Date).AddHours(-24)} |
  ForEach-Object {
    [PSCustomObject]@{
      User    = $_.Properties[0].Value
      Service = $_.Properties[2].Value
      EncType = $_.Properties[5].Value
    }
  } |
  Where-Object { $_.User -eq 'jdoe' } |
  Select-Object User, Service, EncType
```

Finding:

```text
0x17 = RC4-HMAC
```

Submit flag:

```text
FLAG{0x17}
```

## BT-F06: Privileged Login

Task: temukan account privileged yang dipakai login.

Successful logon:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624; StartTime=(Get-Date).AddHours(-24)} |
  ForEach-Object {
    [PSCustomObject]@{
      Time      = $_.TimeCreated
      Account   = $_.Properties[5].Value
      LogonType = $_.Properties[8].Value
      IP        = $_.Properties[18].Value
    }
  } |
  Where-Object { $_.Account -eq 'svc_admin' -or $_.IP -eq '10.10.10.50' } |
  Format-Table -Auto
```

Special privilege:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4672; StartTime=(Get-Date).AddHours(-24)} |
  ForEach-Object {
    [PSCustomObject]@{
      Time    = $_.TimeCreated
      Account = $_.Properties[1].Value
    }
  } |
  Where-Object { $_.Account -eq 'svc_admin' } |
  Format-Table -Auto
```

Finding:

```text
svc_admin
```

Submit flag:

```text
FLAG{svc_admin}
```

## BT-F07: MITRE Technique

Task: identifikasi MITRE ATT&CK technique.

Finding:

```text
Kerberoasting = T1558.003
```

Submit flag:

```text
FLAG{T1558.003}
```

## BT-F08: Mitigasi Utama

Task: identifikasi mitigasi paling kuat untuk service account legacy.

Finding:

```text
gMSA / Group Managed Service Account
```

Submit flag:

```text
FLAG{gMSA}
```

## Timeline Untuk Laporan

```text
1. jdoe authenticate ke domain.
2. jdoe request TGS untuk svc_sql, svc_web, svc_backup, svc_admin.
3. DC mencatat Event ID 4769.
4. Attacker crack hash offline.
5. svc_admin dipakai login.
6. Event ID 4624/4672 menunjukkan privileged activity.
```

## Pitfalls

### Tidak menemukan 4769

Cek audit policy:

```cmd
auditpol /get /subcategory:"Kerberos Service Ticket Operations"
```

Aktifkan jika perlu:

```cmd
auditpol /set /subcategory:"Kerberos Service Ticket Operations" /success:enable /failure:enable
```

### Salah target service

Abaikan:

```text
krbtgt
DC01$
account berakhiran $
```

Fokus:

```text
svc_sql
svc_web
svc_backup
svc_admin
```
