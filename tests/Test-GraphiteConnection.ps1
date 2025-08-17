param(
    [Parameter(Mandatory=$true)]
    [string]$IPAddress,
    
    [Parameter(Mandatory=$true)]
    [int]$Port,
    
    [Parameter(Mandatory=$true)]
    [string]$MetricName,
    
    [Parameter(Mandatory=$true)]
    [double]$Value
)

try {
    # Create TCP client
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    
    Write-Host "Connecting to $IPAddress`:$Port..." -ForegroundColor Yellow
    
    # Connect to Graphite Carbon receiver
    $tcpClient.Connect($IPAddress, $Port)
    
    if ($tcpClient.Connected) {
        Write-Host "✅ Connected successfully!" -ForegroundColor Green
        
        # Get current Unix timestamp
        $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
        
        # Format metric in Graphite plaintext protocol: "metric.name value timestamp\n"
        $metric = "$MetricName $Value $timestamp`n"
        
        Write-Host "Sending metric: $($metric.Trim())" -ForegroundColor Cyan
        
        # Get network stream and send metric
        $stream = $tcpClient.GetStream()
        $data = [System.Text.Encoding]::ASCII.GetBytes($metric)
        $stream.Write($data, 0, $data.Length)
        $stream.Flush()
        
        Write-Host "✅ Metric sent successfully!" -ForegroundColor Green
        
        # Close connection
        $stream.Close()
        $tcpClient.Close()
        
        Write-Host "Connection closed. Check Graphite web interface for the metric." -ForegroundColor Yellow
    }
    else {
        Write-Host "❌ Failed to connect" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($tcpClient) {
        $tcpClient.Dispose()
    }
}

Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Gray
Write-Host "  .\Test-GraphiteConnection.ps1 -IPAddress 10.0.0.1 -Port 2003 -MetricName 'test.cpu.usage' -Value 75.5" -ForegroundColor Gray
Write-Host "  .\Test-GraphiteConnection.ps1 -IPAddress 10.0.0.1 -Port 2003 -MetricName 'test.memory.free' -Value 1024" -ForegroundColor Gray
