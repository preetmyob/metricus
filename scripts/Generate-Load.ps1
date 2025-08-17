<#
.SYNOPSIS
    Generates continuous load against the Metricus test website.
#>

param(
    [int]$DurationMinutes = 60,
    [int]$RequestsPerMinute = 30,
    [string]$BaseUrl = "http://localhost:8080"
)

Write-Host "Starting load generation..." -ForegroundColor Green
Write-Host "Target: $BaseUrl" -ForegroundColor Gray
Write-Host "Duration: $DurationMinutes minutes" -ForegroundColor Gray
Write-Host "Rate: $RequestsPerMinute requests/minute" -ForegroundColor Gray
Write-Host ""

$actions = @("", "cpu", "memory", "io", "exception")
$startTime = Get-Date
$endTime = $startTime.AddMinutes($DurationMinutes)
$requestCount = 0

while ((Get-Date) -lt $endTime) {
    try {
        $action = $actions | Get-Random
        
        if ($action -eq "") {
            $response = Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -TimeoutSec 30
        } else {
            $body = "action=$action"
            $response = Invoke-WebRequest -Uri $BaseUrl -Method POST -Body $body -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -TimeoutSec 30
        }
        
        $requestCount++
        
        if ($requestCount % 10 -eq 0) {
            $elapsed = (Get-Date) - $startTime
            $rate = [math]::Round($requestCount / $elapsed.TotalMinutes, 1)
            Write-Host "Requests: $requestCount | Rate: $rate/min | Action: $action" -ForegroundColor Gray
        }
        
        # Wait to maintain desired rate
        $sleepMs = [math]::Max(1000, (60000 / $RequestsPerMinute))
        Start-Sleep -Milliseconds $sleepMs
    }
    catch {
        Write-Warning "Request failed: $($_.Exception.Message)"
        Start-Sleep -Seconds 5
    }
}

Write-Host ""
Write-Host "Load generation completed!" -ForegroundColor Green
Write-Host "Total requests: $requestCount" -ForegroundColor Gray
