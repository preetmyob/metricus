# Metricus Update Verification Script
param(
    [string]$ExpectedVersion,
    [string]$InstallPath = "C:\Metricus"
)

function Write-Status($Message, $Status = "INFO") {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $statusColor = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    Write-Host "[$timestamp] " -NoNewline
    Write-Host "[$Status] " -ForegroundColor $statusColor -NoNewline
    Write-Host $Message
}

$script:PassCount = 0
$script:FailCount = 0
$script:WarnCount = 0

function Test-Condition($Description, $Condition, $FailureMessage = "") {
    if ($Condition) {
        Write-Status $Description "PASS"
        $script:PassCount++
        return $true
    } else {
        $msg = if ($FailureMessage) { "$Description - $FailureMessage" } else { $Description }
        Write-Status $msg "FAIL"
        $script:FailCount++
        return $false
    }
}

function Test-Warning($Description, $Condition, $WarningMessage = "") {
    if (-not $Condition) {
        $msg = if ($WarningMessage) { "$Description - $WarningMessage" } else { $Description }
        Write-Status $msg "WARN"
        $script:WarnCount++
    }
}

try {
    Write-Status "=== METRICUS UPDATE VERIFICATION ===" "INFO"
    Write-Status "Install Path: $InstallPath" "INFO"
    if ($ExpectedVersion) {
        Write-Status "Expected Version: $ExpectedVersion" "INFO"
    }
    Write-Status "" "INFO"
    
    # Test 1: Service Existence and Status
    Write-Status "--- SERVICE VERIFICATION ---" "INFO"
    
    $services = @(Get-CimInstance win32_service -Filter "Name='Metricus'")
    Test-Condition "Service exists in system" ($services.Count -eq 1) "Found $($services.Count) services"
    
    if ($services.Count -eq 1) {
        $service = $services[0]
        Test-Condition "Service is running" ($service.State -eq "Running") "State: $($service.State)"
        Test-Condition "Service start mode is automatic" ($service.StartMode -eq "Auto") "Start mode: $($service.StartMode)"
        
        # Extract executable path using different method
        $servicePath = $service.PathName
        if ($servicePath -match '"([^"]+)"') {
            $exePath = $matches[1]
        } else {
            $exePath = ($servicePath -split '\s+')[0]
        }
        
        Test-Condition "Service executable path is valid" (Test-Path $exePath) "Path: $exePath"
        Write-Status "Service executable: $exePath" "INFO"
        
        # Update InstallPath based on actual service location if different
        $actualInstallPath = Split-Path (Split-Path $exePath -Parent) -Parent
        if ($actualInstallPath -ne $InstallPath) {
            Write-Status "Adjusting install path to actual location: $actualInstallPath" "WARN"
            $InstallPath = $actualInstallPath
        }
    }
    
    # Test 2: File System Structure Verification
    Write-Status "--- FILE SYSTEM VERIFICATION ---" "INFO"
    
    Test-Condition "Install directory exists" (Test-Path $InstallPath)
    
    if (Test-Path $InstallPath) {
        $versionDirs = Get-ChildItem -Path $InstallPath -Directory | Where-Object {$_.Name -match "^metricus-\d+\.\d+\.\d+$"}
        Test-Condition "Version directories found" ($versionDirs.Count -gt 0) "Found $($versionDirs.Count) directories"
        
        if ($versionDirs) {
            $latestDir = $versionDirs | Sort-Object Name -Descending | Select-Object -First 1
            Write-Status "Latest version directory: $($latestDir.Name)" "INFO"
            
            if ($ExpectedVersion) {
                Test-Condition "Expected version matches latest" ($latestDir.Name -eq "metricus-$ExpectedVersion")
            }
            
            # Verify core files
            $coreFiles = @("metricus.exe")
            foreach ($file in $coreFiles) {
                $filePath = Join-Path $latestDir.FullName $file
                Test-Condition "$file exists" (Test-Path $filePath)
                
                if (Test-Path $filePath) {
                    $fileInfo = Get-Item $filePath
                    Test-Condition "$file is not empty" ($fileInfo.Length -gt 0) "Size: $($fileInfo.Length) bytes"
                }
            }
            
            # Check PluginInterface.dll separately (no recent modification check)
            $pluginInterfacePath = Join-Path $latestDir.FullName "PluginInterface.dll"
            Test-Condition "PluginInterface.dll exists" (Test-Path $pluginInterfacePath)
            if (Test-Path $pluginInterfacePath) {
                $fileInfo = Get-Item $pluginInterfacePath
                Test-Condition "PluginInterface.dll is not empty" ($fileInfo.Length -gt 0) "Size: $($fileInfo.Length) bytes"
            }
            
            # Verify plugins structure
            $pluginsPath = Join-Path $latestDir.FullName "Plugins"
            Test-Condition "Plugins directory exists" (Test-Path $pluginsPath)
            
            if (Test-Path $pluginsPath) {
                $pluginDirs = Get-ChildItem -Path $pluginsPath -Directory
                Test-Condition "Plugin directories found" ($pluginDirs.Count -gt 0) "Found $($pluginDirs.Count) plugins"
                
                foreach ($plugin in $pluginDirs) {
                    $pluginDll = Get-ChildItem -Path $plugin.FullName -Filter "*.dll" | Select-Object -First 1
                    Test-Condition "Plugin $($plugin.Name) has DLL" ($pluginDll -ne $null)
                    
                    $configPath = Join-Path $plugin.FullName "config.json"
                    if (Test-Path $configPath) {
                        Write-Status "Plugin $($plugin.Name) has config" "INFO"
                    } else {
                        Write-Status "Plugin $($plugin.Name) has no config (optional)" "INFO"
                    }
                }
            }
        }
    }
    
    # Test 3: Configuration Integrity
    Write-Status "--- CONFIGURATION VERIFICATION ---" "INFO"
    
    if ($versionDirs) {
        $configFiles = Get-ChildItem -Path $latestDir.FullName -Filter "config.json" -Recurse
        Test-Condition "Configuration files found" ($configFiles.Count -gt 0) "Found $($configFiles.Count) configs"
        
        foreach ($config in $configFiles) {
            try {
                $jsonContent = Get-Content $config.FullName -Raw | ConvertFrom-Json
                Test-Condition "Config $($config.Name) is valid JSON" ($jsonContent -ne $null)
            } catch {
                Test-Condition "Config $($config.Name) is valid JSON" $false "Parse error: $($_.Exception.Message)"
            }
        }
    }
    
    # Test 4: Process and Performance Verification
    Write-Status "--- PROCESS VERIFICATION ---" "INFO"
    
    $metricusProcesses = Get-Process | Where-Object {$_.ProcessName -match "metricus"}
    Test-Condition "Metricus process is running" ($metricusProcesses.Count -gt 0) "Found $($metricusProcesses.Count) processes"
    
    if ($metricusProcesses) {
        $process = $metricusProcesses[0]
        Test-Condition "Process has reasonable memory usage" ($process.WorkingSet64 -lt 100MB) "Memory: $([math]::Round($process.WorkingSet64/1MB, 2)) MB"
        Test-Condition "Process started recently" ($process.StartTime -gt (Get-Date).AddHours(-1)) "Started: $($process.StartTime)"
        
        # Verify process path matches service path
        if ($exePath) {
            Test-Condition "Process path matches service" ($process.Path -eq $exePath) "Process: $($process.Path)"
        }
    }
    
    # Test 6: Network/Port Verification (if applicable)
    Write-Status "--- NETWORK VERIFICATION ---" "INFO"
    
    $netstatOutput = netstat -an | Select-String ":2003|:8080"
    Test-Warning "Network ports in use" ($netstatOutput.Count -gt 0) "No typical Metricus ports (2003, 8080) detected"
    
    # Test 7: Backup Verification
    Write-Status "--- BACKUP VERIFICATION ---" "INFO"
    
    $backupFiles = Get-ChildItem -Path $InstallPath -Filter "backup-*.zip" -ErrorAction SilentlyContinue
    Test-Condition "Backup files exist" ($backupFiles.Count -gt 0) "Found $($backupFiles.Count) backups"
    
    if ($backupFiles) {
        $latestBackup = $backupFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Test-Condition "Recent backup available" ($latestBackup.LastWriteTime -gt (Get-Date).AddHours(-2)) "Latest: $($latestBackup.LastWriteTime)"
    }
    
    $configBackups = Get-ChildItem -Path $InstallPath -Filter "config-backup-*.zip" -ErrorAction SilentlyContinue
    Test-Condition "Config backups exist" ($configBackups.Count -gt 0) "Found $($configBackups.Count) config backups"
    
    # Test 8: Version Comparison
    Write-Status "--- VERSION VERIFICATION ---" "INFO"
    
    if ($versionDirs.Count -gt 1) {
        $sortedVersions = $versionDirs | Sort-Object Name -Descending
        $currentVersion = $sortedVersions[0].Name
        $previousVersion = $sortedVersions[1].Name
        
        Write-Status "Current version: $currentVersion" "INFO"
        Write-Status "Previous version: $previousVersion" "INFO"
        
        Test-Condition "Version upgrade detected" ($currentVersion -ne $previousVersion)
        
        # Check if old version still exists (should be preserved)
        Test-Condition "Previous version preserved" (Test-Path $sortedVersions[1].FullName)
    }
    
    # Final Summary
    Write-Status "" "INFO"
    Write-Status "=== VERIFICATION SUMMARY ===" "INFO"
    Write-Status "PASSED: $script:PassCount" "PASS"
    if ($script:WarnCount -gt 0) {
        Write-Status "WARNINGS: $script:WarnCount" "WARN"
    }
    if ($script:FailCount -gt 0) {
        Write-Status "FAILED: $script:FailCount" "FAIL"
    }
    
    if ($script:FailCount -eq 0) {
        Write-Status "UPDATE VERIFICATION: SUCCESS" "PASS"
        exit 0
    } else {
        Write-Status "UPDATE VERIFICATION: FAILED" "FAIL"
        exit 1
    }
    
} catch {
    Write-Status "VERIFICATION ERROR: $($_.Exception.Message)" "FAIL"
    exit 1
}
