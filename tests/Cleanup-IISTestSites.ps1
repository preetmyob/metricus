# Cleanup-IISTestSites.ps1
# Removes IIS test sites created for Metricus testing

param(
    [string]$SiteInfoFile = "test-sites.json",
    [string]$BasePath = "C:\inetpub\metricus-test",
    [switch]$Force
)

# Ensure running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Import WebAdministration module
Import-Module WebAdministration -ErrorAction Stop

Write-Host "Cleaning up IIS test sites..." -ForegroundColor Yellow

# Load site information if available
$sites = @()
$siteInfoPath = Join-Path $PSScriptRoot $SiteInfoFile
if (Test-Path $siteInfoPath) {
    try {
        $siteInfo = Get-Content $siteInfoPath | ConvertFrom-Json
        $sites = $siteInfo.Sites
        Write-Host "Loaded site information from $SiteInfoFile"
    }
    catch {
        Write-Warning "Could not load site information from $SiteInfoFile"
    }
}

# If no site info, find sites by pattern
if ($sites.Count -eq 0) {
    Write-Host "Searching for MetricusTest* sites..."
    $iisSites = Get-Website | Where-Object { $_.Name -like "MetricusTest*" }
    foreach ($iisSite in $iisSites) {
        $sites += @{
            Name = $iisSite.Name
            Port = $iisSite.Bindings.Collection[0].bindingInformation.Split(':')[1]
            Path = $iisSite.PhysicalPath
        }
    }
}

if ($sites.Count -eq 0) {
    Write-Host "No Metricus test sites found to clean up." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($sites.Count) test sites to remove:" -ForegroundColor Cyan
foreach ($site in $sites) {
    Write-Host "  - $($site.Name) (Port: $($site.Port))"
}

# Confirm deletion unless -Force is used
if (-not $Force) {
    $confirmation = Read-Host "`nAre you sure you want to remove these sites? (y/N)"
    if ($confirmation -notmatch '^[Yy]') {
        Write-Host "Cleanup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Remove sites and app pools
Write-Host "`nRemoving sites and application pools..." -ForegroundColor Yellow
foreach ($site in $sites) {
    $siteName = $site.Name
    
    try {
        # Stop and remove website
        if (Get-Website -Name $siteName -ErrorAction SilentlyContinue) {
            Stop-Website -Name $siteName -ErrorAction SilentlyContinue
            Remove-Website -Name $siteName
            Write-Host "✓ Removed website: $siteName" -ForegroundColor Green
        }
        
        # Remove application pool
        $appPoolName = $siteName
        if (Get-IISAppPool -Name $appPoolName -ErrorAction SilentlyContinue) {
            Stop-WebAppPool -Name $appPoolName -ErrorAction SilentlyContinue
            Remove-WebAppPool -Name $appPoolName
            Write-Host "✓ Removed app pool: $appPoolName" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to remove $siteName`: $($_.Exception.Message)"
    }
}

# Remove physical directories
if (Test-Path $BasePath) {
    Write-Host "`nRemoving physical directories..." -ForegroundColor Yellow
    
    if (-not $Force) {
        $confirmation = Read-Host "Remove physical files at $BasePath? (y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-Host "Physical files preserved." -ForegroundColor Yellow
        }
        else {
            try {
                Remove-Item -Path $BasePath -Recurse -Force
                Write-Host "✓ Removed directory: $BasePath" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to remove directory $BasePath`: $($_.Exception.Message)"
            }
        }
    }
    else {
        try {
            Remove-Item -Path $BasePath -Recurse -Force
            Write-Host "✓ Removed directory: $BasePath" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to remove directory $BasePath`: $($_.Exception.Message)"
        }
    }
}

# Clean up generated files
$filesToClean = @("test-sites.json", "traffic-stats.json")
foreach ($file in $filesToClean) {
    $filePath = Join-Path $PSScriptRoot $file
    if (Test-Path $filePath) {
        Remove-Item -Path $filePath -Force
        Write-Host "✓ Removed file: $file" -ForegroundColor Green
    }
}

Write-Host "`nCleanup completed!" -ForegroundColor Green
Write-Host "All Metricus test sites and related files have been removed." -ForegroundColor Cyan
