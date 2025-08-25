<#
.SYNOPSIS
    Checks for required build dependencies.

.DESCRIPTION
    Verifies that all required tools are available for building Metricus.
#>

function Test-Dependencies {
    Write-Host "=== Checking Build Dependencies ===" -ForegroundColor Green
    
    $AllGood = $true
    $MissingTools = @()
    
    # Check for .NET Framework (required for .NET Framework 4.8 projects)
    Write-Host "Checking .NET Framework..." -ForegroundColor Gray
    try {
        $NetFramework = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction SilentlyContinue
        if ($NetFramework.Release -ge 528040) {  # .NET Framework 4.8
            Write-Host "  ✓ .NET Framework 4.8+ found" -ForegroundColor Green
        } else {
            Write-Host "  ❌ .NET Framework 4.8+ required" -ForegroundColor Red
            $AllGood = $false
            $MissingTools += @{
                Name = ".NET Framework 4.8"
                Install = "Download from: https://dotnet.microsoft.com/download/dotnet-framework/net48"
                Required = $true
            }
        }
    }
    catch {
        Write-Host "  ⚠️  Could not detect .NET Framework version" -ForegroundColor Yellow
    }
    
    # Check for MSBuild (preferred)
    Write-Host "Checking MSBuild..." -ForegroundColor Gray
    $HasMSBuild = $false
    try {
        $MSBuildVersion = & msbuild -version 2>$null | Select-Object -Last 1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ MSBuild found: $MSBuildVersion" -ForegroundColor Green
            $HasMSBuild = $true
        }
    }
    catch {
        Write-Host "  ❌ MSBuild not found" -ForegroundColor Red
    }
    
    # Check for .NET SDK (alternative)
    Write-Host "Checking .NET SDK..." -ForegroundColor Gray
    $HasDotNet = $false
    try {
        $DotNetVersion = & dotnet --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ .NET SDK found: $DotNetVersion" -ForegroundColor Green
            $HasDotNet = $true
        }
    }
    catch {
        Write-Host "  ❌ .NET SDK not found" -ForegroundColor Red
    }
    
    # Need at least one build tool
    if (-not $HasMSBuild -and -not $HasDotNet) {
        $AllGood = $false
        $MissingTools += @{
            Name = "Build Tools"
            Install = "Install one of:`n  • Visual Studio Build Tools: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022`n  • .NET SDK: https://dotnet.microsoft.com/download"
            Required = $true
        }
    }
    
    # Check for NuGet (helpful but not required)
    Write-Host "Checking NuGet..." -ForegroundColor Gray
    $HasNuGet = $false
    try {
        $NuGetVersion = & nuget 2>$null | Select-Object -First 1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ NuGet CLI found" -ForegroundColor Green
            $HasNuGet = $true
        }
    }
    catch {
        Write-Host "  ⚠️  NuGet CLI not found (optional but recommended)" -ForegroundColor Yellow
        $MissingTools += @{
            Name = "NuGet CLI"
            Install = "Download from: https://www.nuget.org/downloads`nOr install via: choco install nuget.commandline"
            Required = $false
        }
    }
    
    # Check for PowerShell version
    Write-Host "Checking PowerShell..." -ForegroundColor Gray
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        Write-Host "  ✓ PowerShell $($PSVersionTable.PSVersion) found" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  PowerShell 5.0+ recommended" -ForegroundColor Yellow
    }
    
    # Summary
    if ($AllGood) {
        Write-Host "`n✅ All required dependencies found!" -ForegroundColor Green
        if (-not $HasNuGet) {
            Write-Host "💡 Consider installing NuGet CLI for better package restore" -ForegroundColor Cyan
        }
        return $true
    } else {
        Write-Host "`n❌ Missing required dependencies:" -ForegroundColor Red
        
        foreach ($Tool in $MissingTools) {
            if ($Tool.Required) {
                Write-Host "`n🔴 $($Tool.Name) (REQUIRED)" -ForegroundColor Red
                Write-Host "$($Tool.Install)" -ForegroundColor Yellow
            }
        }
        
        Write-Host "`n⚠️  Optional tools:" -ForegroundColor Yellow
        foreach ($Tool in $MissingTools) {
            if (-not $Tool.Required) {
                Write-Host "`n🟡 $($Tool.Name) (OPTIONAL)" -ForegroundColor Yellow
                Write-Host "$($Tool.Install)" -ForegroundColor Gray
            }
        }
        
        Write-Host "`n💡 Quick Setup for Windows:" -ForegroundColor Cyan
        Write-Host "1. Install Visual Studio Build Tools 2022" -ForegroundColor Gray
        Write-Host "2. Install .NET Framework 4.8 Developer Pack" -ForegroundColor Gray
        Write-Host "3. Install NuGet CLI (optional)" -ForegroundColor Gray
        
        return $false
    }
}

# Run the check if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Test-Dependencies
}
