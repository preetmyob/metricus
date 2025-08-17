#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Removes the Metricus IIS test environment.

.DESCRIPTION
    This script removes:
    - Test website
    - Test application pool
    - Test application files
    - Load generation processes

.PARAMETER SiteName
    Name of the test website to remove. Default: MetricusTestSite

.PARAMETER AppPoolName
    Name of the application pool to remove. Default: MetricusTestPool

.PARAMETER SitePath
    Physical path of the website to remove. Default: C:\inetpub\wwwroot\MetricusTest

.PARAMETER Force
    Remove without confirmation prompts. Default: $false

.EXAMPLE
    .\Cleanup-TestIIS.ps1
    
.EXAMPLE
    .\Cleanup-TestIIS.ps1 -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SiteName = "MetricusTestSite",
    
    [Parameter(Mandatory=$false)]
    [string]$AppPoolName = "MetricusTestPool",
    
    [Parameter(Mandatory=$false)]
    [string]$SitePath = "C:\inetpub\wwwroot\MetricusTest",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

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

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Stop-LoadGeneration {
    Write-Step "Stopping load generation processes..."
    
    $loadProcesses = Get-Process | Where-Object { 
        $_.ProcessName -eq "powershell" -and 
        $_.CommandLine -like "*Generate-Load.ps1*" 
    }
    
    if ($loadProcesses) {
        foreach ($process in $loadProcesses) {
            try {
                $process.Kill()
                Write-Success "Stopped load generation process (PID: $($process.Id))"
            }
            catch {
                Write-Info "Could not stop process $($process.Id): $($_.Exception.Message)"
            }
        }
    } else {
        Write-Info "No load generation processes found"
    }
}

function Remove-TestWebsite {
    Write-Step "Removing website '$SiteName'..."
    
    try {
        Import-Module WebAdministration -SkipEditionCheck -ErrorAction Stop
        
        if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
            Remove-Website -Name $SiteName
            Write-Success "Website '$SiteName' removed"
        } else {
            Write-Info "Website '$SiteName' not found"
        }
    }
    catch {
        Write-Info "Could not remove website: $($_.Exception.Message)"
    }
}

function Remove-TestAppPool {
    Write-Step "Removing application pool '$AppPoolName'..."
    
    try {
        if (Get-WebAppPoolState -Name $AppPoolName -ErrorAction SilentlyContinue) {
            Remove-WebAppPool -Name $AppPoolName
            Write-Success "Application pool '$AppPoolName' removed"
        } else {
            Write-Info "Application pool '$AppPoolName' not found"
        }
    }
    catch {
        Write-Info "Could not remove application pool: $($_.Exception.Message)"
    }
}

function Remove-TestFiles {
    Write-Step "Removing test files from '$SitePath'..."
    
    if (Test-Path $SitePath) {
        try {
            Remove-Item -Path $SitePath -Recurse -Force
            Write-Success "Test files removed from '$SitePath'"
        }
        catch {
            Write-Info "Could not remove test files: $($_.Exception.Message)"
        }
    } else {
        Write-Info "Test path '$SitePath' not found"
    }
}

function Remove-LoadScript {
    Write-Step "Removing load generation script..."
    
    $loadScriptPath = Join-Path $PSScriptRoot "Generate-Load.ps1"
    
    if (Test-Path $loadScriptPath) {
        try {
            Remove-Item -Path $loadScriptPath -Force
            Write-Success "Load generation script removed"
        }
        catch {
            Write-Info "Could not remove load script: $($_.Exception.Message)"
        }
    } else {
        Write-Info "Load generation script not found"
    }
}

function Show-Summary {
    Write-Host ""
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host " Cleanup Complete" -ForegroundColor Yellow
    Write-Host "=" * 50 -ForegroundColor Cyan
    
    Write-Host "[Removed]" -ForegroundColor Cyan
    Write-Host "  + Website: $SiteName" -ForegroundColor Gray
    Write-Host "  + Application Pool: $AppPoolName" -ForegroundColor Gray
    Write-Host "  + Files: $SitePath" -ForegroundColor Gray
    Write-Host "  + Load generation processes" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Test environment has been cleaned up." -ForegroundColor Green
    Write-Host ""
}

# Main execution
try {
    Write-Host "Metricus IIS Test Environment Cleanup" -ForegroundColor Yellow
    Write-Host "Site: $SiteName | Pool: $AppPoolName" -ForegroundColor Gray
    Write-Host ""
    
    if (-not (Test-Administrator)) {
        throw "This script must be run as Administrator to modify IIS configuration."
    }
    
    if (-not $Force) {
        Write-Host "This will remove:" -ForegroundColor Yellow
        Write-Host "  - Website: $SiteName" -ForegroundColor Gray
        Write-Host "  - Application Pool: $AppPoolName" -ForegroundColor Gray
        Write-Host "  - Files: $SitePath" -ForegroundColor Gray
        Write-Host ""
        
        $confirm = Read-Host "Continue? (y/N)"
        if ($confirm -notmatch "^[Yy]") {
            Write-Host "Cleanup cancelled." -ForegroundColor Gray
            exit 0
        }
    }
    
    Stop-LoadGeneration
    Remove-TestWebsite
    Remove-TestAppPool
    Remove-TestFiles
    Remove-LoadScript
    
    Show-Summary
    
    Write-Host "Cleanup completed successfully!" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ""
    Write-Host "Cleanup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
