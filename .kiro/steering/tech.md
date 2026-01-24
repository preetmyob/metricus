---
inclusion: always
---

# Technology Stack

## Platform

- **.NET Framework 4.8** (target framework)
- **C# (latest language version)** for all code
- **Windows-only** (requires Windows Performance Counters and IIS)

## Build System

- **MSBuild** (Visual Studio 2012+ solution format)
- **NuGet** for package management
- Solution file: `metricus.sln`

## Key Dependencies

- **TopShelf 3.1.3**: Windows service hosting
- **TopShelf.NLog 3.1.3**: Logging integration
- **NLog 4.7.15**: Structured logging
- **ServiceStack.Text 4.0.9**: JSON serialization

## Project Structure

- **metricus**: Main service executable
- **PluginInterface**: Shared plugin interfaces and types
- **Plugins**: Individual plugin projects (ConsoleOut, GraphiteOut, PerformanceCounter, SitesFilter)

## Common Commands

### Build

```bash
# Restore NuGet packages
nuget restore metricus.sln

# Build solution (Debug)
msbuild metricus.sln /p:Configuration=Debug

# Build solution (Release)
msbuild metricus.sln /p:Configuration=Release
```

### Development Workflow

```powershell
# Build and package for development (with console output and debug)
.\scripts\Publish-Metricus-Zip.ps1 -Dev

# Build and package for production
.\scripts\Publish-Metricus-Zip.ps1

# Apply test configuration to Debug build
.\scripts\Update-Configs.ps1 -Environment Test

# Run service locally (from bin directory)
cd metricus\bin\Debug
.\metricus.exe
```

### Testing

```powershell
# Set up IIS test sites
.\scripts\Setup-TestIIS.ps1

# Generate load for testing
.\scripts\Generate-Load.ps1 -DurationMinutes 30 -RequestsPerMinute 60

# Clean up test sites
.\scripts\Cleanup-TestIIS.ps1
```

### Configuration Management

```powershell
# Apply MinTest environment (3 basic metrics)
.\scripts\Update-Configs.ps1 -Environment MinTest

# Apply Test environment (full metrics, 5s interval)
.\scripts\Update-Configs.ps1 -Environment Test

# Apply Prod environment (production-like)
.\scripts\Update-Configs.ps1 -Environment Prod

# Restore from backup
.\scripts\Update-Configs.ps1 -Restore
```

## Output Paths

- **Debug**: `metricus\bin\Debug\`
- **Release**: `metricus\bin\Release\`
- **Plugins**: Output to main service bin directory
- **Packages**: `scripts\releases\metricus-{version}.zip`

## Version Management

- Centralized in `GlobalAssemblyInfo.cs`
- Current version: 1.1.0
- All projects link to GlobalAssemblyInfo for consistent versioning
