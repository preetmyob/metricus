<#
.SYNOPSIS
    Builds Metricus release packages.

.DESCRIPTION
    Builds the Metricus solution and creates a deployment-ready zip package.

.EXAMPLE
    .\Quick-Build.ps1
    Creates metricus-1.1.0.zip with production configuration

.EXAMPLE
    .\Quick-Build.ps1 -Dev
    Creates metricus-1.1.0.zip with development configuration (console output, external Graphite)

.EXAMPLE
    .\Quick-Build.ps1 -Test
    Creates metricus-1.1.0.zip with test configuration (local test Graphite, debug mode)
#>

param(
    [switch]$Dev,
    [switch]$Test,
    [switch]$MinTest
)

$ErrorActionPreference = "Stop"

# Get directories
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SolutionRoot = Split-Path -Parent $ScriptDir
$OutputPath = Join-Path $ScriptDir "releases"

Write-Host "=== Metricus Build ===" -ForegroundColor Green

# Extract version from GlobalAssemblyInfo.cs
$GlobalAssemblyPath = Join-Path $SolutionRoot "GlobalAssemblyInfo.cs"
$AssemblyContent = Get-Content $GlobalAssemblyPath
$VersionLine = $AssemblyContent | Where-Object { $_ -match 'AssemblyInformationalVersion\("([^"]+)"\)' }
$Version = $Matches[1]

Write-Host "Building version: $Version" -ForegroundColor Yellow

# Determine environment
$Environment = $null
if ($Dev) {
    $Environment = "Development"
    Write-Host "Environment: Development (console output, external Graphite)" -ForegroundColor Cyan
} elseif ($Test) {
    $Environment = "Test"
    Write-Host "Environment: Test (local test Graphite, debug mode)" -ForegroundColor Cyan
} elseif ($MinTest) {
    $Environment = "MinTest"
    Write-Host "Environment: MinTest (minimal monitoring)" -ForegroundColor Cyan
} else {
    Write-Host "Environment: Production (default)" -ForegroundColor Cyan
}

# Create output directories
$ReleaseDir = Join-Path $OutputPath "metricus-$Version"
$ZipPath = Join-Path $OutputPath "metricus-$Version.zip"

if (Test-Path $ReleaseDir) {
    Remove-Item $ReleaseDir -Recurse -Force
}
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

# Build solution
Write-Host "`nBuilding solution..." -ForegroundColor Green
$SolutionPath = Join-Path $SolutionRoot "metricus.sln"

$BuildSuccess = $false
$BuildCommands = @(
    @{ Command = "msbuild"; Args = @("`"$SolutionPath`"", "/p:Configuration=Release", "/p:Platform=`"Any CPU`"", "/t:Clean,Rebuild", "/verbosity:minimal") },
    @{ Command = "dotnet"; Args = @("build", "`"$SolutionPath`"", "--configuration", "Release", "--verbosity", "minimal") }
)

foreach ($BuildCmd in $BuildCommands) {
    try {
        & $BuildCmd.Command @($BuildCmd.Args)
        if ($LASTEXITCODE -eq 0) {
            $BuildSuccess = $true
            Write-Host "✅ Build successful" -ForegroundColor Green
            break
        }
    }
    catch {
        continue
    }
}

if (-not $BuildSuccess) {
    throw "Build failed. Please ensure MSBuild or .NET SDK is available."
}

# Copy main executable and dependencies
Write-Host "Copying files..." -ForegroundColor Green
$MainBinPath = Join-Path $SolutionRoot "metricus\bin\Release"

$MainFiles = @("metricus.exe", "metricus.exe.config", "PluginInterface.dll")
foreach ($File in $MainFiles) {
    $SourcePath = Join-Path $MainBinPath $File
    if (Test-Path $SourcePath) {
        Copy-Item $SourcePath $ReleaseDir
    }
}

# Copy dependencies
$DependencyPatterns = @("Topshelf*.dll", "Topshelf*.xml", "NLog*.dll", "NLog*.xml", 
                       "Newtonsoft.Json*.dll", "System.*.dll", "System.*.xml", "ServiceStack*.dll", "ServiceStack*.xml")
foreach ($Pattern in $DependencyPatterns) {
    Get-ChildItem -Path $MainBinPath -Filter $Pattern | ForEach-Object {
        Copy-Item $_.FullName $ReleaseDir
    }
}

# Create Plugins directory and copy plugins
$PluginsDir = Join-Path $ReleaseDir "Plugins"
New-Item -ItemType Directory -Path $PluginsDir -Force | Out-Null

$PluginNames = @("ConsoleOut", "GraphiteOut", "PerfCounter", "SitesFilter")
foreach ($PluginName in $PluginNames) {
    $PluginBinPath = Join-Path $SolutionRoot "Plugins\$PluginName\bin\Release"
    $PluginReleaseDir = Join-Path $PluginsDir $PluginName
    
    if (Test-Path $PluginBinPath) {
        New-Item -ItemType Directory -Path $PluginReleaseDir -Force | Out-Null
        Get-ChildItem -Path $PluginBinPath -Filter "*.dll" | ForEach-Object {
            Copy-Item $_.FullName $PluginReleaseDir
        }
    }
}

# Copy configuration files
$ConfigFiles = @(
    @{ Source = "config-main.json"; Target = "config.json" },
    @{ Source = "config-perfcounter.json"; Target = "Plugins\PerfCounter\config.json" },
    @{ Source = "config-graphiteout.json"; Target = "Plugins\GraphiteOut\config.json" },
    @{ Source = "config-sitesfilter.json"; Target = "Plugins\SitesFilter\config.json" }
)

foreach ($ConfigFile in $ConfigFiles) {
    $SourcePath = Join-Path $ScriptDir $ConfigFile.Source
    $TargetPath = Join-Path $ReleaseDir $ConfigFile.Target
    $TargetDir = Split-Path -Parent $TargetPath
    
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }
    
    if (Test-Path $SourcePath) {
        Copy-Item $SourcePath $TargetPath
    }
}

# Apply environment overrides if specified
if ($Environment) {
    Write-Host "Applying $Environment overrides..." -ForegroundColor Green
    $OverridesPath = Join-Path $ScriptDir "environment-overrides.json"
    
    if (Test-Path $OverridesPath) {
        $Overrides = Get-Content $OverridesPath | ConvertFrom-Json
        
        if ($Overrides.$Environment) {
            $EnvConfig = $Overrides.$Environment
            
            # Apply main config overrides
            if ($EnvConfig.MainConfig) {
                $MainConfigPath = Join-Path $ReleaseDir "config.json"
                $MainConfig = Get-Content $MainConfigPath | ConvertFrom-Json
                
                $EnvConfig.MainConfig.PSObject.Properties | ForEach-Object {
                    $MainConfig | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                }
                
                $MainConfig | ConvertTo-Json -Depth 10 | Set-Content $MainConfigPath
            }
            
            # Apply plugin config overrides
            @("GraphiteOutConfig", "SitesFilterConfig", "PerformanceCounterConfig") | ForEach-Object {
                $ConfigType = $_
                if ($EnvConfig.$ConfigType) {
                    $PluginName = switch ($ConfigType) {
                        "GraphiteOutConfig" { "GraphiteOut" }
                        "SitesFilterConfig" { "SitesFilter" }
                        "PerformanceCounterConfig" { "PerfCounter" }
                    }
                    
                    $PluginConfigPath = Join-Path $ReleaseDir "Plugins\$PluginName\config.json"
                    if (Test-Path $PluginConfigPath) {
                        $PluginConfig = Get-Content $PluginConfigPath | ConvertFrom-Json
                        
                        $EnvConfig.$ConfigType.PSObject.Properties | ForEach-Object {
                            $PluginConfig | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                        
                        $PluginConfig | ConvertTo-Json -Depth 10 | Set-Content $PluginConfigPath
                    }
                }
            }
        }
    }
}

# Create zip package
Write-Host "Creating zip package..." -ForegroundColor Green
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($ReleaseDir, $ZipPath)
}
catch {
    Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -Force
}

# Summary
Write-Host "`n=== Build Complete ===" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor White
Write-Host "Environment: $(if ($Environment) { $Environment } else { 'Production' })" -ForegroundColor White
Write-Host "Package: $ZipPath" -ForegroundColor White
Write-Host "Size: $([math]::Round((Get-Item $ZipPath).Length / 1MB, 2)) MB" -ForegroundColor White
Write-Host "`n✅ Ready to deploy!" -ForegroundColor Green
