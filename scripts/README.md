# Metricus Build Scripts

This folder contains the build and deployment scripts for the Metricus project, along with production configuration files.

## Files

### Build Script
- **`Publish-Metricus.ps1`** - Main PowerShell script to build and package Metricus for deployment

### Configuration Files
- **`config-main.json`** - Main service configuration (interval, active plugins)
- **`config-graphiteout.json`** - GraphiteOut plugin configuration (hostname, port, protocol)
- **`config-sitesfilter.json`** - SitesFilter plugin configuration (IIS/ASP.NET filtering rules)
- **`config-perfcounter.json`** - PerformanceCounter plugin configuration (Windows counters to collect)
- **`config-consoleout.json`** - ConsoleOut plugin configuration (minimal, used for debugging)
- **`environment-overrides.json`** - Environment-specific configuration overrides

## Usage

### Basic Usage
```powershell
# Production build (default)
.\scripts\Publish-Metricus.ps1

# Development build with debug enabled
.\scripts\Publish-Metricus.ps1 -Environment Development

# Test build with minimal plugins
.\scripts\Publish-Metricus.ps1 -Environment Test
```

### Advanced Usage
```powershell
# Custom output path
.\scripts\Publish-Metricus.ps1 -OutputPath "C:\Deploy\Metricus"

# Debug build configuration
.\scripts\Publish-Metricus.ps1 -Configuration Debug -Environment Development
```

## Environment Configurations

### Production
- **Plugins**: PerformanceCounter, SitesFilter, GraphiteOut
- **Debug**: Disabled
- **Interval**: 10 seconds
- **Purpose**: Production monitoring with full metric collection

### Development
- **Plugins**: PerformanceCounter, SitesFilter, GraphiteOut, ConsoleOut
- **Debug**: Enabled in GraphiteOut and SitesFilter
- **Interval**: 10 seconds
- **Purpose**: Development with console output and debug information

### Test
- **Plugins**: PerformanceCounter, ConsoleOut
- **Debug**: Enabled in all plugins
- **Interval**: 5 seconds
- **Purpose**: Testing with minimal plugins and fast feedback

## Configuration Management

### Modifying Configurations
1. Edit the appropriate `config-*.json` file
2. For environment-specific changes, modify `environment-overrides.json`
3. Run the build script to apply changes

### Adding New Environments
1. Add a new section to `environment-overrides.json`
2. Update the `ValidateSet` in `Publish-Metricus.ps1` to include the new environment
3. Document the new environment in this README

### Configuration Precedence
1. Base configuration from `config-*.json` files
2. Environment overrides from `environment-overrides.json`
3. Final configuration written to deployment package

## Output

The script creates a deployment package with:
- Compiled Metricus service and all plugins
- Applied configuration files
- Windows service installation scripts (`install.bat`, `uninstall.bat`)
- Documentation (`README.md`)

## Requirements

- PowerShell 5.1 or PowerShell Core
- .NET SDK or Visual Studio Build Tools
- Windows (for final deployment)

## Troubleshooting

### Build Failures
- Ensure .NET SDK or MSBuild is installed
- Check that all project dependencies are restored
- Verify solution file exists in parent directory

### Configuration Errors
- Validate JSON syntax in configuration files
- Check that all required properties are present
- Ensure environment names match exactly (case-sensitive)

### Deployment Issues
- Run installation scripts as Administrator on target machine
- Verify .NET Framework 4.8 is installed on target
- Check Windows Event Log for service startup errors
