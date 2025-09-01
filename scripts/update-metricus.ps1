# Metricus Complete Update Script - All Steps Combined
param(
    [Parameter(Mandatory=$true)]
    [string]$ZipPath,
    [string]$InstallPath = "C:\Metricus"
)

$ErrorActionPreference = "Stop"

# Import AWS PowerShell module if needed for S3 operations
if ($ZipPath -match '^s3://.*') {
    try {
        Import-Module AWSPowerShell -ErrorAction Stop
        Write-Host "AWS PowerShell module loaded successfully"
    } catch {
        throw "AWS PowerShell module not available. Please install: Install-Module AWSPowerShell"
    }
}

function Write-Log($Message, $Level = "INFO") {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Test-AdminRights {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

function Get-ZipFile($ZipPath) {
    if ($ZipPath -match '^https?://.*\.s3.*\.amazonaws\.com/.*' -or $ZipPath -match '^s3://.*') {
        # S3 URL detected - download to temp location
        $originalFileName = Split-Path $ZipPath -Leaf
        $tempZipPath = Join-Path $env:TEMP $originalFileName
        Write-Log "S3 URL detected, downloading to: $tempZipPath"
        
        try {
            if ($ZipPath -match '^s3://(.+?)/(.+)') {
                # s3://bucket/key format
                $bucket = $matches[1]
                $key = $matches[2]
                Write-Log "Using AWS PowerShell to download from S3: s3://$bucket/$key"
                
                Copy-S3Object -BucketName $bucket -Key $key -LocalFile $tempZipPath
                Write-Log "S3 download completed successfully"
                
            } else {
                # HTTPS S3 URL format
                Write-Log "Downloading from HTTPS S3 URL"
                Invoke-WebRequest -Uri $ZipPath -OutFile $tempZipPath -UseBasicParsing
            }
            
            Write-Log "Download completed successfully"
            return $tempZipPath
            
        } catch {
            throw "Failed to download from S3: $($_.Exception.Message)"
        }
    } else {
        # Local file path
        if (-not (Test-Path $ZipPath)) {
            throw "Local zip file not found: $ZipPath"
        }
        Write-Log "Using local zip file: $ZipPath"
        return $ZipPath
    }
}

function Invoke-Rollback($backupZipPath) {
    Write-Log "INITIATING ROLLBACK..." "ERROR"
    
    try {
        # Stop current service if running
        $service = Get-Service -Name "Metricus" -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Stop-Service $service.Name -Force
            Write-Log "Service stopped for rollback"
        }
        
        # Uninstall current service
        if ($service) {
            $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='Metricus'"
            if ($wmiService) {
                $currentServicePath = $wmiService.PathName
                if ($currentServicePath -match '^"([^"]+)"') {
                    $currentExePath = $matches[1]
                } else {
                    $currentExePath = $currentServicePath.Split(' ')[0]
                }
                
                if (Test-Path $currentExePath) {
                    & $currentExePath uninstall
                    Write-Log "Current service uninstalled for rollback"
                }
            }
        }
        
        # Extract backup name and determine target folder
        $backupName = (Get-Item $backupZipPath).BaseName
        if ($backupName -match 'backup-(metricus-\d+\.\d+\.\d+)-\d+-\d+') {
            $targetFolderName = $matches[1]
        } else {
            throw "Cannot determine target folder name from backup: $backupName"
        }
        
        $finalRestorePath = "$InstallPath\$targetFolderName"
        
        if (Test-Path $finalRestorePath) {
            Remove-Item $finalRestorePath -Recurse -Force
        }
        
        Expand-Archive -Path $backupZipPath -DestinationPath $finalRestorePath -Force
        Write-Log "Backup restored to: $finalRestorePath"
        
        # Reinstall old service
        $restoredExePath = "$finalRestorePath\metricus.exe"
        & $restoredExePath install
        & $restoredExePath start
        
        Write-Log "ROLLBACK COMPLETED SUCCESSFULLY" "ERROR"
        return $true
        
    } catch {
        Write-Log "ROLLBACK FAILED: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

try {
    Write-Log "=== METRICUS UPDATE PROCESS STARTED ==="
    Write-Log "Zip source: $ZipPath"
    Write-Log "Install path: $InstallPath"
    
    # Download/locate zip file
    Write-Log "Attempting to get zip file..."
    $actualZipPath = Get-ZipFile $ZipPath
    $isDownloadedFile = ($actualZipPath -ne $ZipPath)
    Write-Log "Zip file located at: $actualZipPath"
    
    # STEP 1-4: Pre-flight Validation
    Write-Log "=== PRE-FLIGHT VALIDATION ==="
    
    # Check admin privileges
    if (-not (Test-AdminRights)) {
        throw "Administrator privileges required for service operations"
    }
    Write-Log "Administrator privileges: Confirmed"
    
    # Validate zip file
    $zipInfo = Get-Item $actualZipPath
    Write-Log "Zip file validated: $($zipInfo.Name) ($([math]::Round($zipInfo.Length / 1MB, 2)) MB)"
    
    # Basic zip integrity check
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($actualZipPath)
    $entryCount = $zip.Entries.Count
    $zip.Dispose()
    Write-Log "Zip integrity verified: $entryCount entries"
    
    # Find current service and version
    $service = Get-Service -Name "Metricus" -ErrorAction SilentlyContinue
    if (-not $service) {
        throw "No Metricus service found"
    }
    
    $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='Metricus'"
    $servicePath = $wmiService.PathName
    
    if ($servicePath -match '^"([^"]+)"') {
        $currentExePath = $matches[1]
    } else {
        $currentExePath = $servicePath.Split(' ')[0]
    }
    
    $currentVersionPath = Split-Path $currentExePath -Parent
    $currentVersionName = Split-Path $currentVersionPath -Leaf
    
    Write-Log "Current service: $($service.Name) (Status: $($service.Status))"
    Write-Log "Current version: $currentVersionName"
    Write-Log "Current path: $currentVersionPath"
    
    # Verify install path is writable
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force
    }
    
    $testFile = Join-Path $InstallPath "write-test-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
    "test" | Out-File -FilePath $testFile -Force
    Remove-Item $testFile -Force
    Write-Log "Install path write permissions: Confirmed"
    
    # STEP 5-7: Service Shutdown and Verification
    Write-Log "=== SERVICE SHUTDOWN ==="
    
    # Stop service
    if ($service.Status -eq 'Running') {
        Stop-Service $service.Name -Force
        
        $timeout = 30
        $elapsed = 0
        do {
            Start-Sleep -Seconds 1
            $service.Refresh()
            $elapsed++
            if ($elapsed -gt $timeout) {
                throw "Service stop timeout after $timeout seconds"
            }
        } while ($service.Status -ne 'Stopped')
        
        Write-Log "Service stopped successfully"
    }
    
    # Uninstall service
    & $currentExePath uninstall
    if ($LASTEXITCODE -ne 0) { throw "Failed to uninstall service" }
    Write-Log "Service uninstalled successfully"
    
    # Verify service removed
    Start-Sleep -Seconds 2
    $remainingService = Get-Service -Name "Metricus" -ErrorAction SilentlyContinue
    if ($remainingService) {
        throw "Service still exists after uninstall"
    }
    Write-Log "Service removal verified"
    
    # STEP 8-9: Backup Creation
    Write-Log "=== BACKUP CREATION ==="
    
    # Create full backup
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupName = "backup-$currentVersionName-$timestamp"
    $backupPath = Join-Path $InstallPath $backupName
    
    Copy-Item -Path $currentVersionPath -Destination $backupPath -Recurse -Force
    Write-Log "Full backup created: $backupName"
    
    # Create backup zip and remove directory
    $backupZipPath = "$backupPath.zip"
    [System.IO.Compression.ZipFile]::CreateFromDirectory($backupPath, $backupZipPath)
    Remove-Item -Path $backupPath -Recurse -Force
    
    $zipSize = [math]::Round((Get-Item $backupZipPath).Length / 1MB, 2)
    Write-Log "Backup compressed: $backupName.zip ($zipSize MB)"
    
    # Create separate config backup
    $configBackupName = "config-backup-$currentVersionName-$timestamp"
    $configBackupPath = Join-Path $InstallPath $configBackupName
    New-Item -ItemType Directory -Path $configBackupPath -Force
    
    $configFiles = Get-ChildItem -Path $currentVersionPath -Name "config.json" -Recurse
    foreach ($configFile in $configFiles) {
        $sourceFile = Join-Path $currentVersionPath $configFile
        $destFile = Join-Path $configBackupPath $configFile
        $destDir = Split-Path $destFile -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force
        }
        Copy-Item -Path $sourceFile -Destination $destFile -Force
    }
    
    # Zip config backup and remove directory
    $configBackupZipPath = "$configBackupPath.zip"
    [System.IO.Compression.ZipFile]::CreateFromDirectory($configBackupPath, $configBackupZipPath)
    Remove-Item -Path $configBackupPath -Recurse -Force
    
    Write-Log "Config backup created: $configBackupName.zip ($($configFiles.Count) files)"
    
    # STEP 10-11: Zip Validation and Extraction
    Write-Log "=== NEW VERSION EXTRACTION ==="
    
    # Validate zip structure in temp location
    $tempExtractPath = "$env:TEMP\metricus-extract-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $tempExtractPath -Force
    
    Expand-Archive -Path $actualZipPath -DestinationPath $tempExtractPath -Force
    
    $metricusFolder = Get-ChildItem -Path $tempExtractPath -Directory | Where-Object {$_.Name -like 'metricus-*'} | Select-Object -First 1
    if (-not $metricusFolder) {
        throw "No metricus version folder found in zip"
    }
    
    $metricusExe = Join-Path $metricusFolder.FullName "metricus.exe"
    if (-not (Test-Path $metricusExe)) {
        throw "metricus.exe not found in extracted folder"
    }
    
    $pluginsDir = Join-Path $metricusFolder.FullName "Plugins"
    if (-not (Test-Path $pluginsDir)) {
        throw "Plugins directory not found in extracted folder"
    }
    
    Write-Log "Zip validation successful: $($metricusFolder.Name)"
    Remove-Item $tempExtractPath -Recurse -Force
    
    # Extract to final location
    Expand-Archive -Path $actualZipPath -DestinationPath $InstallPath -Force
    
    $newVersionFolder = Get-ChildItem -Path $InstallPath -Directory | Where-Object {$_.Name -like 'metricus-*'} | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Log "New version extracted: $($newVersionFolder.Name)"
    
    # STEP 12-15: Configuration Migration and Validation
    Write-Log "=== CONFIGURATION MIGRATION ==="
    
    # Validate new executable
    $newExePath = Join-Path $newVersionFolder.FullName "metricus.exe"
    if (-not (Test-Path $newExePath)) {
        throw "metricus.exe not found in new version"
    }
    
    # Test executable functionality
    try {
        $process = Start-Process -FilePath $newExePath -ArgumentList "--help" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\metricus-help.txt" -RedirectStandardError "$env:TEMP\metricus-error.txt"
        Remove-Item "$env:TEMP\metricus-help.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\metricus-error.txt" -Force -ErrorAction SilentlyContinue
        Write-Log "New executable validated"
    } catch {
        Write-Log "Warning: Executable test failed: $($_.Exception.Message)" "WARN"
    }
    
    # Copy configs from old to new version
    $oldConfigFiles = Get-ChildItem -Path $currentVersionPath -Name "config.json" -Recurse
    $copiedCount = 0
    
    foreach ($configFile in $oldConfigFiles) {
        $sourceFile = Join-Path $currentVersionPath $configFile
        $destFile = Join-Path $newVersionFolder.FullName $configFile
        $destDir = Split-Path $destFile -Parent
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force
        }
        
        Copy-Item -Path $sourceFile -Destination $destFile -Force
        $copiedCount++
    }
    
    Write-Log "Config files copied: $copiedCount"
    
    # Verify directory structure and configs
    $oldDirs = Get-ChildItem -Path $currentVersionPath -Directory -Recurse
    foreach ($oldDir in $oldDirs) {
        $relativePath = $oldDir.FullName.Replace($currentVersionPath, "").TrimStart("\")
        $newDirPath = Join-Path $newVersionFolder.FullName $relativePath
        if (-not (Test-Path $newDirPath)) {
            New-Item -ItemType Directory -Path $newDirPath -Force
        }
    }
    
    # Validate configs copied successfully
    $newConfigFiles = Get-ChildItem -Path $newVersionFolder.FullName -Name "config.json" -Recurse
    if ($newConfigFiles.Count -ne $oldConfigFiles.Count) {
        throw "Config copy verification failed. Expected: $($oldConfigFiles.Count), Found: $($newConfigFiles.Count)"
    }
    
    # Spot check file contents
    $firstConfig = $oldConfigFiles[0]
    $sourceContent = Get-Content (Join-Path $currentVersionPath $firstConfig) -Raw
    $destContent = Get-Content (Join-Path $newVersionFolder.FullName $firstConfig) -Raw
    if ($sourceContent -ne $destContent) {
        throw "Config file content verification failed"
    }
    
    Write-Log "Configuration migration verified"
    
    # STEP 16-17: Service Installation and Startup
    Write-Log "=== SERVICE INSTALLATION ==="
    
    # Install new service
    & $newExePath install
    if ($LASTEXITCODE -ne 0) { throw "Failed to install new service" }
    Write-Log "New service installed"
    
    # Verify service registration
    Start-Sleep -Seconds 2
    $newService = Get-Service -Name "Metricus" -ErrorAction SilentlyContinue
    if (-not $newService) {
        throw "New service not found after installation"
    }
    
    # Start service
    & $newExePath start
    if ($LASTEXITCODE -ne 0) { throw "Failed to start new service" }
    
    # Wait for service to start
    $timeout = 30
    $elapsed = 0
    do {
        Start-Sleep -Seconds 1
        $newService.Refresh()
        $elapsed++
        if ($elapsed -gt $timeout) {
            throw "Service start timeout after $timeout seconds"
        }
    } while ($newService.Status -ne 'Running')
    
    Write-Log "New service started successfully"
    
    # STEP 18-19: Cleanup
    Write-Log "=== CLEANUP ==="
    
    # Remove temp files
    $tempDirs = Get-ChildItem -Path $env:TEMP -Directory | Where-Object {$_.Name -like 'metricus-extract-*'}
    foreach ($tempDir in $tempDirs) {
        Remove-Item $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    $tempFiles = @("$env:TEMP\metricus-help.txt", "$env:TEMP\metricus-error.txt")
    foreach ($tempFile in $tempFiles) {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
    
    Write-Log "Temporary files cleaned up"
    
    # Clean up downloaded zip file if it was downloaded
    if ($isDownloadedFile -and (Test-Path $actualZipPath)) {
        Remove-Item $actualZipPath -Force -ErrorAction SilentlyContinue
        Write-Log "Downloaded zip file cleaned up"
    }
    
    # FINAL SUCCESS
    Write-Log "=== UPDATE COMPLETED SUCCESSFULLY ==="
    Write-Log "Old version: $currentVersionName"
    Write-Log "New version: $($newVersionFolder.Name)"
    Write-Log "Service status: $($newService.Status)"
    Write-Log "Backup available: $backupName.zip"
    Write-Log "Config backup: $configBackupName.zip"
    
    exit 0
    
} catch {
    Write-Log "UPDATE FAILED: $($_.Exception.Message)" "ERROR"
    
    # Attempt rollback if backup exists
    if ($backupZipPath -and (Test-Path $backupZipPath)) {
        $rollbackSuccess = Invoke-Rollback $backupZipPath
        if ($rollbackSuccess) {
            Write-Log "System restored to previous state" "ERROR"
        } else {
            Write-Log "CRITICAL: Update failed and rollback failed - manual intervention required" "ERROR"
        }
    } else {
        Write-Log "No backup available for rollback - manual intervention required" "ERROR"
    }
    
    # Cleanup temp files
    if ($tempExtractPath -and (Test-Path $tempExtractPath)) {
        Remove-Item $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clean up downloaded zip file if it was downloaded
    if ($isDownloadedFile -and $actualZipPath -and (Test-Path $actualZipPath)) {
        Remove-Item $actualZipPath -Force -ErrorAction SilentlyContinue
    }
    
    exit 1
}
