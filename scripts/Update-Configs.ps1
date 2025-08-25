#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Copies configuration files to the compiled output directory for testing.

.DESCRIPTION
    This script copies the configuration files from the scripts folder to the 
    Debug/Release bin output directory, allowing quick testing of config changes
    without a full rebuild. Supports backup and restore functionality.

.PARAMETER Configuration
    Build configuration (Debug/Release). Default: Debug

.PARAMETER Environment
    Target environment (Production/Development/Test/MinTest). Default: Development

.PARAMETER Backup
    Create backup of existing configurations before applying changes

.PARAMETER Restore
    Restore configurations from backup

.EXAMPLE
    .\Update-Configs.ps1
    
.EXAMPLE
    .\Update-Configs.ps1 -Configuration Release -Environment Production

.EXAMPLE
    .\Update-Configs.ps1 -Environment MinTest -Backup

.EXAMPLE
    .\Update-Configs.ps1 -Restore
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Production", "Development", "Test", "MinTest", "Prod")]
    [string]$Environment = "Development",
    
    [Parameter(Mandatory=$false)]
    [switch]$Backup,
    
    [Parameter(Mandatory=$false)]
    [switch]$Restore
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

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "  x $Message" -ForegroundColor Red
}

function Create-Backup {
    param($OutputPath)
    
    Write-Step "Creating backup of current configurations..."
    
    $backupDir = Join-Path $OutputPath "config-backup"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupSubDir = Join-Path $backupDir $timestamp
    New-Item -ItemType Directory -Path $backupSubDir -Force | Out-Null
    
    # Backup main config
    $mainConfig = Join-Path $OutputPath "config.json"
    if (Test-Path $mainConfig) {
        Copy-Item $mainConfig (Join-Path $backupSubDir "config.json")
        Write-Success "Backed up main config"
    }
    
    # Backup plugin configs
    $pluginsDir = Join-Path $OutputPath "Plugins"
    if (Test-Path $pluginsDir) {
        $plugins = @("GraphiteOut", "SitesFilter", "PerfCounter", "ConsoleOut")
        
        foreach ($plugin in $plugins) {
            $pluginConfigPath = Join-Path $pluginsDir "$plugin\config.json"
            if (Test-Path $pluginConfigPath) {
                $backupPluginDir = Join-Path $backupSubDir "Plugins\$plugin"
                New-Item -ItemType Directory -Path $backupPluginDir -Force | Out-Null
                Copy-Item $pluginConfigPath (Join-Path $backupPluginDir "config.json")
                Write-Success "Backed up $plugin config"
            }
        }
    }
    
    # Create a "latest" symlink/copy for easy restore
    $latestBackup = Join-Path $backupDir "latest"
    if (Test-Path $latestBackup) {
        Remove-Item $latestBackup -Recurse -Force
    }
    Copy-Item $backupSubDir $latestBackup -Recurse
    
    Write-Success "Backup created: $backupSubDir"
    return $backupSubDir
}

function Restore-Backup {
    param($OutputPath)
    
    Write-Step "Restoring configurations from backup..."
    
    $latestBackup = Join-Path $OutputPath "config-backup\latest"
    if (-not (Test-Path $latestBackup)) {
        throw "No backup found at: $latestBackup"
    }
    
    # Restore main config
    $backupMainConfig = Join-Path $latestBackup "config.json"
    if (Test-Path $backupMainConfig) {
        Copy-Item $backupMainConfig (Join-Path $OutputPath "config.json")
        Write-Success "Restored main config"
    }
    
    # Restore plugin configs
    $backupPluginsDir = Join-Path $latestBackup "Plugins"
    if (Test-Path $backupPluginsDir) {
        $plugins = @("GraphiteOut", "SitesFilter", "PerfCounter", "ConsoleOut")
        
        foreach ($plugin in $plugins) {
            $backupPluginConfig = Join-Path $backupPluginsDir "$plugin\config.json"
            $targetPluginConfig = Join-Path $OutputPath "Plugins\$plugin\config.json"
            
            if ((Test-Path $backupPluginConfig) -and (Test-Path (Split-Path $targetPluginConfig -Parent))) {
                Copy-Item $backupPluginConfig $targetPluginConfig
                Write-Success "Restored $plugin config"
            }
        }
    }
    
    Write-Success "Configuration restored from backup"
}

function Load-ConfigurationFiles {
    Write-Step "Loading configuration files..."
    
    $ScriptDir = $PSScriptRoot
    $configFiles = @{
        MainConfig = "config-main.json"
        GraphiteOutConfig = "config-graphiteout.json"
        SitesFilterConfig = "config-sitesfilter.json"
        PerfCounterConfig = "config-perfcounter.json"
        ConsoleOutConfig = "config-consoleout.json"
        EnvironmentOverrides = "environment-overrides.json"
    }
    
    # For MinTest, use the minimal perf counter config if it exists
    if ($Environment -eq "MinTest") {
        $minimalPerfConfig = Join-Path $ScriptDir "config-perfcounter-minimal.json"
        if (Test-Path $minimalPerfConfig) {
            $configFiles.PerfCounterConfig = "config-perfcounter-minimal.json"
            Write-Info "Using minimal performance counter configuration"
        }
    }
    
    $configs = @{}
    
    foreach ($configType in $configFiles.Keys) {
        $configPath = Join-Path $ScriptDir $configFiles[$configType]
        
        if (-not (Test-Path $configPath)) {
            throw "Configuration file not found: $configPath"
        }
        
        try {
            $configContent = Get-Content $configPath -Raw -Encoding UTF8
            $configs[$configType] = $configContent | ConvertFrom-Json
            Write-Success "Loaded $($configFiles[$configType])"
        }
        catch {
            throw "Failed to parse configuration file $configPath`: $($_.Exception.Message)"
        }
    }
    
    return $configs
}

function Find-OutputDirectory {
    Write-Step "Finding output directory..."
    
    $ScriptRoot = Split-Path $PSScriptRoot -Parent  # Go up one level from scripts folder
    $outputPath = Join-Path $ScriptRoot "metricus\bin\$Configuration"
    
    if (-not (Test-Path $outputPath)) {
        throw "Output directory not found: $outputPath. Please build the solution first."
    }
    
    Write-Success "Found output directory: $outputPath"
    return $outputPath
}

function Apply-Configuration {
    param($OutputPath, $Configs)
    
    Write-Step "Applying $Environment configuration to output directory..."
    
    # Start with base configurations - use deep copy via JSON serialization
    $finalConfigs = @{}
    
    foreach ($configType in @('MainConfig', 'GraphiteOutConfig', 'SitesFilterConfig', 'PerfCounterConfig', 'ConsoleOutConfig')) {
        if ($Configs[$configType]) {
            $jsonString = $Configs[$configType] | ConvertTo-Json -Depth 10
            $finalConfigs[$configType] = $jsonString | ConvertFrom-Json
        }
        else {
            Write-Warning "Configuration $configType is null or missing"
            $finalConfigs[$configType] = @{}
        }
    }
    
    # Apply environment overrides - handle case insensitive matching
    $environmentKey = $null
    foreach ($key in $Configs.EnvironmentOverrides.PSObject.Properties.Name) {
        if ($key -ieq $Environment) {
            $environmentKey = $key
            break
        }
    }
    
    if ($environmentKey) {
        $overrides = $Configs.EnvironmentOverrides.$environmentKey
        Write-Info "Applying $environmentKey overrides"
        
        foreach ($configType in $overrides.PSObject.Properties.Name) {
            $override = $overrides.$configType
            
            if (-not $finalConfigs[$configType]) {
                $finalConfigs[$configType] = @{}
            }
            
            foreach ($property in $override.PSObject.Properties.Name) {
                $finalConfigs[$configType] | Add-Member -MemberType NoteProperty -Name $property -Value $override.$property -Force
            }
        }
        Write-Success "Environment overrides applied"
    }
    else {
        Write-Info "No overrides found for $Environment environment"
        Write-Info "Available environments: $($Configs.EnvironmentOverrides.PSObject.Properties.Name -join ', ')"
    }
    
    # Write main configuration
    $mainConfigPath = Join-Path $OutputPath "config.json"
    $finalConfigs.MainConfig | ConvertTo-Json -Depth 10 | Set-Content $mainConfigPath -Encoding UTF8
    Write-Success "Main configuration updated: $mainConfigPath"
    
    # Update plugin configurations
    $pluginConfigs = @{
        "GraphiteOut" = $finalConfigs.GraphiteOutConfig
        "SitesFilter" = $finalConfigs.SitesFilterConfig
        "PerfCounter" = $finalConfigs.PerfCounterConfig
        "ConsoleOut" = $finalConfigs.ConsoleOutConfig
    }
    
    foreach ($plugin in $pluginConfigs.Keys) {
        $pluginDir = Join-Path $OutputPath "Plugins\$plugin"
        
        if (Test-Path $pluginDir) {
            $configPath = Join-Path $pluginDir "config.json"
            $pluginConfigs[$plugin] | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
            Write-Success "Plugin $plugin configuration updated: $configPath"
        }
        else {
            Write-Warning "Plugin directory not found: $pluginDir"
        }
    }
}

function Show-Summary {
    param($OutputPath, $Environment)
    
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host " Configuration Update Complete" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    Write-Host "[Target] Directory: " -NoNewline -ForegroundColor Cyan
    Write-Host $OutputPath -ForegroundColor White
    
    Write-Host "[Environment] Applied: " -NoNewline -ForegroundColor Cyan
    Write-Host "$Environment ($Configuration)" -ForegroundColor White
    
    Write-Host "[Files] Updated:" -ForegroundColor Cyan
    Write-Host "  + config.json (main service)" -ForegroundColor Gray
    Write-Host "  + Plugins\GraphiteOut\config.json" -ForegroundColor Gray
    Write-Host "  + Plugins\SitesFilter\config.json" -ForegroundColor Gray
    Write-Host "  + Plugins\PerfCounter\config.json" -ForegroundColor Gray
    Write-Host "  + Plugins\ConsoleOut\config.json" -ForegroundColor Gray
    
    # Show environment-specific info
    if ($Environment -eq "MinTest") {
        Write-Host ""
        Write-Host "[MinTest Environment]" -ForegroundColor Yellow
        Write-Host "  + Minimal metrics configuration applied" -ForegroundColor Gray
        Write-Host "  + Expected pattern: minimal.test.*" -ForegroundColor Gray
        Write-Host "  + Only 3 performance counters enabled" -ForegroundColor Gray
    }
    elseif ($Environment -eq "Test") {
        Write-Host ""
        Write-Host "[Test Environment]" -ForegroundColor Yellow
        Write-Host "  + Full metrics configuration" -ForegroundColor Gray
        Write-Host "  + Expected pattern: advanced.development.*" -ForegroundColor Gray
        Write-Host "  + Graphite: 10.0.0.14:2003" -ForegroundColor Gray
    }
    elseif ($Environment -eq "Prod") {
        Write-Host ""
        Write-Host "[Production Environment]" -ForegroundColor Yellow
        Write-Host "  + Production configuration (matches 0.5.0)" -ForegroundColor Gray
        Write-Host "  + Expected pattern: advanced.production.*" -ForegroundColor Gray
        Write-Host "  + Graphite: 10.0.0.14:2003" -ForegroundColor Gray
        Write-Host "  + Debug disabled, ConsoleOut disabled" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Ready for testing! Run metricus.exe from the output directory." -ForegroundColor Green
    Write-Host ""
    
    # Show quick test commands
    Write-Host "[Quick Test Commands]" -ForegroundColor Yellow
    Write-Host "cd `"$OutputPath`"" -ForegroundColor Gray
    Write-Host ".\metricus.exe" -ForegroundColor Gray
    Write-Host ""
    
    # Show restore command
    Write-Host "[Restore Command]" -ForegroundColor Yellow
    Write-Host ".\Update-Configs.ps1 -Restore" -ForegroundColor Gray
    Write-Host ""
}

# Main execution
try {
    Write-Host "Metricus Configuration Update Script" -ForegroundColor Yellow
    
    if ($Restore) {
        Write-Host "Mode: Restore from backup" -ForegroundColor Gray
        $outputPath = Find-OutputDirectory
        Restore-Backup $outputPath
        Write-Host "Configuration restored successfully!" -ForegroundColor Green
        exit 0
    }
    
    Write-Host "Environment: $Environment | Configuration: $Configuration" -ForegroundColor Gray
    if ($Backup) {
        Write-Host "Backup: Enabled" -ForegroundColor Gray
    }
    Write-Host ""
    
    $outputPath = Find-OutputDirectory
    
    if ($Backup) {
        Create-Backup $outputPath | Out-Null
    }
    
    $configs = Load-ConfigurationFiles
    Apply-Configuration $outputPath $configs
    Show-Summary $outputPath $Environment
    
    Write-Host "Configuration update completed successfully!" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ""
    Write-Error-Custom "Failed: $($_.Exception.Message)"
    exit 1
}
