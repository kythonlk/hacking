# 🗺️ Nmap Enumeration Cheat Sheet (CPTS)

## 🚀 Quick Starts & Baseline Scans
These are your "go-to" commands when starting a box or looking for quick wins.

- **Find available IPs with output file** = `sudo nmap 10.129.2.0/24 -sn -oA tnet | grep for | cut -d" " -f5`
- **CPTS core services** = `sudo nmap 10.129.2.18 -p 21,22,23,25,53,80,111,139,443,445,1433,2049,3306,3389,5985,8080 -sV -sC -T4`
- **Fast open ports + banner** = `sudo nmap 10.129.2.18 -F --script banner --min-rate 1000`
- **Stealth with 5 IPs (4 Decoys)** = `sudo nmap 10.129.2.18 -sS -Pn -n --top-ports 100 -D RND:4,ME --min-rate 1000`
- **Full port discovery sweep** = `sudo nmap 10.129.2.18 -p- --min-rate 5000 --open -Pn -n`
- **Quick UDP discovery** = `sudo nmap 10.129.2.18 -sU --top-ports 20 --min-rate 1000 -Pn`
- **Ping scan with packet trace** = `sudo nmap 10.129.2.18 -sn -oA host -PE --packet-trace`
- **Ping without ARP** = `sudo nmap 10.129.2.18 -sn -oA host -PE --packet-trace --disable-arp-ping`
- **Fast scan (Top 100)** = `sudo nmap 10.129.2.18 -F`
- **Full TCP sweep (High Speed)** = `sudo nmap 10.129.2.18 -p- --min-rate 5000`
- **Service & Default Scripts (The Big Two)** = `sudo nmap 10.129.2.18 -sV -sC`
- **Aggressive scan (OS, Service, Scripts)** = `sudo nmap 10.129.2.18 -A`
- **Scan specific ports** = `sudo nmap 10.129.2.18 -p 22,80,443,445`
- **Ping scan only (Alive check)** = `sudo nmap 10.129.2.0/24 -sn`
- **Only show open ports** = `sudo nmap 10.129.2.18 --open`
- **Fastest UDP (Top 20)** = `sudo nmap 10.129.2.18 -sU -F --top-ports 20`
- **Check specific service version** = `sudo nmap 10.129.2.18 -p 80 -sV --version-intensity 0`

---

## 🥷 Stealth & Performance (T4/Min-Rate Optimization)
Balance speed with evasion. Using `--min-rate` ensures Nmap doesn't slow down due to network congestion, while `-T4` optimizes timing for modern networks.

- **Fast Stealth TCP SYN** = `sudo nmap 10.129.2.18 -sS -T4 --min-rate 1000`
- **No Ping (Skip discovery)** = `sudo nmap 10.129.2.18 -Pn -T4`
- **No DNS resolution** = `sudo nmap 10.129.2.18 -n`
- **Disable ARP Pings** = `sudo nmap 10.129.2.18 --disable-arp-ping`
- **Limit Max Retries (Speed up)** = `sudo nmap 10.129.2.18 --max-retries 1`
- **Host Timeout (Drop slow hosts)** = `sudo nmap 10.129.2.18 --host-timeout 15m`
- **Fast Scan with Packet Trace** = `sudo nmap 10.129.2.18 --packet-trace --min-rate 1000`
- **Increase Parallelism** = `sudo nmap 10.129.2.18 --min-parallelism 100`
- **Set RTT Timeout** = `sudo nmap 10.129.2.18 --max-rtt-timeout 100ms`
- **Sneaky Timing (Very Slow)** = `sudo nmap 10.129.2.18 -T2`

---

## 🧱 Firewall & IDS Evasion
Essential for the CPTS "Firewall" modules and bypassing filters.

- **Fragment packets (8 bytes)** = `sudo nmap 10.129.2.18 -f`
- **Fragment packets (16 bytes)** = `sudo nmap 10.129.2.18 -ff`
- **Custom MTU size** = `sudo nmap 10.129.2.18 --mtu 24`
- **Decoy scan (Mask IP)** = `sudo nmap 10.129.2.18 -D RND:10`
- **Source Port 53 (DNS Bypass)** = `sudo nmap 10.129.2.18 --source-port 53`
- **Source Port 80 (HTTP Bypass)** = `sudo nmap 10.129.2.18 -g 80`
- **Append random data to packets** = `sudo nmap 10.129.2.18 --data-length 25`
- **Spoof MAC Address** = `sudo nmap 10.129.2.18 --spoof-mac Apple`
- **Bad Checksums (Firewall test)** = `sudo nmap 10.129.2.18 --badsum`
- **TCP ACK Scan (Map filters)** = `sudo nmap 10.129.2.18 -sA`

---

## 🔍 Service-Specific Enumeration (NSE)
Use scripts to get more than just "open" or "closed."

- **Banner Grabbing** = `sudo nmap 10.129.2.18 --script banner`
- **SMB Share Enum** = `sudo nmap 10.129.2.18 -p 445 --script smb-enum-shares`
- **SMB Vulnerability Scan** = `sudo nmap 10.129.2.18 -p 445 --script vuln`
- **HTTP Directory Brute** = `sudo nmap 10.129.2.18 -p 80 --script http-enum`
- **SSH Auth Methods** = `sudo nmap 10.129.2.18 -p 22 --script ssh-auth-methods`
- **DNS Zone Transfer** = `sudo nmap 10.129.2.18 -p 53 --script dns-zone-transfer`
- **FTP Anonymous Login** = `sudo nmap 10.129.2.18 -p 21 --script ftp-anon`
- **MySQL Databases Enum** = `sudo nmap 10.129.2.18 -p 3306 --script mysql-databases`
- **SNMP Info Extraction** = `sudo nmap 10.129.2.18 -sU -p 161 --script snmp-info`
- **LDAP Root DSE** = `sudo nmap 10.129.2.18 -p 389 --script ldap-rootdse`

---

## 🗄️ SMB Enumeration (Port 139/445)
High priority for Windows environments and Active Directory.

- **List all SMB scripts** = `ls /usr/share/nmap/scripts/smb*`
- **Enum shares (Null Session)** = `sudo nmap -p 445 --script smb-enum-shares 10.129.2.18`
- **Enum users (MSRPC)** = `sudo nmap -p 445 --script smb-enum-users 10.129.2.18`
- **Check SMB Security Mode** = `sudo nmap -p 445 --script smb-security-mode 10.129.2.18`
- **Detect OS via SMB** = `sudo nmap -p 445 --script smb-os-discovery 10.129.2.18`
- **Check for MS17-010 (EternalBlue)** = `sudo nmap -p 445 --script smb-vuln-ms17-010 10.129.2.18`
- **List SMB Sessions** = `sudo nmap -p 445 --script smb-enum-sessions 10.129.2.18`
- **Enum SMB Domains** = `sudo nmap -p 445 --script smb-enum-domains 10.129.2.18`
- **Brute force SMB logins** = `sudo nmap -p 445 --script smb-brute --script-args userdb=users.txt,passdb=pass.txt`
- **SMB2 Protocol info** = `sudo nmap -p 445 --script smb2-capabilities,smb2-security-mode`

---

## 📂 FTP Enumeration (Port 21)
Often holds configuration files or backups.

- **Check for Anonymous Login** = `sudo nmap -p 21 --script ftp-anon 10.129.2.18`
- **FTP Banner & System info** = `sudo nmap -p 21 --script ftp-syst,banner 10.129.2.18`
- **Check for FTP Bounce attack** = `sudo nmap -p 21 --script ftp-bounce 10.129.2.18`
- **FTP Brute force** = `sudo nmap -p 21 --script ftp-brute 10.129.2.18`
- **List FTP root files** = `sudo nmap -p 21 --script ftp-ls 10.129.2.18`
- **Check ProFTPD exploits** = `sudo nmap -p 21 --script ftp-proftpd-backdoor 10.129.2.18`
- **Check vsftpd backdoor** = `sudo nmap -p 21 --script ftp-vsftpd-backdoor 10.129.2.18`

---

## 📧 SMTP & Mail (Port 25, 465, 587)
Critical for user enumeration.

- **List SMTP commands (EHLO)** = `sudo nmap -p 25 --script smtp-commands 10.129.2.18`
- **Enumerate SMTP users** = `sudo nmap -p 25 --script smtp-enum-users 10.129.2.18`
- **Check for Open Relay** = `sudo nmap -p 25 --script smtp-open-relay 10.129.2.18`
- **Brute force SMTP** = `sudo nmap -p 25 --script smtp-brute 10.129.2.18`
- **IMAP Capabilities** = `sudo nmap -p 143 --script imap-capabilities 10.129.2.18`
- **POP3 Capabilities** = `sudo nmap -p 110 --script pop3-capabilities 10.129.2.18`

---

## 🌐 HTTP/HTTPS Enumeration (Port 80/443)
The most common attack surface in CPTS.

- **Enumerate directories** = `sudo nmap -p 80 --script http-enum 10.129.2.18`
- **Grab HTTP Headers** = `sudo nmap -p 80 --script http-headers 10.129.2.18`
- **Fetch Title of pages** = `sudo nmap -p 80 --script http-title 10.129.2.18`
- **Check robots.txt** = `sudo nmap -p 80 --script http-robots.txt 10.129.2.18`
- **Detect Web App Firewall (WAF)** = `sudo nmap -p 80 --script http-waf-detect 10.129.2.18`
- **Check for SSL/TLS Vulns** = `sudo nmap -p 443 --script ssl-enum-ciphers,ssl-heartbleed`
- **HTTP Methods (PUT/DELETE?)** = `sudo nmap -p 80 --script http-methods 10.129.2.18`
- **Vhost Discovery** = `sudo nmap -p 80 --script http-vhosts 10.129.2.18`

---

## 🗃️ Database & Services (SQL, SNMP, DNS)
Often the final objective.

- **MySQL Info** = `sudo nmap -p 3306 --script mysql-info,mysql-databases 10.129.2.18`
- **MSSQL Info** = `sudo nmap -p 1433 --script ms-sql-info,ms-sql-config`
- **Oracle SID Brute** = `sudo nmap -p 1521 --script oracle-sid-brute`
- **SNMP Info (UDP 161)** = `sudo nmap -sU -p 161 --script snmp-info 10.129.2.18`
- **DNS Zone Transfer** = `sudo nmap -p 53 --script dns-zone-transfer --script-args dns-zone-transfer.domain=test.local`
- **NFS Shares** = `sudo nmap -p 111,2049 --script nfs-ls,nfs-showmount,nfs-statfs`
- **Redis Info** = `sudo nmap -p 6379 --script redis-info`
- **RDP Security Check** = `sudo nmap -p 3389 --script rdp-enum-encryption,rdp-ntlm-info`

---

## 🛠️ Output & Miscellaneous
How to save your work for the exam report.

- **Save in all formats** = `sudo nmap 10.129.2.18 -oA output_name`
- **Grepable output** = `sudo nmap 10.129.2.18 -oG results.txt`
- **XML for import to tools** = `sudo nmap 10.129.2.18 -oX results.xml`
- **Resume a cancelled scan** = `sudo nmap --resume output_name.nmap`
- **Show reason for port state** = `sudo nmap 10.129.2.18 --reason`
- **IPv6 Scanning** = `sudo nmap -6 dead:beef::1`
- **Check Nmap Version** = `nmap -V`
- **Update Script Database** = `sudo nmap --script-updatedb`
- **Trace Network Hops** = `sudo nmap 10.129.2.18 --traceroute`
- **List scripts with help** = `nmap --script-help "http-*"`
