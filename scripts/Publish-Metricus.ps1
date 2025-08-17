#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Builds and publishes Metricus with production configuration from external files.

.DESCRIPTION
    This script builds the Metricus solution and creates a deployment package 
    with production-ready configuration loaded from JSON files in the scripts folder.

.PARAMETER OutputPath
    The path where the published application will be created. Default: ./publish

.PARAMETER Configuration
    Build configuration (Debug/Release). Default: Release

.PARAMETER Environment
    Target environment (Production/Development/Test). Default: Production

.EXAMPLE
    .\Publish-Metricus.ps1
    
.EXAMPLE
    .\Publish-Metricus.ps1 -OutputPath "C:\Deploy\Metricus" -Environment Development
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "./publish",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Production", "Development", "Test")]
    [string]$Environment = "Production"
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

function Test-Prerequisites {
    Write-Step "Checking prerequisites..."
    
    $ScriptRoot = Split-Path $PSScriptRoot -Parent  # Go up one level from scripts folder
    $SolutionPath = Join-Path $ScriptRoot "metricus.sln"
    
    if (-not (Test-Path $SolutionPath)) {
        throw "Solution file not found: $SolutionPath"
    }
    Write-Success "Solution file found"
    
    # Check for build tools
    $buildTool = $null
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        $buildTool = "dotnet"
        Write-Success "dotnet CLI found"
    }
    elseif (Get-Command msbuild -ErrorAction SilentlyContinue) {
        $buildTool = "msbuild"
        Write-Success "MSBuild found"
    }
    else {
        throw "No build tools found. Install .NET SDK or Visual Studio Build Tools."
    }
    
    return @{
        SolutionPath = $SolutionPath
        ScriptRoot = $ScriptRoot
        BuildTool = $buildTool
    }
}

function Build-Solution {
    param($BuildInfo)
    
    Write-Step "Building solution ($Configuration)..."
    
    try {
        if ($BuildInfo.BuildTool -eq "dotnet") {
            & dotnet restore $BuildInfo.SolutionPath --verbosity minimal
            & dotnet build $BuildInfo.SolutionPath --configuration $Configuration --no-restore --verbosity minimal
        }
        else {
            & msbuild $BuildInfo.SolutionPath /t:Restore /p:Configuration=$Configuration /verbosity:minimal
            & msbuild $BuildInfo.SolutionPath /p:Configuration=$Configuration /verbosity:minimal
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed with exit code $LASTEXITCODE"
        }
        
        Write-Success "Build completed successfully"
    }
    catch {
        throw "Build failed: $($_.Exception.Message)"
    }
}

function Copy-BuildOutput {
    param($BuildInfo)
    
    Write-Step "Copying build output..."
    
    $PublishPath = New-Item -ItemType Directory -Path $OutputPath -Force | Select-Object -ExpandProperty FullName
    
    # Copy main application
    $sourcePath = Join-Path $BuildInfo.ScriptRoot "metricus\bin\$Configuration"
    if (-not (Test-Path $sourcePath)) {
        throw "Build output not found: $sourcePath"
    }
    
    Copy-Item -Path "$sourcePath\*" -Destination $PublishPath -Recurse -Force
    Write-Success "Main application copied"
    
    # Create and copy plugins
    $pluginsPath = Join-Path $PublishPath "Plugins"
    New-Item -ItemType Directory -Path $pluginsPath -Force | Out-Null
    
    # Copy all plugin assemblies (including ConsoleOut for debug scenarios)
    $pluginProjects = @("GraphiteOut", "ConsoleOut", "PerfCounter", "SitesFilter")
    
    foreach ($plugin in $pluginProjects) {
        $pluginSourcePath = Join-Path $BuildInfo.ScriptRoot "plugins\$plugin\bin\$Configuration"
        $pluginTargetPath = Join-Path $pluginsPath $plugin
        
        if (Test-Path $pluginSourcePath) {
            New-Item -ItemType Directory -Path $pluginTargetPath -Force | Out-Null
            Copy-Item -Path "$pluginSourcePath\*" -Destination $pluginTargetPath -Recurse -Force
            Write-Success "Plugin $plugin copied"
        }
        else {
            Write-Warning "Plugin $plugin build output not found"
        }
    }
    
    return $PublishPath
}

function Apply-Configuration {
    param($PublishPath, $Configs)
    
    Write-Step "Applying $Environment configuration..."
    
    # Start with base configurations
    $finalConfigs = @{
        MainConfig = $Configs.MainConfig.PSObject.Copy()
        GraphiteOutConfig = $Configs.GraphiteOutConfig.PSObject.Copy()
        SitesFilterConfig = $Configs.SitesFilterConfig.PSObject.Copy()
        PerfCounterConfig = $Configs.PerfCounterConfig.PSObject.Copy()
        ConsoleOutConfig = $Configs.ConsoleOutConfig.PSObject.Copy()
    }
    
    # Apply environment overrides
    if ($Configs.EnvironmentOverrides.PSObject.Properties.Name -contains $Environment) {
        $overrides = $Configs.EnvironmentOverrides.$Environment
        Write-Info "Applying $Environment overrides"
        
        foreach ($configType in $overrides.PSObject.Properties.Name) {
            $override = $overrides.$configType
            
            foreach ($property in $override.PSObject.Properties.Name) {
                $finalConfigs[$configType] | Add-Member -MemberType NoteProperty -Name $property -Value $override.$property -Force
            }
        }
        Write-Success "Environment overrides applied"
    }
    else {
        Write-Info "No overrides found for $Environment environment"
    }
    
    # Write configuration files
    $finalConfigs.MainConfig | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $PublishPath "config.json") -Encoding UTF8
    Write-Success "Main configuration written"
    
    # Plugin configurations
    $pluginConfigs = @{
        "GraphiteOut" = $finalConfigs.GraphiteOutConfig
        "SitesFilter" = $finalConfigs.SitesFilterConfig
        "PerfCounter" = $finalConfigs.PerfCounterConfig
        "ConsoleOut" = $finalConfigs.ConsoleOutConfig
    }
    
    foreach ($plugin in $pluginConfigs.Keys) {
        $pluginDir = Join-Path $PublishPath "Plugins\$plugin"
        if (Test-Path $pluginDir) {
            $configPath = Join-Path $pluginDir "config.json"
            $pluginConfigs[$plugin] | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
            Write-Success "Plugin $plugin configuration written"
        }
    }
}

function Create-DeploymentScripts {
    param($PublishPath)
    
    Write-Step "Creating deployment scripts..."
    
    # Installation script
    $installScript = @'
@echo off
echo Installing Metricus Service...

REM Stop service if running
sc stop Metricus 2>nul

REM Install service
metricus.exe install
if %ERRORLEVEL% NEQ 0 (
    echo Failed to install service
    pause
    exit /b 1
)

REM Start service
sc start Metricus
if %ERRORLEVEL% NEQ 0 (
    echo Failed to start service
    pause
    exit /b 1
)

echo Metricus service installed and started successfully
pause
'@
    
    $installScript | Set-Content (Join-Path $PublishPath "install.bat") -Encoding ASCII
    Write-Success "Installation script created"
    
    # Uninstall script
    $uninstallScript = @'
@echo off
echo Uninstalling Metricus Service...

REM Stop service
sc stop Metricus

REM Uninstall service
metricus.exe uninstall

echo Metricus service uninstalled
pause
'@
    
    $uninstallScript | Set-Content (Join-Path $PublishPath "uninstall.bat") -Encoding ASCII
    Write-Success "Uninstallation script created"
    
    # README
    $buildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $readme = @"
# Metricus Deployment Package

**Build Date:** $buildDate
**Configuration:** $Configuration
**Environment:** $Environment

## Installation

1. Copy this folder to the target Windows machine
2. Run ``install.bat`` as Administrator
3. Verify service is running in Windows Services

## Configuration Files

- ``config.json`` - Main service configuration
- ``Plugins\GraphiteOut\config.json`` - Graphite output settings
- ``Plugins\SitesFilter\config.json`` - IIS/ASP.NET filtering rules
- ``Plugins\PerfCounter\config.json`` - Performance counter collection
- ``Plugins\ConsoleOut\config.json`` - Console output settings

## Service Management

- Install: ``metricus.exe install``
- Start: ``sc start Metricus``
- Stop: ``sc stop Metricus``
- Uninstall: ``metricus.exe uninstall``

## Environment Configurations

### Production
- Standard production plugins (PerfCounter, SitesFilter, GraphiteOut)
- Debug disabled
- 10-second collection interval

### Development  
- All plugins including ConsoleOut for immediate feedback
- Debug enabled in GraphiteOut and SitesFilter
- 10-second collection interval

### Test
- Minimal plugins (PerfCounter, ConsoleOut)
- Debug enabled for troubleshooting
- 5-second collection interval for faster feedback

## Requirements

- Windows Server with .NET Framework 4.8
- Administrator privileges for installation
- Performance counter access for metrics collection

## Configuration Sources

This deployment was built from configuration files in the scripts folder:
- config-main.json
- config-graphiteout.json
- config-sitesfilter.json
- config-perfcounter.json
- config-consoleout.json
- environment-overrides.json
"@
    
    $readme | Set-Content (Join-Path $PublishPath "README.md") -Encoding UTF8
    Write-Success "README created"
}

function Show-Summary {
    param($PublishPath)
    
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host " Deployment Package Ready" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    Write-Host "[Package] Location: " -NoNewline -ForegroundColor Cyan
    Write-Host $PublishPath -ForegroundColor White
    
    Write-Host "[Build] Environment: " -NoNewline -ForegroundColor Cyan
    Write-Host "$Environment ($Configuration)" -ForegroundColor White
    
    $totalFiles = (Get-ChildItem $PublishPath -Recurse -File).Count
    $totalSize = [math]::Round((Get-ChildItem $PublishPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    
    Write-Host "[Stats] Package: " -NoNewline -ForegroundColor Cyan
    Write-Host "$totalFiles files, $totalSize MB" -ForegroundColor White
    
    Write-Host "[Config] Source: " -NoNewline -ForegroundColor Cyan
    Write-Host "External JSON files in scripts folder" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Ready for Windows deployment!" -ForegroundColor Green
    Write-Host ""
}

# Main execution
try {
    Write-Host "Metricus Build and Publish Script" -ForegroundColor Yellow
    Write-Host "Environment: $Environment | Configuration: $Configuration" -ForegroundColor Gray
    Write-Host ""
    
    $configs = Load-ConfigurationFiles
    $buildInfo = Test-Prerequisites
    Build-Solution $buildInfo
    $publishPath = Copy-BuildOutput $buildInfo
    Apply-Configuration $publishPath $configs
    Create-DeploymentScripts $publishPath
    Show-Summary $publishPath
    
    Write-Host "Publish completed successfully!" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ""
    Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
