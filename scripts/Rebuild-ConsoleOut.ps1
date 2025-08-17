#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Rebuilds just the ConsoleOut plugin for quick testing.

.DESCRIPTION
    This script rebuilds only the ConsoleOut plugin and copies it to the output directory,
    allowing quick testing of changes without rebuilding the entire solution.

.PARAMETER Configuration
    Build configuration (Debug/Release). Default: Debug

.EXAMPLE
    .\Rebuild-ConsoleOut.ps1
    
.EXAMPLE
    .\Rebuild-ConsoleOut.ps1 -Configuration Release
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug"
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

try {
    Write-Host "ConsoleOut Plugin Rebuild Script" -ForegroundColor Yellow
    Write-Host "Configuration: $Configuration" -ForegroundColor Gray
    Write-Host ""
    
    $ScriptRoot = Split-Path $PSScriptRoot -Parent
    $ConsoleOutProject = Join-Path $ScriptRoot "plugins\ConsoleOut\ConsoleOut.csproj"
    
    if (-not (Test-Path $ConsoleOutProject)) {
        throw "ConsoleOut project not found: $ConsoleOutProject"
    }
    
    Write-Step "Rebuilding ConsoleOut plugin..."
    
    # Check for build tools
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        Write-Info "Using dotnet CLI"
        & dotnet build $ConsoleOutProject --configuration $Configuration --verbosity minimal
    }
    elseif (Get-Command msbuild -ErrorAction SilentlyContinue) {
        Write-Info "Using MSBuild"
        & msbuild $ConsoleOutProject /p:Configuration=$Configuration /verbosity:minimal
    }
    else {
        throw "No build tools found. Install .NET SDK or Visual Studio Build Tools."
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed with exit code $LASTEXITCODE"
    }
    
    Write-Success "ConsoleOut plugin rebuilt successfully"
    
    # Show output location
    $outputPath = Join-Path $ScriptRoot "metricus\bin\$Configuration\Plugins\ConsoleOut"
    Write-Info "Output location: $outputPath"
    
    if (Test-Path $outputPath) {
        $files = Get-ChildItem $outputPath -File
        Write-Info "Files in output:"
        foreach ($file in $files) {
            Write-Info "  - $($file.Name)"
        }
    }
    
    Write-Host ""
    Write-Host "ConsoleOut plugin rebuild completed!" -ForegroundColor Green
    Write-Host "You can now test the updated plugin." -ForegroundColor Gray
    
    exit 0
}
catch {
    Write-Host ""
    Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
