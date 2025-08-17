<#
.SYNOPSIS
    Builds Metricus release packages.

.DESCRIPTION
    Builds the Metricus solution and creates a deployment-ready zip package.
    Must be run from the directory containing metricus.sln

.EXAMPLE
    .\scripts\Publish-Metricus-Zip.ps1
    Creates metricus-1.1.0.zip with production configuration

.EXAMPLE
    .\scripts\Publish-Metricus-Zip.ps1 -Dev
    Creates metricus-1.1.0.zip with development configuration (console output, external Graphite)

.EXAMPLE
    .\scripts\Publish-Metricus-Zip.ps1 -Test
    Creates metricus-1.1.0.zip with test configuration (local test Graphite, debug mode)
#>

param(
    [switch]$Dev,
    [switch]$Test,
    [switch]$MinTest,
    [switch]$SkipDependencyCheck
)

$ErrorActionPreference = "Stop"

# Check that we're running from the correct directory
$CurrentDir = Get-Location
$SolutionPath = Join-Path $CurrentDir "metricus.sln"
if (-not (Test-Path $SolutionPath)) {
    Write-Host "❌ metricus.sln not found in current directory!" -ForegroundColor Red
    Write-Host "Current directory: $CurrentDir" -ForegroundColor Gray
    Write-Host "`nPlease run this script from the directory containing metricus.sln:" -ForegroundColor Yellow
    Write-Host "cd /path/to/metricus-refactor" -ForegroundColor Gray
    Write-Host ".\scripts\Publish-Metricus-Zip.ps1" -ForegroundColor Gray
    throw "Solution file not found in current directory"
}

# Check if we're on a mapped drive (MSBuild has issues with Mac filesystem via mapped drives)
$IsOnMappedDrive = $CurrentDir.Path -match '^[A-Z]:\\'
$SolutionRoot = $CurrentDir
$ScriptDir = Join-Path $SolutionRoot "scripts"

if ($IsOnMappedDrive) {
    Write-Host "Detected mapped drive - copying source to local temp directory for MSBuild..." -ForegroundColor Yellow
    
    # Use a simpler temp directory path to avoid encoding issues
    $TempBuildDir = "C:\Temp\metricus-build-$(Get-Random)"
    Write-Host "Temp build directory: $TempBuildDir" -ForegroundColor Gray
    
    try {
        # Create temp directory (and parent if needed)
        New-Item -ItemType Directory -Path $TempBuildDir -Force | Out-Null
        
        # Copy source files, excluding build artifacts
        Write-Host "Copying source files (excluding build artifacts)..." -ForegroundColor Gray
        
        # Copy essential files first
        $EssentialFiles = @("*.sln", "*.cs", "GlobalAssemblyInfo.cs", "*.md", "LICENSE", "packages.config")
        foreach ($Pattern in $EssentialFiles) {
            Get-ChildItem -Path $SolutionRoot -Filter $Pattern -Recurse | ForEach-Object {
                $RelativePath = $_.FullName.Substring($SolutionRoot.ToString().Length + 1)
                $TargetPath = Join-Path $TempBuildDir $RelativePath
                $TargetDir = Split-Path $TargetPath -Parent
                
                if (-not (Test-Path $TargetDir)) {
                    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
                }
                
                Copy-Item $_.FullName $TargetPath -Force
                if ($Pattern -eq "packages.config") {
                    Write-Host "  ✓ $RelativePath" -ForegroundColor Gray
                }
            }
        }
        
        # Copy root level files
        Get-ChildItem -Path $SolutionRoot -File | Where-Object { 
            $_.Extension -in @('.sln', '.cs', '.md', '.txt') -or $_.Name -eq 'LICENSE' 
        } | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $TempBuildDir $_.Name) -Force
            Write-Host "  ✓ $($_.Name)" -ForegroundColor Gray
        }
        
        # Copy directories, excluding problematic ones
        $ExcludeDirs = @("bin", "obj", ".vs", ".git", "packages", "TestResults")
        $DirsToInclude = @("metricus", "PluginInterface", "Plugins", "scripts", "tests")
        
        foreach ($DirName in $DirsToInclude) {
            $SourceDir = Join-Path $SolutionRoot $DirName
            $TargetDir = Join-Path $TempBuildDir $DirName
            
            if (Test-Path $SourceDir) {
                Write-Host "  Copying $DirName..." -ForegroundColor Gray
                try {
                    # Use robocopy for directory copying with exclusions
                    $robocopyResult = & robocopy $SourceDir $TargetDir /E /XD bin obj .vs .git packages TestResults /XF *.user *.suo *.cache /NFL /NDL /NJH /NJS /NC /NS /NP
                    Write-Host "  ✓ $DirName copied" -ForegroundColor Gray
                }
                catch {
                    # Fallback to PowerShell copy
                    Write-Host "  Robocopy failed, using PowerShell copy..." -ForegroundColor Yellow
                    Copy-Item $SourceDir $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "  ✓ $DirName copied (fallback)" -ForegroundColor Gray
                }
            }
        }
        
        # Verify essential files were copied
        $TempSolutionPath = Join-Path $TempBuildDir "metricus.sln"
        if (-not (Test-Path $TempSolutionPath)) {
            throw "Solution file was not copied successfully"
        }
        
        # List what we actually copied for debugging
        Write-Host "Temp directory contents:" -ForegroundColor Gray
        Get-ChildItem $TempBuildDir | ForEach-Object {
            Write-Host "  - $($_.Name)" -ForegroundColor DarkGray
        }
        
        # Update paths to use temp directory
        $SolutionRoot = $TempBuildDir
        $SolutionPath = $TempSolutionPath
        $ScriptDir = Join-Path $TempBuildDir "scripts"
        
        # Set cleanup flag for temp directory
        $script:CleanupTempDir = $TempBuildDir
        
        Write-Host "✅ Source copied to local temp directory" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to copy source to temp directory: $($_.Exception.Message)" -ForegroundColor Red
        throw "Cannot prepare build environment"
    }
}

$OutputPath = Join-Path $SolutionRoot "releases"

Write-Host "=== Metricus Build ===" -ForegroundColor Green
Write-Host "Solution: $SolutionPath" -ForegroundColor Gray

# Wrap main logic in try-finally for cleanup
try {
    # Check dependencies first (unless skipped)
    if (-not $SkipDependencyCheck) {
        Write-Host "Checking build dependencies..." -ForegroundColor Green
        
        $AllGood = $true
        $MissingTools = @()
        
        # Check for .NET Framework (required for .NET Framework 4.8 projects)
        try {
            $NetFramework = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction SilentlyContinue
            if ($NetFramework.Release -ge 528040) {  # .NET Framework 4.8
                Write-Host "  ✓ .NET Framework 4.8+ found" -ForegroundColor Green
            } else {
                Write-Host "  ❌ .NET Framework 4.8+ required" -ForegroundColor Red
                $AllGood = $false
                $MissingTools += ".NET Framework 4.8"
            }
        }
        catch {
            Write-Host "  ⚠️  Could not detect .NET Framework version" -ForegroundColor Yellow
        }
        
        # Check for MSBuild (required)
        $HasMSBuild = $false
        try {
            $null = & msbuild -version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ MSBuild found" -ForegroundColor Green
                $HasMSBuild = $true
            }
        }
        catch { }
        
        if (-not $HasMSBuild) {
            Write-Host "  ❌ MSBuild not found" -ForegroundColor Red
            $AllGood = $false
            $MissingTools += "MSBuild"
        }
        
        # Fail fast if missing required dependencies
        if (-not $AllGood) {
            Write-Host "`n❌ Missing required dependencies!" -ForegroundColor Red
            Write-Host "`nTo fix this, install:" -ForegroundColor Yellow
            
            if ($MissingTools -contains ".NET Framework 4.8") {
                Write-Host "`n🔴 .NET Framework 4.8 Developer Pack" -ForegroundColor Red
                Write-Host "   Download: https://dotnet.microsoft.com/download/dotnet-framework/net48" -ForegroundColor Gray
            }
            
            if ($MissingTools -contains "MSBuild") {
                Write-Host "`n🔴 MSBuild (Visual Studio Build Tools)" -ForegroundColor Red
                Write-Host "   Download: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" -ForegroundColor Gray
            }
            
            throw "Missing required build dependencies"
        }
        
        Write-Host "✅ Dependencies OK" -ForegroundColor Green
    }

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

    # Restore and build with MSBuild
    Write-Host "`nRestoring packages and building..." -ForegroundColor Green

    # Debug: Check if solution file actually exists and is readable
    Write-Host "Debug: Checking solution file..." -ForegroundColor Gray
    Write-Host "  Path: $SolutionPath" -ForegroundColor Gray
    Write-Host "  Exists: $(Test-Path $SolutionPath)" -ForegroundColor Gray
    if (Test-Path $SolutionPath) {
        $SolutionSize = (Get-Item $SolutionPath).Length
        Write-Host "  Size: $SolutionSize bytes" -ForegroundColor Gray
        
        # Try to read first few lines
        try {
            $FirstLines = Get-Content $SolutionPath -TotalCount 3
            Write-Host "  First line: $($FirstLines[0])" -ForegroundColor Gray
        }
        catch {
            Write-Host "  Cannot read file: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    try {
        Write-Host "MSBuild restore and build..." -ForegroundColor Gray
        
        # Try different approaches to work around the issue
        $BuildSuccess = $false
        
        # Approach 1: Try with current directory set to solution directory
        $OriginalLocation = Get-Location
        try {
            Set-Location (Split-Path $SolutionPath -Parent)
            $SolutionFileName = Split-Path $SolutionPath -Leaf
            Write-Host "Trying from solution directory with filename: $SolutionFileName" -ForegroundColor Gray
            
            & msbuild "`"$SolutionFileName`"" /t:Restore,Rebuild /p:Configuration=Release /p:Platform="Any CPU" /verbosity:minimal
            if ($LASTEXITCODE -eq 0) {
                $BuildSuccess = $true
                Write-Host "✅ Build successful (approach 1)" -ForegroundColor Green
            }
        }
        finally {
            Set-Location $OriginalLocation
        }
        
        # Approach 2: Try with full path but different syntax and proper NuGet restore
        if (-not $BuildSuccess) {
            Write-Host "Trying with different path syntax and NuGet restore..." -ForegroundColor Gray
            
            # Change to solution directory for better package restore
            Set-Location (Split-Path $SolutionPath -Parent)
            try {
                # First try to restore packages using NuGet (better for packages.config)
                $LocalNuGet = Join-Path $ScriptDir "nuget.exe"
                if (Test-Path $LocalNuGet) {
                    Write-Host "Using local nuget.exe for restore..." -ForegroundColor Gray
                    & $LocalNuGet restore "metricus.sln"
                } else {
                    Write-Host "Using MSBuild restore..." -ForegroundColor Gray
                    & msbuild "metricus.sln" /t:Restore /verbosity:minimal
                }
                
                # Then build
                Write-Host "Building after restore..." -ForegroundColor Gray
                & msbuild "metricus.sln" /t:Rebuild /p:Configuration=Release /p:Platform="Any CPU" /verbosity:minimal
                if ($LASTEXITCODE -eq 0) {
                    $BuildSuccess = $true
                    Write-Host "✅ Build successful (approach 2)" -ForegroundColor Green
                }
            }
            finally {
                Set-Location $OriginalLocation
            }
        }
        
        # Approach 3: Try copying solution file without BOM
        if (-not $BuildSuccess) {
            Write-Host "Trying to fix BOM encoding issue..." -ForegroundColor Gray
            $SolutionContent = Get-Content $SolutionPath -Raw
            $CleanSolutionPath = $SolutionPath -replace '\.sln$', '_clean.sln'
            [System.IO.File]::WriteAllText($CleanSolutionPath, $SolutionContent, [System.Text.Encoding]::UTF8)
            
            & msbuild "`"$CleanSolutionPath`"" /t:Restore,Rebuild /p:Configuration=Release /p:Platform="Any CPU" /verbosity:minimal
            if ($LASTEXITCODE -eq 0) {
                $BuildSuccess = $true
                Write-Host "✅ Build successful (approach 3 - BOM fix)" -ForegroundColor Green
            }
        }
        
        if (-not $BuildSuccess) {
            throw "All MSBuild approaches failed with exit code $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "`n❌ Build failed" -ForegroundColor Red
        Write-Host "`nTroubleshooting steps:" -ForegroundColor Yellow
        Write-Host "1. Check that all NuGet packages can be downloaded" -ForegroundColor Gray
        Write-Host "2. Verify all project references are correct" -ForegroundColor Gray
        Write-Host "3. Check for missing Windows SDK components" -ForegroundColor Gray
        Write-Host "4. Solution file may have encoding issues" -ForegroundColor Gray
        throw "Build failed. Please resolve the issues above and try again."
    }

    # Copy main executable and dependencies
    Write-Host "Copying files..." -ForegroundColor Green
    $MainBinPath = Join-Path $SolutionRoot "metricus\bin\Release"

    if (-not (Test-Path $MainBinPath)) {
        throw "Build output not found at: $MainBinPath"
    }

    $MainFiles = @("metricus.exe", "metricus.exe.config", "PluginInterface.dll")
    foreach ($File in $MainFiles) {
        $SourcePath = Join-Path $MainBinPath $File
        if (Test-Path $SourcePath) {
            Copy-Item $SourcePath $ReleaseDir
            Write-Host "  ✓ $File" -ForegroundColor Gray
        } else {
            Write-Warning "Missing: $File"
        }
    }

    # Copy dependencies (including System DLLs that might be missing in Release)
    $DependencyPatterns = @("Topshelf*.dll", "Topshelf*.xml", "NLog*.dll", "NLog*.xml", 
                           "Newtonsoft.Json*.dll", "System.*.dll", "System.*.xml", "ServiceStack*.dll", "ServiceStack*.xml",
                           "Microsoft.*.dll", "Microsoft.*.xml")
    foreach ($Pattern in $DependencyPatterns) {
        Get-ChildItem -Path $MainBinPath -Filter $Pattern | ForEach-Object {
            Copy-Item $_.FullName $ReleaseDir
            Write-Host "  ✓ $($_.Name)" -ForegroundColor Gray
        }
    }
    
    # Also copy System DLLs from Debug build if Release is missing them (common issue)
    $DebugBinPath = Join-Path $SolutionRoot "metricus\bin\Debug"
    if ((Test-Path $DebugBinPath) -and ((Get-ChildItem -Path $MainBinPath -Filter "System.*.dll").Count -eq 0)) {
        Write-Host "Release build missing System DLLs, copying from Debug build..." -ForegroundColor Yellow
        
        # Copy from main Debug directory
        Get-ChildItem -Path $DebugBinPath -Filter "System.*.dll" | ForEach-Object {
            $TargetPath = Join-Path $ReleaseDir $_.Name
            if (-not (Test-Path $TargetPath)) {
                Copy-Item $_.FullName $ReleaseDir
                Write-Host "  ✓ $($_.Name) (from Debug)" -ForegroundColor Gray
            }
        }
        
        # Also copy from Debug plugin directories (where most System DLLs actually are)
        $DebugPluginsPath = Join-Path $DebugBinPath "Plugins"
        if (Test-Path $DebugPluginsPath) {
            Get-ChildItem -Path $DebugPluginsPath -Recurse -Filter "System.*.dll" | ForEach-Object {
                $TargetPath = Join-Path $ReleaseDir $_.Name
                if (-not (Test-Path $TargetPath)) {
                    Copy-Item $_.FullName $ReleaseDir
                    Write-Host "  ✓ $($_.Name) (from Debug plugins)" -ForegroundColor Gray
                }
            }
        }
    }

    # Create Plugins directory and copy plugins
    $PluginsDir = Join-Path $ReleaseDir "Plugins"
    New-Item -ItemType Directory -Path $PluginsDir -Force | Out-Null

    $PluginNames = @("ConsoleOut", "GraphiteOut", "PerfCounter", "SitesFilter")
    foreach ($PluginName in $PluginNames) {
        $PluginReleaseDir = Join-Path $PluginsDir $PluginName
        New-Item -ItemType Directory -Path $PluginReleaseDir -Force | Out-Null
        
        # Try multiple possible locations for plugin DLLs
        $PossiblePaths = @(
            (Join-Path $SolutionRoot "Plugins\$PluginName\bin\Release"),
            (Join-Path $SolutionRoot "metricus\bin\Release\Plugins\$PluginName"),
            (Join-Path $SolutionRoot "metricus\bin\Debug\Plugins\$PluginName")
        )
        
        $PluginDllFound = $false
        foreach ($PluginBinPath in $PossiblePaths) {
            if (Test-Path $PluginBinPath) {
                $AllFiles = Get-ChildItem -Path $PluginBinPath -Filter "*.*" | Where-Object { 
                    $_.Extension -in @('.dll', '.config', '.xml') 
                }
                if ($AllFiles.Count -gt 0) {
                    Write-Host "  Found $PluginName files in: $PluginBinPath" -ForegroundColor Gray
                    foreach ($File in $AllFiles) {
                        Copy-Item $File.FullName $PluginReleaseDir
                        Write-Host "  ✓ $PluginName\$($File.Name)" -ForegroundColor Gray
                    }
                    $PluginDllFound = $true
                    break
                }
            }
        }
        
        if (-not $PluginDllFound) {
            Write-Warning "Plugin DLLs not found for $PluginName in any of the expected locations"
            Write-Host "  Searched:" -ForegroundColor Yellow
            $PossiblePaths | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
        } else {
            # Create plugin .config file with assembly binding redirects if needed
            $PluginDllPath = Join-Path $PluginReleaseDir "$PluginName.dll"
            $PluginConfigPath = Join-Path $PluginReleaseDir "$PluginName.dll.config"
            
            if ((Test-Path $PluginDllPath) -and (-not (Test-Path $PluginConfigPath))) {
                Write-Host "  Creating assembly binding redirects for $PluginName..." -ForegroundColor Gray
                
                $ConfigContent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <runtime>
    <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">
      <dependentAssembly>
        <assemblyIdentity name="System.Runtime.CompilerServices.Unsafe" publicKeyToken="b03f5f7f11d50a3a" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-6.0.0.0" newVersion="6.0.0.0" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Memory" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-4.0.1.2" newVersion="4.0.1.2" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Buffers" publicKeyToken="cc7b13ffcd2ddd51" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-4.0.3.0" newVersion="4.0.3.0" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="ServiceStack.Text" publicKeyToken="02c12cbda47e6587" culture="neutral" />
        <bindingRedirect oldVersion="0.0.0.0-6.0.0.0" newVersion="4.0.9.0" />
      </dependentAssembly>
    </assemblyBinding>
  </runtime>
</configuration>
"@
                [System.IO.File]::WriteAllText($PluginConfigPath, $ConfigContent, [System.Text.Encoding]::UTF8)
                Write-Host "  ✓ $PluginName\$PluginName.dll.config (generated)" -ForegroundColor Gray
            }
        }
    }

    # Copy configuration files
    Write-Host "Setting up configuration..." -ForegroundColor Green
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
            Write-Host "  ✓ $($ConfigFile.Target)" -ForegroundColor Gray
        } else {
            Write-Warning "Config file not found: $($ConfigFile.Source)"
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
                    Write-Host "  ✓ Main config updated" -ForegroundColor Gray
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
                            Write-Host "  ✓ $PluginName config updated" -ForegroundColor Gray
                        }
                    }
                }
            } else {
                Write-Warning "Environment '$Environment' not found in overrides file"
            }
        } else {
            Write-Warning "Environment overrides file not found: $OverridesPath"
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

    # Copy zip file back to original root releases folder if we used temp directory
    if ($script:CleanupTempDir) {
        $OriginalRootDir = Get-Location
        $OriginalOutputPath = Join-Path $OriginalRootDir "releases"
        $OriginalZipPath = Join-Path $OriginalOutputPath "metricus-$Version.zip"
        
        Write-Host "`nCopying package to releases folder..." -ForegroundColor Green
        
        # Ensure root releases directory exists
        if (-not (Test-Path $OriginalOutputPath)) {
            New-Item -ItemType Directory -Path $OriginalOutputPath -Force | Out-Null
        }
        
        # Copy the zip file
        Copy-Item $ZipPath $OriginalZipPath -Force
        Write-Host "Package copied to: $OriginalZipPath" -ForegroundColor Gray
        
        # Update the display path
        $ZipPath = $OriginalZipPath
    }

    Write-Host "`n✅ Ready to deploy!" -ForegroundColor Green
    Write-Host "Final package location: $ZipPath" -ForegroundColor Cyan

}
catch {
    # Re-throw the error
    Write-Host "`n❌ Build failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
finally {
    # Cleanup temp directory if we created one
    if ($script:CleanupTempDir -and (Test-Path $script:CleanupTempDir)) {
        Write-Host "`nCleaning up temp directory..." -ForegroundColor Gray
        try {
            Remove-Item $script:CleanupTempDir -Recurse -Force
            Write-Host "✅ Temp directory cleaned up" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️  Could not clean up temp directory: $script:CleanupTempDir" -ForegroundColor Yellow
        }
    }
}
