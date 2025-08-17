#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets up a complete IIS test environment for Metricus metric collection.

.DESCRIPTION
    This script creates:
    - IIS application pool with .NET Framework
    - Test website with sample ASP.NET application
    - Load generation script to simulate traffic
    - Performance counter monitoring setup

.PARAMETER SiteName
    Name of the test website. Default: MetricusTestSite

.PARAMETER Port
    Port for the test website. Default: 8080

.PARAMETER AppPoolName
    Name of the application pool. Default: MetricusTestPool

.PARAMETER SitePath
    Physical path for the website. Default: C:\inetpub\wwwroot\MetricusTest

.PARAMETER GenerateLoad
    Whether to start load generation after setup. Default: $true

.EXAMPLE
    .\Setup-TestIIS.ps1
    
.EXAMPLE
    .\Setup-TestIIS.ps1 -SiteName "MyTestSite" -Port 9090 -GenerateLoad $false
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SiteName = "MetricusTestSite",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 8080,
    
    [Parameter(Mandatory=$false)]
    [string]$AppPoolName = "MetricusTestPool",
    
    [Parameter(Mandatory=$false)]
    [string]$SitePath = "C:\inetpub\wwwroot\MetricusTest",
    
    [Parameter(Mandatory=$false)]
    [bool]$GenerateLoad = $true
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "> $Message" -ForegroundColor Green
}

function Write-Success {
    param([string]$Message)
    Write-Host "  + $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  i $Message" -ForegroundColor Gray
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  ! $Message" -ForegroundColor Yellow
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Enable-IISFeatures {
    Write-Step "Enabling IIS features..."
    
    $features = @(
        "IIS-WebServerRole",
        "IIS-WebServer",
        "IIS-CommonHttpFeatures",
        "IIS-HttpErrors",
        "IIS-HttpLogging",
        "IIS-RequestMonitor",
        "IIS-HttpTracing",
        "IIS-Security",
        "IIS-RequestFiltering",
        "IIS-Performance",
        "IIS-WebServerManagementTools",
        "IIS-ManagementConsole",
        "IIS-IIS6ManagementCompatibility",
        "IIS-Metabase",
        "IIS-ASPNET45",
        "IIS-NetFxExtensibility45",
        "IIS-ISAPIExtensions",
        "IIS-ISAPIFilter"
    )
    
    foreach ($feature in $features) {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart | Out-Null
            Write-Success "Enabled $feature"
        }
        catch {
            Write-Warning "Failed to enable $feature - may already be enabled"
        }
    }
}

function Import-WebAdministration {
    Write-Step "Loading IIS management module..."
    
    try {
        Import-Module WebAdministration -SkipEditionCheck -ErrorAction Stop
        Write-Success "WebAdministration module loaded"
    }
    catch {
        throw "Failed to load WebAdministration module. Ensure IIS is installed."
    }
}

function Create-ApplicationPool {
    Write-Step "Creating application pool '$AppPoolName'..."
    
    # Remove existing pool if it exists
    if (Get-WebAppPoolState -Name $AppPoolName -ErrorAction SilentlyContinue) {
        Remove-WebAppPool -Name $AppPoolName
        Write-Info "Removed existing application pool"
    }
    
    # Create new application pool
    New-WebAppPool -Name $AppPoolName
    
    # Configure application pool settings
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "managedRuntimeVersion" -Value "v4.0"
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "recycling.periodicRestart.time" -Value "00:00:00"
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "processModel.maxProcesses" -Value 1
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "processModel.idleTimeout" -Value "00:00:00"
    
    Write-Success "Application pool '$AppPoolName' created and configured"
}

function Create-Website {
    Write-Step "Creating website '$SiteName'..."
    
    # Remove existing site if it exists
    if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
        Remove-Website -Name $SiteName
        Write-Info "Removed existing website"
    }
    
    # Create site directory
    if (-not (Test-Path $SitePath)) {
        New-Item -ItemType Directory -Path $SitePath -Force | Out-Null
        Write-Success "Created site directory: $SitePath"
    }
    
    # Create website
    New-Website -Name $SiteName -Port $Port -PhysicalPath $SitePath -ApplicationPool $AppPoolName
    
    Write-Success "Website '$SiteName' created on port $Port"
}

function Create-TestApplication {
    Write-Step "Creating test ASP.NET application..."
    
    # Create web.config
    $webConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.web>
    <compilation targetFramework="4.8" />
    <httpRuntime targetFramework="4.8" />
  </system.web>
  <system.webServer>
    <defaultDocument>
      <files>
        <clear />
        <add value="default.aspx" />
      </files>
    </defaultDocument>
  </system.webServer>
</configuration>
"@
    
    $webConfig | Set-Content -Path (Join-Path $SitePath "web.config") -Encoding UTF8
    
    # Create default.aspx
    $defaultAspx = @"
<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Threading" %>
<%@ Import Namespace="System.Diagnostics" %>

<!DOCTYPE html>
<html>
<head>
    <title>Metricus Test Site</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .metric { background: #f0f0f0; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .button { background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; margin: 5px; cursor: pointer; }
        .button:hover { background: #005a87; }
    </style>
</head>
<body>
    <h1>Metricus Test Site</h1>
    <p>This site generates various metrics for Metricus to collect.</p>
    
    <div class="metric">
        <strong>Current Time:</strong> <%= DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") %>
    </div>
    
    <div class="metric">
        <strong>Process ID:</strong> <%= Process.GetCurrentProcess().Id %>
    </div>
    
    <div class="metric">
        <strong>Thread Count:</strong> <%= Process.GetCurrentProcess().Threads.Count %>
    </div>
    
    <div class="metric">
        <strong>Working Set:</strong> <%= (Process.GetCurrentProcess().WorkingSet64 / 1024 / 1024).ToString("F2") %> MB
    </div>
    
    <div class="metric">
        <strong>Request Count:</strong> <%= Application["RequestCount"] ?? 0 %>
    </div>
    
    <h2>Load Generation</h2>
    <form method="post">
        <button type="submit" name="action" value="cpu" class="button">Generate CPU Load</button>
        <button type="submit" name="action" value="memory" class="button">Generate Memory Load</button>
        <button type="submit" name="action" value="io" class="button">Generate I/O Load</button>
        <button type="submit" name="action" value="exception" class="button">Generate Exception</button>
    </form>
    
    <script runat="server">
        protected void Page_Load(object sender, EventArgs e)
        {
            // Increment request counter
            if (Application["RequestCount"] == null)
                Application["RequestCount"] = 0;
            Application["RequestCount"] = (int)Application["RequestCount"] + 1;
            
            string action = Request.Form["action"];
            
            switch (action)
            {
                case "cpu":
                    GenerateCpuLoad();
                    break;
                case "memory":
                    GenerateMemoryLoad();
                    break;
                case "io":
                    GenerateIoLoad();
                    break;
                case "exception":
                    GenerateException();
                    break;
            }
        }
        
        private void GenerateCpuLoad()
        {
            var stopwatch = Stopwatch.StartNew();
            while (stopwatch.ElapsedMilliseconds < 2000) // 2 seconds of CPU work
            {
                Math.Sqrt(DateTime.Now.Ticks);
            }
        }
        
        private void GenerateMemoryLoad()
        {
            var data = new List<byte[]>();
            for (int i = 0; i < 100; i++)
            {
                data.Add(new byte[1024 * 1024]); // 1MB chunks
            }
            Thread.Sleep(1000);
            data.Clear();
            GC.Collect();
        }
        
        private void GenerateIoLoad()
        {
            string tempFile = Path.GetTempFileName();
            try
            {
                for (int i = 0; i < 1000; i++)
                {
                    File.WriteAllText(tempFile, "Test data " + i);
                    File.ReadAllText(tempFile);
                }
            }
            finally
            {
                if (File.Exists(tempFile))
                    File.Delete(tempFile);
            }
        }
        
        private void GenerateException()
        {
            try
            {
                throw new InvalidOperationException("Test exception for metrics");
            }
            catch (Exception ex)
            {
                // Log but don't crash
                System.Diagnostics.Trace.WriteLine("Generated exception: " + ex.Message);
            }
        }
    </script>
    
    <h2>Auto-Refresh</h2>
    <p>This page will auto-refresh every 30 seconds to generate continuous metrics.</p>
    <script>
        setTimeout(function() {
            window.location.reload();
        }, 30000);
    </script>
</body>
</html>
"@
    
    $defaultAspx | Set-Content -Path (Join-Path $SitePath "default.aspx") -Encoding UTF8
    
    Write-Success "Test ASP.NET application created"
}

function Create-LoadGenerator {
    Write-Step "Creating load generation script..."
    
    $loadScript = @"
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates continuous load against the Metricus test website.
#>

param(
    [int]`$DurationMinutes = 60,
    [int]`$RequestsPerMinute = 30,
    [string]`$BaseUrl = "http://localhost:$Port"
)

Write-Host "Starting load generation..." -ForegroundColor Green
Write-Host "Target: `$BaseUrl" -ForegroundColor Gray
Write-Host "Duration: `$DurationMinutes minutes" -ForegroundColor Gray
Write-Host "Rate: `$RequestsPerMinute requests/minute" -ForegroundColor Gray
Write-Host ""

`$actions = @("", "cpu", "memory", "io", "exception")
`$startTime = Get-Date
`$endTime = `$startTime.AddMinutes(`$DurationMinutes)
`$requestCount = 0

while ((Get-Date) -lt `$endTime) {
    try {
        `$action = `$actions | Get-Random
        
        if (`$action -eq "") {
            `$response = Invoke-WebRequest -Uri `$BaseUrl -UseBasicParsing -TimeoutSec 30
        } else {
            `$body = "action=`$action"
            `$response = Invoke-WebRequest -Uri `$BaseUrl -Method POST -Body `$body -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -TimeoutSec 30
        }
        
        `$requestCount++
        
        if (`$requestCount % 10 -eq 0) {
            `$elapsed = (Get-Date) - `$startTime
            `$rate = [math]::Round(`$requestCount / `$elapsed.TotalMinutes, 1)
            Write-Host "Requests: `$requestCount | Rate: `$rate/min | Action: `$action" -ForegroundColor Gray
        }
        
        # Wait to maintain desired rate
        `$sleepMs = [math]::Max(1000, (60000 / `$RequestsPerMinute))
        Start-Sleep -Milliseconds `$sleepMs
    }
    catch {
        Write-Warning "Request failed: `$(`$_.Exception.Message)"
        Start-Sleep -Seconds 5
    }
}

Write-Host ""
Write-Host "Load generation completed!" -ForegroundColor Green
Write-Host "Total requests: `$requestCount" -ForegroundColor Gray
"@
    
    $loadScriptPath = Join-Path $PSScriptRoot "Generate-Load.ps1"
    $loadScript | Set-Content -Path $loadScriptPath -Encoding UTF8
    
    Write-Success "Load generator created: $loadScriptPath"
    return $loadScriptPath
}

function Start-Services {
    Write-Step "Starting IIS services..."
    
    # Start IIS services
    Start-Service W3SVC -ErrorAction SilentlyContinue
    Start-Service WAS -ErrorAction SilentlyContinue
    
    # Start application pool
    Start-WebAppPool -Name $AppPoolName
    
    Write-Success "IIS services started"
}

function Test-Website {
    Write-Step "Testing website..."
    
    Start-Sleep -Seconds 3  # Give IIS time to start
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Success "Website is responding correctly"
            return $true
        }
    }
    catch {
        Write-Warning "Website test failed: $($_.Exception.Message)"
        return $false
    }
    
    return $false
}

function Show-Summary {
    param($LoadScriptPath)
    
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host " IIS Test Environment Setup Complete" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    Write-Host "[Website]" -ForegroundColor Cyan
    Write-Host "  Name: $SiteName" -ForegroundColor White
    Write-Host "  URL: http://localhost:$Port" -ForegroundColor White
    Write-Host "  Path: $SitePath" -ForegroundColor White
    
    Write-Host "[Application Pool]" -ForegroundColor Cyan
    Write-Host "  Name: $AppPoolName" -ForegroundColor White
    Write-Host "  .NET Version: 4.0" -ForegroundColor White
    Write-Host "  Identity: ApplicationPoolIdentity" -ForegroundColor White
    
    Write-Host "[Performance Counters Available]" -ForegroundColor Cyan
    Write-Host "  + ASP.NET Applications" -ForegroundColor Gray
    Write-Host "  + ASP.NET Apps v4.0.30319" -ForegroundColor Gray
    Write-Host "  + Web Service" -ForegroundColor Gray
    Write-Host "  + Process (w3wp)" -ForegroundColor Gray
    Write-Host "  + .NET CLR Memory" -ForegroundColor Gray
    Write-Host "  + .NET CLR LocksAndThreads" -ForegroundColor Gray
    
    Write-Host "[Load Generation]" -ForegroundColor Cyan
    Write-Host "  Script: $LoadScriptPath" -ForegroundColor White
    
    Write-Host "[Quick Commands]" -ForegroundColor Yellow
    Write-Host "# Test the website" -ForegroundColor Gray
    Write-Host "Start-Process 'http://localhost:$Port'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "# Generate load" -ForegroundColor Gray
    Write-Host "& '$LoadScriptPath'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "# View performance counters" -ForegroundColor Gray
    Write-Host "Get-Counter '\ASP.NET Applications(*)\Requests/Sec'" -ForegroundColor Gray
    Write-Host ""
}

# Main execution
try {
    Write-Host "Metricus IIS Test Environment Setup" -ForegroundColor Yellow
    Write-Host "Site: $SiteName | Port: $Port | Pool: $AppPoolName" -ForegroundColor Gray
    Write-Host ""
    
    if (-not (Test-Administrator)) {
        throw "This script must be run as Administrator to configure IIS."
    }
    
    Enable-IISFeatures
    Import-WebAdministration
    Create-ApplicationPool
    Create-Website
    Create-TestApplication
    $loadScriptPath = Create-LoadGenerator
    Start-Services
    
    if (Test-Website) {
        Show-Summary $loadScriptPath
        
        if ($GenerateLoad) {
            Write-Host "Starting load generation..." -ForegroundColor Green
            Start-Process powershell -ArgumentList "-File `"$loadScriptPath`" -DurationMinutes 10"
        }
        
        Write-Host "Setup completed successfully!" -ForegroundColor Green
    } else {
        Write-Warning "Website setup completed but site is not responding. Check IIS configuration."
    }
    
    exit 0
}
catch {
    Write-Host ""
    Write-Host "Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common solutions:" -ForegroundColor Yellow
    Write-Host "1. Run as Administrator" -ForegroundColor Gray
    Write-Host "2. Enable IIS features manually via Windows Features" -ForegroundColor Gray
    Write-Host "3. Install .NET Framework 4.8" -ForegroundColor Gray
    Write-Host "4. Check port $Port is not in use" -ForegroundColor Gray
    exit 1
}
