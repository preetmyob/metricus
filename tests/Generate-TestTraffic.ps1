# Generate-TestTraffic.ps1
# Generates HTTP traffic to IIS test sites for Metricus monitoring

param(
    [int]$DurationMinutes = 5,
    [int]$RequestsPerMinute = 60,
    [string]$SiteInfoFile = "test-sites.json"
)

# Load site information
$siteInfoPath = Join-Path $PSScriptRoot $SiteInfoFile
if (!(Test-Path $siteInfoPath)) {
    Write-Error "Site information file not found: $siteInfoPath"
    Write-Host "Please run Setup-IISTestSites.ps1 first"
    exit 1
}

$siteInfo = Get-Content $siteInfoPath | ConvertFrom-Json
$sites = $siteInfo.Sites

Write-Host "Starting traffic generation for $DurationMinutes minutes..." -ForegroundColor Green
Write-Host "Target: $RequestsPerMinute requests per minute across $($sites.Count) sites" -ForegroundColor Yellow

# Calculate timing
$totalRequests = $DurationMinutes * $RequestsPerMinute
$intervalSeconds = 60.0 / $RequestsPerMinute
$endTime = (Get-Date).AddMinutes($DurationMinutes)

Write-Host "Total requests: $totalRequests"
Write-Host "Request interval: $([math]::Round($intervalSeconds, 2)) seconds"
Write-Host "End time: $($endTime.ToString('HH:mm:ss'))"
Write-Host ""

# Define request patterns
$requestPatterns = @(
    @{ Path = "/"; Weight = 40; Description = "Home page" },
    @{ Path = "/api/fast"; Weight = 30; Description = "Fast API" },
    @{ Path = "/api/medium"; Weight = 15; Description = "Medium API" },
    @{ Path = "/api/slow"; Weight = 10; Description = "Slow API" },
    @{ Path = "/api/memory"; Weight = 3; Description = "Memory intensive" },
    @{ Path = "/api/cpu"; Weight = 2; Description = "CPU intensive" }
)

# Statistics tracking
$stats = @{
    TotalRequests = 0
    SuccessfulRequests = 0
    FailedRequests = 0
    ResponseTimes = @()
    RequestsByPattern = @{}
    RequestsBySite = @{}
}

# Initialize stats
foreach ($pattern in $requestPatterns) {
    $stats.RequestsByPattern[$pattern.Description] = 0
}
foreach ($site in $sites) {
    $stats.RequestsBySite[$site.Name] = 0
}

# Function to select request pattern based on weights
function Get-WeightedRequestPattern {
    $totalWeight = ($requestPatterns | Measure-Object -Property Weight -Sum).Sum
    $random = Get-Random -Minimum 1 -Maximum ($totalWeight + 1)
    
    $currentWeight = 0
    foreach ($pattern in $requestPatterns) {
        $currentWeight += $pattern.Weight
        if ($random -le $currentWeight) {
            return $pattern
        }
    }
    return $requestPatterns[0]  # Fallback
}

# Function to make HTTP request
function Invoke-TestRequest {
    param($Url, $Pattern)
    
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30
        $stopwatch.Stop()
        
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            ResponseTime = $stopwatch.ElapsedMilliseconds
            Error = $null
        }
    }
    catch {
        $stopwatch.Stop()
        return @{
            Success = $false
            StatusCode = 0
            ResponseTime = $stopwatch.ElapsedMilliseconds
            Error = $_.Exception.Message
        }
    }
}

# Main traffic generation loop
Write-Host "Starting traffic generation..." -ForegroundColor Green
$requestCount = 0
$lastProgressUpdate = Get-Date

while ((Get-Date) -lt $endTime) {
    $requestCount++
    
    # Select random site and pattern
    $site = $sites | Get-Random
    $pattern = Get-WeightedRequestPattern
    $url = $site.Url + $pattern.Path
    
    # Make request
    $result = Invoke-TestRequest -Url $url -Pattern $pattern
    
    # Update statistics
    $stats.TotalRequests++
    $stats.RequestsByPattern[$pattern.Description]++
    $stats.RequestsBySite[$site.Name]++
    $stats.ResponseTimes += $result.ResponseTime
    
    if ($result.Success) {
        $stats.SuccessfulRequests++
        $status = "✓"
        $color = "Green"
    } else {
        $stats.FailedRequests++
        $status = "✗"
        $color = "Red"
    }
    
    # Progress output (every 10 requests or every 30 seconds)
    $now = Get-Date
    if (($requestCount % 10 -eq 0) -or (($now - $lastProgressUpdate).TotalSeconds -ge 30)) {
        $elapsed = $now - (Get-Date).AddMinutes(-$DurationMinutes).AddSeconds($endTime.Subtract($now).TotalSeconds)
        $remaining = $endTime - $now
        
        Write-Host "[$($now.ToString('HH:mm:ss'))] $status $($site.Name) $($pattern.Description) ($($result.ResponseTime)ms) - Remaining: $([math]::Round($remaining.TotalMinutes, 1))min" -ForegroundColor $color
        $lastProgressUpdate = $now
    }
    
    # Wait for next request
    if ($intervalSeconds -gt 0.1) {
        Start-Sleep -Milliseconds ([int]($intervalSeconds * 1000))
    }
}

# Generate final statistics
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "TRAFFIC GENERATION COMPLETE" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Cyan

Write-Host "`nOverall Statistics:" -ForegroundColor Yellow
Write-Host "  Total Requests: $($stats.TotalRequests)"
Write-Host "  Successful: $($stats.SuccessfulRequests) ($([math]::Round(($stats.SuccessfulRequests / $stats.TotalRequests) * 100, 1))%)"
Write-Host "  Failed: $($stats.FailedRequests) ($([math]::Round(($stats.FailedRequests / $stats.TotalRequests) * 100, 1))%)"

if ($stats.ResponseTimes.Count -gt 0) {
    $avgResponseTime = ($stats.ResponseTimes | Measure-Object -Average).Average
    $minResponseTime = ($stats.ResponseTimes | Measure-Object -Minimum).Minimum
    $maxResponseTime = ($stats.ResponseTimes | Measure-Object -Maximum).Maximum
    
    Write-Host "`nResponse Times:" -ForegroundColor Yellow
    Write-Host "  Average: $([math]::Round($avgResponseTime, 1))ms"
    Write-Host "  Minimum: $($minResponseTime)ms"
    Write-Host "  Maximum: $($maxResponseTime)ms"
}

Write-Host "`nRequests by Pattern:" -ForegroundColor Yellow
foreach ($pattern in $stats.RequestsByPattern.GetEnumerator() | Sort-Object Value -Descending) {
    Write-Host "  $($pattern.Key): $($pattern.Value)"
}

Write-Host "`nRequests by Site:" -ForegroundColor Yellow
foreach ($site in $stats.RequestsBySite.GetEnumerator() | Sort-Object Value -Descending) {
    Write-Host "  $($site.Key): $($site.Value)"
}

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Run Metricus with SitesFilter enabled to capture IIS metrics"
Write-Host "2. Check Graphite for new IIS performance counters"
Write-Host "3. Monitor metrics at: http://10.0.0.14:8080"

# Save detailed statistics
$detailedStats = @{
    GeneratedAt = Get-Date
    Duration = $DurationMinutes
    RequestsPerMinute = $RequestsPerMinute
    Statistics = $stats
    Sites = $sites
}

$statsFile = Join-Path $PSScriptRoot "traffic-stats.json"
$detailedStats | ConvertTo-Json -Depth 10 | Out-File -FilePath $statsFile -Encoding UTF8
Write-Host "`nDetailed statistics saved to: traffic-stats.json" -ForegroundColor Green
