# hacking

All in one script to init the ground

```bash
git clone https://github.com/kythonlk/hacking.git . && chmod +x a.sh && sudo ./a.sh {ip} {host}
```


## Resources 

### Jobs

[HackerOne](https://hackerone.com/directory/programs) 
[Bugcrowd](https://bugcrowd.com/programs) 

### Tools

[EyeWitness](https://github.com/FortyNorthSecurity/EyeWitness)
[LinEnum](https://github.com/rebootuser/LinEnum.git) Linux root privs check
[linuxprivchecker](https://github.com/sleventyeleven/linuxprivchecker) Linux root privs check
[Seatbelt](https://github.com/GhostPack/Seatbelt) Win root privs check
[JAWS](https://github.com/411Hall/JAWS) .Win root privs check
[CeWL](https://github.com/digininja/CeWL) Wordlist generator
[Payloads](https://github.com/swisskyrepo/PayloadsAllTheThings/) Payloads Generator
[Exploit DB](https://www.exploit-db.com/) Vulnerability Database
[Rapid7 DB](https://www.rapid7.com/db/) Vulnerability Database
[Vulnerability Lab](https://www.vulnerability-lab.com/) Vulnerability Database



sudo apt install exploitdb -y - `searchsploit` 
searchsploit openssh 7.2


gobuster dir -u http://10.10.2.10 -w /usr/share/wordlists/dirb/common.txt -t 50 --no-error -o web_scan.txt
