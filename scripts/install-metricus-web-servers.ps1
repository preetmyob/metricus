[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "production",
    
    [Parameter(Mandatory=$false)]
    [string]$MetricusVersion = "1.2.0",
    
    [Parameter(Mandatory=$false)]
    [string]$MetricusLocalBasePath = "C:\Metricus",
    
    [Parameter(Mandatory=$false)]
    [string]$BucketName = "production-enterprise-site-management",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-southeast-2",
    
    [Parameter(Mandatory=$false)]
    [string]$TempFolder = $env:TEMP,
    
    [Parameter(Mandatory=$false)]
    [string]$RequestId = [guid]::NewGuid().ToString()
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Timestamp] [$Level] $Message"
}

# Get EC2 instance metadata to construct server name
function Get-ServerName {
    Write-Log "Retrieving EC2 instance metadata..."
    
    try {
        # Get instance ID from EC2 metadata service
        $InstanceId = (Invoke-RestMethod -Uri 'http://169.254.169.254/latest/meta-data/instance-id' -TimeoutSec 5).Trim()
        Write-Log "Instance ID: $InstanceId"
        
        # Get instance name tag from EC2
        $InstanceName = (Get-EC2Tag -Filter @{Name="resource-id";Values=$InstanceId} | Where-Object {$_.Key -eq "Name"}).Value
        
        if ([string]::IsNullOrEmpty($InstanceName)) {
            Write-Log "Name tag not found, falling back to hostname" -Level "WARN"
            $InstanceName = $env:COMPUTERNAME
        }
        
        $ServerName = "$InstanceName.$InstanceId"
        Write-Log "Constructed server name: $ServerName"
        
        return $ServerName
    } catch {
        Write-Log "Failed to retrieve EC2 metadata: $_" -Level "ERROR"
        throw "Unable to construct server name. Ensure AWS PowerShell module is installed and instance has appropriate IAM permissions."
    }
}

function Remove-MetricusService {
    Write-Log "Checking for existing Metricus service..."
    $Service = Get-Service -Name "metricus" -ErrorAction SilentlyContinue
    
    if ($null -ne $Service) {
        Write-Log "Metricus service found. Removing..."
        
        if ($Service.Status -eq 'Running') {
            Write-Log "Stopping Metricus service..."
            Stop-Service -Name 'metricus' -Force
            Start-Sleep -Seconds 2
        }
        
        Write-Log "Deleting Metricus service..."
        $deleteResult = sc.exe delete 'metricus' 2>&1
        
        if ($deleteResult -like "*marked for deletion*") {
            Write-Log "Service marked for deletion, attempting WMI force delete..." -Level "WARN"
            $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='metricus'" -ErrorAction SilentlyContinue
            if ($wmiService) {
                $wmiService.Delete() | Out-Null
                Write-Log "WMI delete attempted"
            }
        }
        
        # Wait for service to be deleted (can take time if handles are open)
        $retries = 0
        $maxRetries = 30
        while ((Get-Service -Name "metricus" -ErrorAction SilentlyContinue) -and $retries -lt $maxRetries) {
            if ($retries -eq 0) {
                Write-Log "Waiting for service deletion to complete..."
            }
            Start-Sleep -Seconds 2
            $retries++
        }
        
        if (Get-Service -Name "metricus" -ErrorAction SilentlyContinue) {
            Write-Log "Service still exists after $maxRetries retries. May require server restart." -Level "WARN"
            throw "Failed to delete Metricus service. It may be locked. Try restarting the server."
        } else {
            Write-Log "Metricus service removed successfully"
        }
    } else {
        Write-Log "No existing Metricus service found"
    }
}

function Remove-MetricusFiles {
    Write-Log "Removing existing Metricus files..."
    if (Test-Path $MetricusLocalBasePath) {
        Remove-Item -Path $MetricusLocalBasePath -Force -Recurse -ErrorAction SilentlyContinue
        Write-Log "Metricus files removed"
    }
}

function Install-MetricusFromS3 {
    Write-Log "Downloading Metricus $MetricusVersion from S3..."
    
    $ZipFile = "$TempFolder\metricus-$MetricusVersion.zip"
    
    try {
        Copy-S3Object -BucketName $BucketName -Key "metricus-$MetricusVersion.zip" -LocalFile $ZipFile -Region $Region
        Write-Log "Downloaded successfully"
    } catch {
        Write-Log "Failed to download from S3: $_" -Level "ERROR"
        throw
    }
    
    Write-Log "Extracting Metricus to $MetricusLocalBasePath..."
    Expand-Archive -LiteralPath $ZipFile -DestinationPath $MetricusLocalBasePath -Force
    
    # Unblock files to prevent "loaded from network location" security errors
    Write-Log "Unblocking extracted files..."
    Get-ChildItem -Path $MetricusLocalBasePath -Recurse | Unblock-File -ErrorAction SilentlyContinue
    
    # Cleanup temp file
    Remove-Item -Path $ZipFile -Force -ErrorAction SilentlyContinue
    
    Write-Log "Extraction complete"
}

function Set-MetricusConfiguration {
    $MetricusInstallRoot = "$MetricusLocalBasePath\metricus-$MetricusVersion"
    
    if (-not (Test-Path $MetricusInstallRoot)) {
        throw "Metricus installation directory not found: $MetricusInstallRoot"
    }
    
    Write-Log "Configuring Metricus main config..."
    $MainConfigPath = "$MetricusInstallRoot\config.json"
    $MetricusConfigJson = Get-Content $MainConfigPath | ConvertFrom-Json
    $MetricusConfigJson.Host = "unused_graphite_web_udp_hostname"
    $MetricusConfigJson.ActivePlugins = @('PerformanceCounter', 'SitesFilter', 'GraphiteOut')
    $MetricusConfigJson | ConvertTo-Json -Depth 10 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Out-File $MainConfigPath -Encoding UTF8
    
    Write-Log "Configuring GraphiteOut plugin..."
    $GraphiteConfigPath = "$MetricusInstallRoot\Plugins\GraphiteOut\config.json"
    $GraphiteConfigJson = Get-Content $GraphiteConfigPath | ConvertFrom-Json
    
    # Set Graphite hostname based on environment
    $testEnvironments = 'development', 'staging'
    if ($testEnvironments -contains $Environment) {
        $GraphiteConfigJson.Hostname = "graphitedevtest.edops.myob.com"
        Write-Log "Using test Graphite endpoint for $Environment environment"
    } else {
        $GraphiteConfigJson.Hostname = "graphite.edops.myob.com"
        Write-Log "Using production Graphite endpoint"
    }
    
    $GraphiteConfigJson.Port = "2010"
    $GraphiteConfigJson.Protocol = "tcp"
    $GraphiteConfigJson.Debug = $true
    $GraphiteConfigJson.SendBufferSize = "5000"
    $GraphiteConfigJson.Servername = $ServerName
    $GraphiteConfigJson.Prefix = "advanced.$Environment"
    
    $GraphiteConfigJson | ConvertTo-Json -Depth 10 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Out-File $GraphiteConfigPath -Encoding UTF8
    
    Write-Log "Configuration complete"
    Write-Log "Main config: $MainConfigPath"
    Write-Log "GraphiteOut config: $GraphiteConfigPath"
    
    return $MetricusInstallRoot
}

function Install-MetricusService {
    param([string]$InstallRoot)
    
    $MetricusExe = "$InstallRoot\metricus.exe"
    
    if (-not (Test-Path $MetricusExe)) {
        throw "Metricus executable not found: $MetricusExe"
    }
    
    Write-Log "Installing Metricus Windows service..."
    & $MetricusExe install
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Metricus service. Exit code: $LASTEXITCODE"
    }
    
    Write-Log "Starting Metricus service (initial start)..."
    try {
        Start-Service -Name 'metricus' -ErrorAction Stop
    } catch {
        Write-Log "Failed to start service: $_" -Level "ERROR"
        Write-Log "Checking service status and logs..." -Level "WARN"
        $Service = Get-Service -Name 'metricus' -ErrorAction SilentlyContinue
        if ($Service) {
            Write-Log "Service status: $($Service.Status)" -Level "WARN"
        }
        throw
    }
    
    # Verify service is running
    Start-Sleep -Seconds 2
    $Service = Get-Service -Name 'metricus'
    if ($Service.Status -ne 'Running') {
        Write-Log "Service failed to start. Status: $($Service.Status)" -Level "ERROR"
        Write-Log "Check Windows Event Viewer (Application log) for Metricus errors" -Level "ERROR"
        throw "Metricus service failed to start. Status: $($Service.Status)"
    }
    Write-Log "Metricus service started successfully" -Level "SUCCESS"
    
    Write-Log "Waiting 20 seconds for initial startup..."
    Start-Sleep -Seconds 20
    
    Write-Log "Stopping Metricus service..."
    Stop-Service -Name 'metricus' -Force
    Start-Sleep -Seconds 2
    
    Write-Log "Initializing HTTP Service Request Queues performance counters..."
    try {
        Get-Counter -ListSet "HTTP Service Request Queues" -ErrorAction Stop | Out-Null
        Write-Log "Performance counters initialized successfully"
    } catch {
        Write-Log "Warning: Failed to initialize HTTP Service Request Queues counters: $_" -Level "WARN"
    }
    
    Write-Log "Starting Metricus service..."
    Start-Service -Name 'metricus'
    
    Start-Sleep -Seconds 2
    $Service = Get-Service -Name 'metricus'
    if ($Service.Status -eq 'Running') {
        Write-Log "Metricus service is running successfully" -Level "SUCCESS"
    } else {
        throw "Metricus service failed to start. Status: $($Service.Status)"
    }
}

# Main execution
try {
    Write-Log "======================================"
    Write-Log "Metricus Installation Script"
    Write-Log "======================================"
    Write-Log "Version: $MetricusVersion"
    Write-Log "Environment: $Environment"
    Write-Log "Request ID: $RequestId"
    Write-Log "======================================"
    
    # Step 1: Get server name from EC2 metadata
    $ServerName = Get-ServerName
    Write-Log "Server: $ServerName"
    
    # Step 2: Remove existing service
    Remove-MetricusService
    
    # Step 3: Remove existing files
    Remove-MetricusFiles
    
    # Step 4: Download and extract from S3
    Install-MetricusFromS3
    
    # Step 5: Configure Metricus
    $InstallRoot = Set-MetricusConfiguration
    
    # Step 6: Install and start service
    Install-MetricusService -InstallRoot $InstallRoot
    
    Write-Log "======================================"
    Write-Log "Metricus installation completed successfully!" -Level "SUCCESS"
    Write-Log "======================================"
    
} catch {
    Write-Log "======================================"
    Write-Log "Installation failed: $_" -Level "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    Write-Log "======================================"
    exit 1
}