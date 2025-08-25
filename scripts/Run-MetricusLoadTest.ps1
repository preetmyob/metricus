#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete Metricus load test - setup, generate load, and cleanup.

.DESCRIPTION
    This script performs a complete end-to-end test of Metricus:
    1. Sets up a test IIS website with sample ASP.NET application
    2. Generates load for a specified duration (default 2 minutes)
    3. Monitors Metricus metrics collection
    4. Cleans up all test resources

    Compatible with PowerShell 5.1 and PowerShell 7.x

.PARAMETER LoadDurationMinutes
    Duration to generate load in minutes. Default: 2

.PARAMETER RequestsPerMinute
    Number of requests per minute to generate. Default: 60

.PARAMETER SiteName
    Name of the test website. Default: MetricusLoadTest

.PARAMETER Port
    Port for the test website. Default: 8080

.PARAMETER SkipCleanup
    Skip cleanup after test completion. Default: $false

.PARAMETER Force
    Skip confirmation prompts. Default: $false

.EXAMPLE
    .\Run-MetricusLoadTest.ps1
    Runs a 2-minute load test with default settings

.EXAMPLE
    .\Run-MetricusLoadTest.ps1 -LoadDurationMinutes 5 -RequestsPerMinute 120
    Runs a 5-minute load test with higher request rate

.EXAMPLE
    .\Run-MetricusLoadTest.ps1 -SkipCleanup -Force
    Runs test without cleanup and without prompts

.NOTES
    Requires Windows with IIS installed and Administrator privileges.
    Compatible with PowerShell 5.1+ and PowerShell 7.x
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$LoadDurationMinutes = 2,
    
    [Parameter(Mandatory=$false)]
    [int]$RequestsPerMinute = 60,
    
    [Parameter(Mandatory=$false)]
    [string]$SiteName = "MetricusLoadTest",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 8080,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipCleanup,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$script:TestStartTime = Get-Date
$script:AppPoolName = "${SiteName}Pool"
$script:SitePath = "C:\inetpub\wwwroot\$SiteName"
$script:BaseUrl = "http://localhost:$Port"

# Color functions for better output
function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "> $Message" -ForegroundColor Yellow
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

function Write-Error {
    param([string]$Message)
    Write-Host "  x $Message" -ForegroundColor Red
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-CompatibleWebRequest {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [string]$Body = $null,
        [string]$ContentType = $null,
        [int]$TimeoutSec = 30
    )
    
    try {
        # Handle SSL/TLS differences between PS versions
        if ($PSVersionTable.PSVersion.Major -eq 5) {
            # PowerShell 5.1 - ensure TLS 1.2 is available
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        }
        
        # Build parameters more carefully for PowerShell 5.1 compatibility
        if ($Method -eq "GET") {
            return Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec $TimeoutSec
        } else {
            if ($Body -and $ContentType) {
                return Invoke-WebRequest -Uri $Uri -Method $Method -Body $Body -ContentType $ContentType -UseBasicParsing -TimeoutSec $TimeoutSec
            } elseif ($Body) {
                return Invoke-WebRequest -Uri $Uri -Method $Method -Body $Body -UseBasicParsing -TimeoutSec $TimeoutSec
            } else {
                return Invoke-WebRequest -Uri $Uri -Method $Method -UseBasicParsing -TimeoutSec $TimeoutSec
            }
        }
    }
    catch {
        # Re-throw with more context, handle null exception messages
        $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { "Unknown HTTP error" }
        throw "HTTP request failed: $errorMessage"
    }
}

function Find-AvailablePort {
    param(
        [int]$StartPort = 8080,
        [int]$MaxAttempts = 10
    )
    
    for ($i = 0; $i -lt $MaxAttempts; $i++) {
        $testPort = $StartPort + $i
        $portInUse = $false
        
        try {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                # PowerShell 7+ - try Get-NetTCPConnection, fallback to netstat
                try {
                    $portInUse = (Get-NetTCPConnection -LocalPort $testPort -ErrorAction SilentlyContinue) -ne $null
                }
                catch {
                    # Fallback to netstat
                    $netstatOutput = & netstat -an 2>$null | Select-String ":$testPort "
                    $portInUse = $netstatOutput -ne $null
                }
            } else {
                # PowerShell 5.1
                $portInUse = (Get-NetTCPConnection -LocalPort $testPort -ErrorAction SilentlyContinue) -ne $null
            }
            
            if (-not $portInUse) {
                return $testPort
            }
        }
        catch {
            # If we can't check, assume it's available and let IIS handle the conflict
            return $testPort
        }
    }
    
    throw "Could not find an available port after checking $MaxAttempts ports starting from $StartPort"
}

function Test-Prerequisites {
    Write-Step "Checking prerequisites..."
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Info "PowerShell version: $($psVersion.Major).$($psVersion.Minor)"
    
    if (-not (Test-Administrator)) {
        throw "This script must be run as Administrator to modify IIS configuration."
    }
    Write-Success "Running as Administrator"
    
    # Check if IIS is installed - compatible with both PS 5.1 and 7
    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            # PowerShell 7+ - use alternative method
            $iisService = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
            if (-not $iisService) {
                throw "IIS World Wide Web Publishing Service not found. Please install IIS first."
            }
            Write-Success "IIS service found"
        } else {
            # PowerShell 5.1 - use Windows-specific cmdlet
            $iisFeature = Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -ErrorAction SilentlyContinue
            if (-not $iisFeature -or $iisFeature.State -ne "Enabled") {
                throw "IIS is not installed or enabled. Please install IIS first."
            }
            Write-Success "IIS is installed and enabled"
        }
    }
    catch {
        throw "Could not verify IIS installation: $($_.Exception.Message)"
    }
    
    # Check if WebAdministration module is available - compatible approach
    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            # PowerShell 7+ - import with special handling for compatibility session
            Write-Info "Loading WebAdministration module via Windows PowerShell compatibility..."
            Import-Module WebAdministration -Force -ErrorAction Stop
            
            # Verify the IIS drive is available, if not try to create it
            if (-not (Get-PSDrive -Name IIS -ErrorAction SilentlyContinue)) {
                Write-Info "IIS drive not found, attempting to initialize..."
                # Force re-import to establish the drive
                Remove-Module WebAdministration -Force -ErrorAction SilentlyContinue
                Import-Module WebAdministration -Force -ErrorAction Stop
            }
        } else {
            # PowerShell 5.1 - standard import (no SkipEditionCheck parameter)
            Import-Module WebAdministration -ErrorAction Stop
        }
        Write-Success "WebAdministration module loaded"
        
        # Test basic IIS functionality
        try {
            $null = Get-Website -ErrorAction Stop
            Write-Info "IIS cmdlets are working correctly"
        }
        catch {
            throw "IIS cmdlets not functioning properly: $($_.Exception.Message)"
        }
    }
    catch {
        throw "WebAdministration module not available: $($_.Exception.Message)"
    }
    
    # Check if port is available - compatible approach with auto-fix
    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            # PowerShell 7+ - use Get-NetTCPConnection if available, fallback to netstat
            try {
                $portInUse = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue 2>$null
            }
            catch {
                # Fallback to netstat for cross-platform compatibility
                $netstatOutput = & netstat -an 2>$null | Select-String ":$Port "
                $portInUse = $netstatOutput -ne $null
            }
        } else {
            # PowerShell 5.1 - use Get-NetTCPConnection
            $portInUse = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        }
        
        if ($portInUse) {
            Write-Warning "Port $Port is already in use. Finding alternative port..."
            $script:Port = Find-AvailablePort -StartPort ($Port + 1)
            $script:BaseUrl = "http://localhost:$script:Port"
            Write-Success "Using alternative port: $script:Port"
        } else {
            Write-Success "Port $Port is available"
        }
    }
    catch {
        Write-Warning "Could not verify port availability: $($_.Exception.Message)"
        Write-Info "Continuing with port $Port - conflict will be detected during site creation"
    }
}

function New-TestApplication {
    Write-Step "Creating test application..."
    
    # Create directory
    if (Test-Path $script:SitePath) {
        Remove-Item -Path $script:SitePath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $script:SitePath -Force | Out-Null
    Write-Success "Created directory: $script:SitePath"
    
    # Create Default.aspx - using the proven approach from Setup-TestIIS
    $defaultAspx = @'
<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Threading" %>
<%@ Import Namespace="System.Diagnostics" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Collections.Generic" %>

<!DOCTYPE html>
<html>
<head>
    <title>Metricus Load Test Site</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f8f9fa; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; margin-bottom: 20px; }
        .metric { background: #e3f2fd; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #2196f3; }
        .button { background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; margin: 5px; cursor: pointer; text-decoration: none; display: inline-block; }
        .button:hover { background: #005a87; }
        .result { background: #e8f5e8; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #4caf50; }
        .timestamp { font-size: 0.9em; color: #666; text-align: center; margin-top: 20px; padding-top: 20px; border-top: 1px solid #eee; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>[METRICUS] Load Test Site</h1>
            <p>Test application for monitoring IIS performance metrics</p>
        </div>
        
        <div class="metric">
            <strong>Current Time:</strong> <%= DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") %>
        </div>
        
        <div class="metric">
            <strong>Server:</strong> <%= Environment.MachineName %>
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
        
        <h2>Load Generation Actions</h2>
        <form method="post">
            <button type="submit" name="action" value="cpu" class="button">[CPU] Generate CPU Load</button>
            <button type="submit" name="action" value="memory" class="button">[MEM] Generate Memory Load</button>
            <button type="submit" name="action" value="io" class="button">[I/O] Generate I/O Load</button>
            <button type="submit" name="action" value="exception" class="button">[ERR] Generate Exception</button>
            <button type="submit" name="action" value="sleep" class="button">[SLEEP] Sleep Test</button>
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
                    case "sleep":
                        GenerateSleep();
                        break;
                }
            }
            
            private void GenerateCpuLoad()
            {
                Response.Write("<div class='result'><strong>[CPU] CPU Load Test</strong><br/>Running intensive calculation...</div>");
                var stopwatch = Stopwatch.StartNew();
                double result = 0;
                while (stopwatch.ElapsedMilliseconds < 1000) // 1 second of CPU work
                {
                    result += Math.Sqrt(DateTime.Now.Ticks);
                }
                Response.Write(string.Format("<div class='result'>Calculation completed in {0}ms. Result: {1:F2}</div>", stopwatch.ElapsedMilliseconds, result));
            }
            
            private void GenerateMemoryLoad()
            {
                Response.Write("<div class='result'><strong>[MEM] Memory Test</strong><br/>Allocating memory...</div>");
                var data = new List<byte[]>();
                for (int i = 0; i < 50; i++)
                {
                    data.Add(new byte[1024 * 1024]); // 1MB chunks
                }
                long memoryUsed = GC.GetTotalMemory(false);
                Response.Write(string.Format("<div class='result'>Allocated ~50MB. Current memory usage: {0:F2}MB</div>", memoryUsed / 1024.0 / 1024.0));
                Thread.Sleep(500);
                data.Clear();
                GC.Collect();
            }
            
            private void GenerateIoLoad()
            {
                Response.Write("<div class='result'><strong>[I/O] I/O Test</strong><br/>File operations...</div>");
                string tempFile = Path.GetTempFileName();
                try
                {
                    byte[] data = new byte[512 * 1024]; // 512KB
                    new Random().NextBytes(data);
                    File.WriteAllBytes(tempFile, data);
                    byte[] readData = File.ReadAllBytes(tempFile);
                    Response.Write(string.Format("<div class='result'>Wrote and read {0}KB to temporary file</div>", data.Length / 1024));
                }
                finally
                {
                    if (File.Exists(tempFile))
                        File.Delete(tempFile);
                }
            }
            
            private void GenerateException()
            {
                Response.Write("<div class='result'><strong>[ERR] Exception Test</strong><br/>Generating handled exception...</div>");
                try
                {
                    throw new InvalidOperationException("Test exception for metrics");
                }
                catch (Exception ex)
                {
                    Response.Write(string.Format("<div class='result'>Caught exception: {0}</div>", Server.HtmlEncode(ex.Message)));
                    System.Diagnostics.Trace.WriteLine("Generated exception: " + ex.Message);
                }
            }
            
            private void GenerateSleep()
            {
                Response.Write("<div class='result'><strong>[SLEEP] Sleep Test</strong><br/>Simulating slow response...</div>");
                Thread.Sleep(1000); // 1 second delay
                Response.Write("<div class='result'>Completed 1-second delay</div>");
            }
        </script>
        
        <div class="timestamp">
            Request processed at <%= DateTime.Now.ToString("HH:mm:ss.fff") %>
        </div>
    </div>
</body>
</html>
'@
    
    $defaultAspxPath = Join-Path $script:SitePath "Default.aspx"
    [System.IO.File]::WriteAllText($defaultAspxPath, $defaultAspx, [System.Text.Encoding]::UTF8)
    Write-Success "Created Default.aspx"
    
    # Create web.config - using the proven approach from Setup-TestIIS
    $webConfig = @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.web>
    <compilation targetFramework="4.8" />
    <httpRuntime targetFramework="4.8" />
    <customErrors mode="Off" />
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
'@
    
    $webConfigPath = Join-Path $script:SitePath "web.config"
    [System.IO.File]::WriteAllText($webConfigPath, $webConfig, [System.Text.Encoding]::UTF8)
    Write-Success "Created web.config"
    
    $defaultAspxPath = Join-Path $script:SitePath "default.aspx"
    [System.IO.File]::WriteAllText($defaultAspxPath, $defaultAspx, [System.Text.Encoding]::UTF8)
    Write-Success "Created default.aspx"
}

function New-TestSite {
    Write-Step "Creating IIS application pool and website..."
    
    # Remove existing site/pool if they exist
    try {
        if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
            Remove-Website -Name $SiteName
            Write-Info "Removed existing website"
        }
        
        if (Get-WebAppPoolState -Name $script:AppPoolName -ErrorAction SilentlyContinue) {
            Remove-WebAppPool -Name $script:AppPoolName
            Write-Info "Removed existing application pool"
        }
    }
    catch {
        Write-Info "No existing resources to remove"
    }
    
    # Create application pool
    try {
        New-WebAppPool -Name $script:AppPoolName
        Write-Success "Created application pool: $script:AppPoolName"
    }
    catch {
        throw "Failed to create application pool: $($_.Exception.Message)"
    }
    
    # Configure application pool - handle PowerShell version differences
    try {
        # Try the standard IIS: drive approach first
        Set-ItemProperty -Path "IIS:\AppPools\$script:AppPoolName" -Name "managedRuntimeVersion" -Value "v4.0" -ErrorAction Stop
        Set-ItemProperty -Path "IIS:\AppPools\$script:AppPoolName" -Name "enable32BitAppOnWin64" -Value $false -ErrorAction Stop
        Set-ItemProperty -Path "IIS:\AppPools\$script:AppPoolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity" -ErrorAction Stop
        Write-Info "Used IIS: drive provider for configuration"
    }
    catch {
        # Fallback: Use Set-WebConfigurationProperty for better compatibility
        Write-Info "IIS: drive not available, using WebConfiguration cmdlets..."
        
        try {
            Set-WebConfigurationProperty -Filter "/system.applicationHost/applicationPools/add[@name='$script:AppPoolName']" -Name "managedRuntimeVersion" -Value "v4.0"
            Set-WebConfigurationProperty -Filter "/system.applicationHost/applicationPools/add[@name='$script:AppPoolName']" -Name "enable32BitAppOnWin64" -Value $false
            Set-WebConfigurationProperty -Filter "/system.applicationHost/applicationPools/add[@name='$script:AppPoolName']/processModel" -Name "identityType" -Value "ApplicationPoolIdentity"
            Write-Info "Used WebConfiguration cmdlets for configuration"
        }
        catch {
            Write-Warning "Could not configure application pool advanced settings: $($_.Exception.Message)"
            Write-Info "Application pool created with default settings"
        }
    }
    
    # Create website
    try {
        New-Website -Name $SiteName -Port $Port -PhysicalPath $script:SitePath -ApplicationPool $script:AppPoolName
        Write-Success "Created website: $SiteName on port $Port"
    }
    catch {
        throw "Failed to create website: $($_.Exception.Message)"
    }
    
    # Start the application pool and website
    try {
        Start-WebAppPool -Name $script:AppPoolName
        Start-Website -Name $SiteName
        Write-Success "Started application pool and website"
    }
    catch {
        throw "Failed to start application pool or website: $($_.Exception.Message)"
    }
    
    # Wait for site to be ready
    Write-Step "Waiting for website to be ready..."
    $maxAttempts = 30
    $attempt = 0
    
    do {
        $attempt++
        try {
            $response = Invoke-CompatibleWebRequest -Uri $script:BaseUrl -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Success "Website is responding (HTTP $($response.StatusCode))"
                break
            }
        }
        catch {
            if ($attempt -eq $maxAttempts) {
                Write-Error "Website failed to start after $maxAttempts attempts"
                Write-Info "Last error: $($_.Exception.Message)"
                
                # Additional diagnostics
                Write-Step "Running diagnostics..."
                
                # Check if the site is actually running
                try {
                    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
                    if ($site) {
                        Write-Info "IIS Site Status: $($site.State)"
                    }
                    
                    $pool = Get-WebAppPoolState -Name $script:AppPoolName -ErrorAction SilentlyContinue
                    if ($pool) {
                        Write-Info "App Pool Status: $($pool.Value)"
                    }
                }
                catch {
                    Write-Warning "Could not get IIS status: $($_.Exception.Message)"
                }
                
                # Check Windows Event Log for ASP.NET errors
                try {
                    $recentErrors = Get-EventLog -LogName Application -Source "ASP.NET*" -After (Get-Date).AddMinutes(-5) -ErrorAction SilentlyContinue | Select-Object -First 3
                    if ($recentErrors) {
                        Write-Info "Recent ASP.NET errors found in Event Log:"
                        foreach ($error in $recentErrors) {
                            Write-Info "  - $($error.TimeGenerated): $($error.Message.Substring(0, [Math]::Min(100, $error.Message.Length)))..."
                        }
                    }
                }
                catch {
                    Write-Info "Could not check Event Log for ASP.NET errors"
                }
                
                # Try a simple HTTP request to see the actual error
                try {
                    Write-Info "Attempting to retrieve detailed error information..."
                    $errorResponse = Invoke-WebRequest -Uri $script:BaseUrl -UseBasicParsing -ErrorAction SilentlyContinue
                }
                catch {
                    if ($_.Exception.Response) {
                        $statusCode = $_.Exception.Response.StatusCode
                        Write-Info "HTTP Status: $statusCode"
                        
                        if ($_.Exception.Response.GetResponseStream) {
                            try {
                                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                                $errorContent = $reader.ReadToEnd()
                                $reader.Close()
                                
                                if ($errorContent -and $errorContent.Length -gt 0) {
                                    Write-Info "Error response preview:"
                                    $preview = $errorContent.Substring(0, [Math]::Min(500, $errorContent.Length))
                                    Write-Info $preview
                                }
                            }
                            catch {
                                Write-Info "Could not read error response content"
                            }
                        }
                    }
                }
                
                throw "Website failed to start after $maxAttempts attempts: $($_.Exception.Message)"
            }
            
            if ($attempt % 5 -eq 0) {
                Write-Info "Attempt $attempt/$maxAttempts - still waiting for website to respond..."
            }
            Start-Sleep -Seconds 2
        }
    } while ($attempt -lt $maxAttempts)
}

function Start-LoadGeneration {
    Write-Step "Starting load generation for $LoadDurationMinutes minutes..."
    
    $actions = @("", "cpu", "memory", "io", "exception", "sleep")
    $startTime = Get-Date
    $endTime = $startTime.AddMinutes($LoadDurationMinutes)
    $requestCount = 0
    $successCount = 0
    $errorCount = 0
    
    Write-Info "Target: $script:BaseUrl"
    Write-Info "Rate: $RequestsPerMinute requests/minute"
    Write-Info "Duration: $LoadDurationMinutes minutes"
    Write-Info "End time: $($endTime.ToString('HH:mm:ss'))"
    Write-Host ""
    
    while ((Get-Date) -lt $endTime) {
        try {
            # Use more compatible random selection for PowerShell 5.1
            $randomIndex = Get-Random -Minimum 0 -Maximum $actions.Length
            $action = $actions[$randomIndex]
            $requestCount++
            
            if ($action -eq "") {
                $response = Invoke-CompatibleWebRequest -Uri $script:BaseUrl -TimeoutSec 30
            } else {
                $body = "action=$action"
                $response = Invoke-CompatibleWebRequest -Uri $script:BaseUrl -Method POST -Body $body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 30
            }
            
            if ($response.StatusCode -eq 200) {
                $successCount++
            }
            
            # Progress reporting
            if ($requestCount % 20 -eq 0) {
                $elapsed = (Get-Date) - $startTime
                $remaining = $endTime - (Get-Date)
                $actualRate = [math]::Round($requestCount / $elapsed.TotalMinutes, 1)
                $successRate = [math]::Round(($successCount / $requestCount) * 100, 1)
                
                $progressMessage = "  [PROGRESS] Requests: " + $requestCount + " | Success: " + $successRate + "% | Rate: " + $actualRate + "/min | Remaining: " + $remaining.ToString('mm\:ss') + " | Action: " + $action
                Write-Host $progressMessage -ForegroundColor Cyan
            }
            
            # Wait to maintain desired rate
            $sleepMs = [math]::Max(100, (60000 / $RequestsPerMinute))
            Start-Sleep -Milliseconds $sleepMs
        }
        catch {
            $errorCount++
            if ($errorCount % 5 -eq 0) {
                $exceptionMessage = if ($_.Exception.Message) { $_.Exception.Message } else { "Unknown error" }
                $errorMessage = "Request failed (" + $errorCount + " errors total): " + $exceptionMessage
                Write-Warning $errorMessage
            }
            Start-Sleep -Seconds 2
        }
    }
    
    $totalElapsed = (Get-Date) - $startTime
    $actualRate = [math]::Round($requestCount / $totalElapsed.TotalMinutes, 1)
    $successRate = [math]::Round(($successCount / $requestCount) * 100, 1)
    
    Write-Host ""
    Write-Success "Load generation completed!"
    Write-Info "Total requests: $requestCount"
    $successMessage = "Successful: " + $successCount + " (" + $successRate + " percent)"
    Write-Info $successMessage
    Write-Info "Errors: $errorCount"
    Write-Info "Actual rate: $actualRate requests/minute"
    Write-Info "Duration: $($totalElapsed.ToString('mm\:ss'))"
}

function Get-MetricusStatus {
    Write-Step "Checking Metricus service status..."
    
    try {
        $service = Get-Service -Name "metricus" -ErrorAction SilentlyContinue
        if ($service) {
            Write-Success "Metricus service found - Status: $($service.Status)"
            
            if ($service.Status -eq "Running") {
                Write-Info "Metricus should be collecting metrics during the test"
            } else {
                Write-Warning "Metricus service is not running - metrics may not be collected"
            }
        } else {
            Write-Warning "Metricus service not found - install and start Metricus to collect metrics"
        }
    }
    catch {
        Write-Warning "Could not check Metricus service: $($_.Exception.Message)"
    }
}

function Remove-TestResources {
    Write-Step "Cleaning up test resources..."
    
    try {
        # Stop and remove website
        if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
            Stop-Website -Name $SiteName -ErrorAction SilentlyContinue
            Remove-Website -Name $SiteName
            Write-Success "Removed website: $SiteName"
        }
        
        # Stop and remove application pool
        if (Get-WebAppPoolState -Name $script:AppPoolName -ErrorAction SilentlyContinue) {
            Stop-WebAppPool -Name $script:AppPoolName -ErrorAction SilentlyContinue
            Remove-WebAppPool -Name $script:AppPoolName
            Write-Success "Removed application pool: $script:AppPoolName"
        }
        
        # Remove files
        if (Test-Path $script:SitePath) {
            Remove-Item -Path $script:SitePath -Recurse -Force
            Write-Success "Removed files: $script:SitePath"
        }
    }
    catch {
        Write-Warning "Cleanup error: $($_.Exception.Message)"
    }
}

function Show-TestSummary {
    $totalDuration = (Get-Date) - $script:TestStartTime
    
    Write-Header "Test Summary"
    Write-Host "Test Configuration:" -ForegroundColor Yellow
    Write-Host "  Site Name: $SiteName" -ForegroundColor Gray
    Write-Host "  Port: $Port" -ForegroundColor Gray
    Write-Host "  Load Duration: $LoadDurationMinutes minutes" -ForegroundColor Gray
    Write-Host "  Request Rate: $RequestsPerMinute requests/minute" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Results:" -ForegroundColor Yellow
    Write-Host "  Total Test Duration: $($totalDuration.ToString('mm\:ss'))" -ForegroundColor Gray
    Write-Host "  Base URL: $script:BaseUrl" -ForegroundColor Gray
    Write-Host "  Cleanup: $(if ($SkipCleanup) { 'Skipped' } else { 'Completed' })" -ForegroundColor Gray
    Write-Host ""
    
    if (-not $SkipCleanup) {
        Write-Host "✅ Test completed successfully and resources cleaned up!" -ForegroundColor Green
    } else {
        Write-Host "✅ Test completed successfully!" -ForegroundColor Green
        Write-Host "⚠️  Test resources left running for manual inspection." -ForegroundColor Yellow
        Write-Host "   Use the following to clean up manually:" -ForegroundColor Gray
        Write-Host "   .\Run-MetricusLoadTest.ps1 -SiteName '$SiteName' -Port $Port -LoadDurationMinutes 0" -ForegroundColor Gray
    }
}

# Main execution
try {
    Write-Header "Metricus Load Test"
    Write-Host "Starting comprehensive load test..." -ForegroundColor Green
    Write-Host "Duration: $LoadDurationMinutes minutes | Rate: $RequestsPerMinute req/min | Port: $Port" -ForegroundColor Gray
    
    if (-not $Force) {
        Write-Host ""
        Write-Host "This test will:" -ForegroundColor Yellow
        Write-Host "  1. Create test IIS site '$SiteName' on port $Port" -ForegroundColor Gray
        Write-Host "  2. Generate load for $LoadDurationMinutes minutes" -ForegroundColor Gray
        Write-Host "  3. $(if ($SkipCleanup) { 'Leave resources running' } else { 'Clean up all resources' })" -ForegroundColor Gray
        Write-Host ""
        
        $confirm = Read-Host "Continue? (Y/n)"
        if ($confirm -match "^[Nn]") {
            Write-Host "Test cancelled." -ForegroundColor Gray
            exit 0
        }
    }
    
    # Execute test phases
    Test-Prerequisites
    Get-MetricusStatus
    New-TestApplication
    New-TestSite
    
    if ($LoadDurationMinutes -gt 0) {
        Start-LoadGeneration
    } else {
        Write-Info "Load duration is 0 - skipping load generation"
    }
    
    if (-not $SkipCleanup) {
        Remove-TestResources
    }
    
    Show-TestSummary
    exit 0
}
catch {
    Write-Host ""
    Write-Error "Test failed: $($_.Exception.Message)"
    
    # Attempt cleanup on failure unless explicitly skipped
    if (-not $SkipCleanup) {
        Write-Host ""
        Write-Step "Attempting cleanup after failure..."
        try {
            Remove-TestResources
            Write-Success "Emergency cleanup completed"
        }
        catch {
            Write-Warning "Emergency cleanup failed: $($_.Exception.Message)"
        }
    }
    
    exit 1
}
