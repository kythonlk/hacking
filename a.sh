#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$#" -ne 2 ]; then
  echo -e "${RED}Usage: $0 <IP> <Hostname>${NC}"
  echo -e "Example: $0 10.10.2.10 inflight.htb"
  exit 1
fi

IP=$1
HOST=$2
BASHRC="$HOME/.bashrc"

echo -e "${BLUE}[*] Checking for rockyou.txt...${NC}"
ROCKYOU_DIR="/usr/share/wordlists"
if [ ! -f "$ROCKYOU_DIR/rockyou.txt" ] && [ -f "$ROCKYOU_DIR/rockyou.txt.gz" ]; then
  echo -e "${YELLOW}[!] Unzipping rockyou.txt.gz (requires sudo)...${NC}"
  sudo gunzip -k "$ROCKYOU_DIR/rockyou.txt.gz"
  echo -e "${GREEN}[+] rockyou.txt is ready!${NC}"
else
  echo -e "${GREEN}[+] rockyou.txt already exists.${NC}"
fi

echo -e "\n${BLUE}[*] Checking ~/.bashrc for aliases...${NC}"

grep -q "alias v='nvim'" "$BASHRC" || {
  echo "alias v='nvim'" >>"$BASHRC"
  echo -e "${GREEN}[+] Added alias: v='nvim'${NC}"
}
grep -q "alias o='xdg-open'" "$BASHRC" || {
  echo "alias o='xdg-open'" >>"$BASHRC"
  echo -e "${GREEN}[+] Added alias: o='xdg-open'${NC}"
}

echo -e "\n${BLUE}[*] Checking /etc/hosts for $HOST...${NC}"
if grep -q "$HOST" /etc/hosts; then
  echo -e "${YELLOW}[!] $HOST already exists in /etc/hosts. Skipping...${NC}"
else
  sudo sed -i "/^$IP/d" /etc/hosts
  echo -e "$IP\t$HOST" | sudo tee -a /etc/hosts >/dev/null
  echo -e "${GREEN}[+] Added $IP $HOST to /etc/hosts!${NC}"
fi

echo -e "\n${BLUE}[*] Creating workspace directory...${NC}"
mkdir -p "$HOST"/{nmap,web,smb,exploits,loot}
cd "$HOST" || exit

echo -e "${BLUE}[*] Fast Port Scan${NC}"
sudo nmap "$IP" -p 21,22,23,25,53,80,111,139,443,445,1433,2049,3306,3389,5985,8080 -sV -sC -T4 -oA nmap/01_fast_initial

echo -e "${YELLOW}[*] All Port Scan Sweeping all 65,535 ports...${NC}"
sudo nmap -p- --min-rate 5000 -Pn -n -T4 "$IP" -oG nmap/02_all_ports.gnmap

OPEN_PORTS=$(grep -oP '\d{1,5}/open' nmap/02_all_ports.gnmap | cut -d '/' -f 1 | tr '\n' ',' | sed 's/,$//')

if [ -z "$OPEN_PORTS" ]; then
  echo -e "${RED}[-] No additional open ports found. VPN issue or host is dead?${NC}"
else
  echo -e "${GREEN}[+] Full port sweep complete! Open ports: $OPEN_PORTS${NC}"
  echo -e "${YELLOW}[*] Running deep service enumeration on ALL found ports...${NC}"

  sudo nmap -p "$OPEN_PORTS" -sC -sV -Pn -n -T4 --reason -oA nmap/03_comprehensive_tcp "$IP"
fi

echo -e "\n${GREEN}[+] All scans complete! Check the $HOST/nmap/ directory.${NC}"
