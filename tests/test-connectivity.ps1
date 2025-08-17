# PowerShell commands to test Graphite connectivity from Parallels VM

# Test connectivity to port 2003 (Carbon receiver - correct port for Metricus)
Test-NetConnection -ComputerName "10.211.55.2" -Port 2003

# Test connectivity to port 2010 (if you have a custom configuration)
Test-NetConnection -ComputerName "10.211.55.2" -Port 2010

# Alternative using telnet-style test
$tcpClient = New-Object System.Net.Sockets.TcpClient
try {
    $tcpClient.Connect("10.211.55.2", 2003)
    Write-Host "Connection to 10.211.55.2:2003 successful" -ForegroundColor Green
    $tcpClient.Close()
} catch {
    Write-Host "Connection to 10.211.55.2:2003 failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test web interface
try {
    $response = Invoke-WebRequest -Uri "http://10.211.55.2:8080" -TimeoutSec 5
    Write-Host "Graphite web interface accessible: HTTP $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Graphite web interface not accessible: $($_.Exception.Message)" -ForegroundColor Red
}
