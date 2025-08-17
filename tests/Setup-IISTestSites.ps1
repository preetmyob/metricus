# Setup-IISTestSites.ps1
# Creates IIS test websites with ASP.NET applications for Metricus testing

param(
    [string]$BasePort = 8001,
    [int]$SiteCount = 3,
    [string]$BasePath = "C:\inetpub\metricus-test"
)

# Ensure running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Import WebAdministration module
Import-Module WebAdministration -ErrorAction Stop

Write-Host "Setting up IIS test sites for Metricus..." -ForegroundColor Green

# Create base directory
if (!(Test-Path $BasePath)) {
    New-Item -ItemType Directory -Path $BasePath -Force
    Write-Host "Created base directory: $BasePath"
}

# Function to create a simple ASP.NET page
function Create-TestPage {
    param([string]$SitePath, [string]$SiteName)
    
    $defaultPage = @"
<%@ Page Language="C#" %>
<!DOCTYPE html>
<html>
<head>
    <title>$SiteName - Metricus Test Site</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .content { margin: 20px 0; }
        .metrics { background: #e8f4fd; padding: 15px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>$SiteName</h1>
        <p>Test site for Metricus performance monitoring</p>
    </div>
    
    <div class="content">
        <h2>Site Information</h2>
        <p><strong>Site Name:</strong> $SiteName</p>
        <p><strong>Server Time:</strong> <%= DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") %></p>
        <p><strong>Machine Name:</strong> <%= Environment.MachineName %></p>
        <p><strong>Process ID:</strong> <%= System.Diagnostics.Process.GetCurrentProcess().Id %></p>
    </div>
    
    <div class="metrics">
        <h3>Performance Test Endpoints</h3>
        <ul>
            <li><a href="api/fast">Fast Response (< 100ms)</a></li>
            <li><a href="api/medium">Medium Response (500ms)</a></li>
            <li><a href="api/slow">Slow Response (2s)</a></li>
            <li><a href="api/memory">Memory Intensive</a></li>
            <li><a href="api/cpu">CPU Intensive</a></li>
        </ul>
    </div>
</body>
</html>
"@

    $apiPage = @"
<%@ Page Language="C#" %>
<%
    string action = Request.QueryString["action"] ?? "fast";
    
    switch(action.ToLower()) {
        case "medium":
            System.Threading.Thread.Sleep(500);
            Response.Write("Medium response completed in 500ms");
            break;
        case "slow":
            System.Threading.Thread.Sleep(2000);
            Response.Write("Slow response completed in 2000ms");
            break;
        case "memory":
            // Allocate some memory
            var data = new byte[1024 * 1024]; // 1MB
            for(int i = 0; i < data.Length; i++) data[i] = (byte)(i % 256);
            Response.Write("Memory intensive operation completed - allocated 1MB");
            break;
        case "cpu":
            // CPU intensive operation
            double result = 0;
            for(int i = 0; i < 1000000; i++) {
                result += Math.Sqrt(i) * Math.Sin(i);
            }
            Response.Write("CPU intensive operation completed - result: " + result.ToString("F2"));
            break;
        default:
            Response.Write("Fast response completed");
            break;
    }
%>
"@

    # Create site directory
    $siteDir = Join-Path $SitePath $SiteName
    if (!(Test-Path $siteDir)) {
        New-Item -ItemType Directory -Path $siteDir -Force
    }
    
    # Create API directory
    $apiDir = Join-Path $siteDir "api"
    if (!(Test-Path $apiDir)) {
        New-Item -ItemType Directory -Path $apiDir -Force
    }
    
    # Write pages
    $defaultPage | Out-File -FilePath (Join-Path $siteDir "default.aspx") -Encoding UTF8
    $apiPage | Out-File -FilePath (Join-Path $apiDir "fast.aspx") -Encoding UTF8
    $apiPage | Out-File -FilePath (Join-Path $apiDir "medium.aspx") -Encoding UTF8
    $apiPage | Out-File -FilePath (Join-Path $apiDir "slow.aspx") -Encoding UTF8
    $apiPage | Out-File -FilePath (Join-Path $apiDir "memory.aspx") -Encoding UTF8
    $apiPage | Out-File -FilePath (Join-Path $apiDir "cpu.aspx") -Encoding UTF8
}

# Create test sites
$sites = @()
for ($i = 1; $i -le $SiteCount; $i++) {
    $siteName = "MetricusTest$i"
    $port = [int]$BasePort + $i - 1
    $siteDir = Join-Path $BasePath $siteName
    
    Write-Host "Creating site: $siteName on port $port" -ForegroundColor Yellow
    
    # Remove existing site if it exists
    if (Get-Website -Name $siteName -ErrorAction SilentlyContinue) {
        Remove-Website -Name $siteName
        Write-Host "Removed existing site: $siteName"
    }
    
    # Create site directory and content
    Create-TestPage -SitePath $BasePath -SiteName $siteName
    
    # Create IIS site
    New-Website -Name $siteName -Port $port -PhysicalPath $siteDir
    
    # Configure application pool for .NET Framework
    $appPoolName = "MetricusTest$i"
    if (Get-IISAppPool -Name $appPoolName -ErrorAction SilentlyContinue) {
        Remove-WebAppPool -Name $appPoolName
    }
    
    New-WebAppPool -Name $appPoolName
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name processModel.identityType -Value ApplicationPoolIdentity
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name managedRuntimeVersion -Value "v4.0"
    Set-ItemProperty -Path "IIS:\Sites\$siteName" -Name applicationPool -Value $appPoolName
    
    $sites += @{
        Name = $siteName
        Port = $port
        Url = "http://localhost:$port"
        Path = $siteDir
    }
    
    Write-Host "Created site: $siteName at http://localhost:$port" -ForegroundColor Green
}

# Start all sites
Write-Host "`nStarting all test sites..." -ForegroundColor Green
foreach ($site in $sites) {
    Start-Website -Name $site.Name
    Write-Host "Started: $($site.Name) - $($site.Url)"
}

Write-Host "`nTest sites created successfully!" -ForegroundColor Green
Write-Host "Sites created:" -ForegroundColor Cyan
foreach ($site in $sites) {
    Write-Host "  - $($site.Name): $($site.Url)" -ForegroundColor White
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run 'Generate-TestTraffic.ps1' to create traffic"
Write-Host "2. Run Metricus to capture the metrics"
Write-Host "3. Check Graphite for IIS performance counters"

# Save site information for traffic generation script
$siteInfo = @{
    Sites = $sites
    Created = Get-Date
}
$siteInfo | ConvertTo-Json | Out-File -FilePath (Join-Path $PSScriptRoot "test-sites.json") -Encoding UTF8

Write-Host "`nSite information saved to test-sites.json" -ForegroundColor Green
