# PowerShell script to send test metrics to Graphite from Windows VM
# Usage: .\send-test-metrics.ps1
# Press Ctrl+C to stop

param(
    [string]$GraphiteHost = "10.0.0.14",
    [int]$GraphitePort = 2003,
    [int]$IntervalSeconds = 10
)

Write-Host "Starting Metricus Test Metric Generator"
Write-Host "Target: $GraphiteHost:$GraphitePort"
Write-Host "Interval: $IntervalSeconds seconds"
Write-Host "Press Ctrl+C to stop"
Write-Host ""

$counter = 0

while ($true) {
    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $counter++
        
        # Generate realistic test data
        $cpuUsage = [math]::Round((Get-Random -Minimum 20 -Maximum 90) + [math]::Sin($counter * 0.1) * 10, 1)
        $memoryUsed = [math]::Round((Get-Random -Minimum 2000000000 -Maximum 8000000000), 0)
        $responseTime = [math]::Round((Get-Random -Minimum 50 -Maximum 500) + [math]::Sin($counter * 0.2) * 50, 0)
        $diskUsage = [math]::Round((Get-Random -Minimum 30 -Maximum 80), 1)
        $networkBytes = Get-Random -Minimum 1000000 -Maximum 10000000
        
        # Create TCP connection
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($GraphiteHost, $GraphitePort)
        $stream = $tcpClient.GetStream()
        
        # Prepare metrics
        $metrics = @(
            "test.vm.cpu.usage $cpuUsage $timestamp",
            "test.vm.memory.used $memoryUsed $timestamp",
            "test.vm.response_time $responseTime $timestamp",
            "test.vm.disk.usage $diskUsage $timestamp",
            "test.vm.network.bytes $networkBytes $timestamp",
            "test.vm.connectivity 1 $timestamp"
        )
        
        # Send all metrics
        foreach ($metric in $metrics) {
            $data = [System.Text.Encoding]::ASCII.GetBytes("$metric`n")
            $stream.Write($data, 0, $data.Length)
        }
        
        $stream.Close()
        $tcpClient.Close()
        
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Sent metrics: CPU=$cpuUsage%, Memory=$([math]::Round($memoryUsed/1GB,1))GB, Response=$($responseTime)ms"
        
    } catch {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Start-Sleep -Seconds $IntervalSeconds
}
