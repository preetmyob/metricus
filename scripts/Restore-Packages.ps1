<#
.SYNOPSIS
    Restores NuGet packages for the Metricus solution.

.DESCRIPTION
    This script restores all NuGet packages required by the Metricus solution using MSBuild.
    Run this before building if you get missing assembly errors.
#>

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SolutionRoot = Split-Path -Parent $ScriptDir

# Handle UNC paths by mapping to drive letter
if ($SolutionRoot -match '^\\\\') {
    Write-Host "Detected UNC path, mapping to drive letter..." -ForegroundColor Yellow
    
    # Find available drive letter (starting with X:)
    $AvailableDrive = $null
    for ($i = 88; $i -ge 65; $i--) {  # X to A
        $DriveLetter = [char]$i
        if (-not (Test-Path "${DriveLetter}:\")) {
            $AvailableDrive = $DriveLetter
            break
        }
    }
    
    if ($AvailableDrive) {
        $UNCRoot = $SolutionRoot -replace '\\[^\\]*$', ''  # Get UNC root path
        Write-Host "Mapping $UNCRoot to ${AvailableDrive}:" -ForegroundColor Gray
        
        try {
            & net use "${AvailableDrive}:" "$UNCRoot" 2>$null
            if ($LASTEXITCODE -eq 0) {
                # Update paths to use mapped drive
                $SolutionRoot = $SolutionRoot -replace [regex]::Escape($UNCRoot), "${AvailableDrive}:"
                Write-Host "✅ Mapped to ${AvailableDrive}: drive" -ForegroundColor Green
                $script:CleanupDrive = $AvailableDrive
            }
        }
        catch {
            Write-Host "⚠️  Drive mapping failed, continuing with UNC path" -ForegroundColor Yellow
        }
    }
}

# Find the solution file - check both parent directory and current directory
$SolutionPath = Join-Path $SolutionRoot "metricus.sln"
if (-not (Test-Path $SolutionPath)) {
    # Try the scripts directory itself (solution might be at same level as scripts folder)
    $AlternateSolutionRoot = Split-Path -Parent $ScriptDir
    $AlternateSolutionPath = Join-Path $AlternateSolutionRoot "metricus.sln"
    if (Test-Path $AlternateSolutionPath) {
        $SolutionRoot = $AlternateSolutionRoot
        $SolutionPath = $AlternateSolutionPath
        Write-Host "Found solution at: $SolutionPath" -ForegroundColor Gray
    } else {
        throw "Cannot find metricus.sln in $SolutionRoot or $AlternateSolutionRoot"
    }
}

Write-Host "=== Restoring NuGet Packages ===" -ForegroundColor Green
Write-Host "Solution: $SolutionPath" -ForegroundColor Gray

Write-Host "=== Restoring NuGet Packages ===" -ForegroundColor Green
Write-Host "Solution: $SolutionPath" -ForegroundColor Gray

# Wrap main logic in try-finally to ensure UNC cleanup
try {
    # Use MSBuild to restore packages (works best with packages.config)
    try {
        Write-Host "Restoring packages with MSBuild..." -ForegroundColor Gray
        & msbuild "`"$SolutionPath`"" /t:Restore /verbosity:minimal
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Packages restored successfully" -ForegroundColor Green
        } else {
            throw "MSBuild restore failed with exit code $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "❌ Package restore failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
        Write-Host "1. Ensure MSBuild is installed (Visual Studio Build Tools)" -ForegroundColor Gray
        Write-Host "2. Check internet connection for NuGet package downloads" -ForegroundColor Gray
        Write-Host "3. Verify solution file exists: $SolutionPath" -ForegroundColor Gray
        throw "Package restore failed"
    }

    Write-Host "`n✅ Package restore completed!" -ForegroundColor Green
    Write-Host "You can now run .\Publish-Metricus-Zip.ps1" -ForegroundColor Gray

}
catch {
    # Re-throw the error after cleanup
    Write-Host "`n❌ Restore failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
finally {
    # Always cleanup mapped drive if we created one
    if ($script:CleanupDrive) {
        Write-Host "`nCleaning up mapped drive ${script:CleanupDrive}:..." -ForegroundColor Gray
        try {
            & net use "${script:CleanupDrive}:" /delete 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Drive ${script:CleanupDrive}: unmapped" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Drive ${script:CleanupDrive}: may still be mapped" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "⚠️  Could not unmap drive ${script:CleanupDrive}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}
