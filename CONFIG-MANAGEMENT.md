# Metricus Configuration Management

This document describes how to manage Metricus configurations for different environments.

## Prerequisites

- PowerShell (Windows PowerShell or PowerShell Core)
- Metricus project built in Debug or Release configuration

## Available Environments

| Environment | Description | Metrics Pattern | Use Case |
|-------------|-------------|-----------------|----------|
| **Development** | Default development settings | `advanced.development.*` | Local development |
| **Test** | Full test environment | `advanced.development.preet.i-9999999.*` | Testing with full metrics |
| **MinTest** | Minimal test environment | `minimal.test.minimal.*` | Testing with 3 basic metrics |
| **Prod** | Production environment | `advanced.production.preet.i-9999999.*` | Production-like testing |

## Usage

### Apply Configuration

```powershell
# Apply MinTest environment (minimal metrics)
.\scripts\Update-Configs.ps1 -Environment MinTest

# Apply Test environment (full metrics)
.\scripts\Update-Configs.ps1 -Environment Test

# Apply Prod environment (production-like)
.\scripts\Update-Configs.ps1 -Environment Prod

# Apply with backup
.\scripts\Update-Configs.ps1 -Environment Test -Backup

# Apply to Release build
.\scripts\Update-Configs.ps1 -Environment Test -Configuration Release
```

### Restore Configuration

```powershell
# Restore from backup
.\scripts\Update-Configs.ps1 -Restore
```

## Configuration Details

### MinTest Environment
- **Purpose**: Minimal testing with basic system metrics
- **Metrics**: Only 3 performance counters (CPU, Memory, System processes)
- **Interval**: 10 seconds
- **Plugins**: PerformanceCounter, GraphiteOut, ConsoleOut
- **Graphite**: 10.0.0.14:2003
- **Pattern**: `minimal.test.minimal.*`

### Test Environment  
- **Purpose**: Full testing with all metrics
- **Metrics**: All performance counters (50+ metrics)
- **Interval**: 5 seconds
- **Plugins**: PerformanceCounter, SitesFilter, GraphiteOut, ConsoleOut
- **Graphite**: 10.0.0.14:2003
- **Pattern**: `advanced.development.preet.i-9999999.*`

### Prod Environment
- **Purpose**: Production-like configuration for testing
- **Metrics**: All performance counters (50+ metrics)
- **Interval**: 10 seconds
- **Plugins**: PerformanceCounter, SitesFilter, GraphiteOut (no ConsoleOut)
- **Graphite**: 10.0.0.14:2003
- **Pattern**: `advanced.production.preet.i-9999999.*`
- **Debug**: Disabled (production-ready)

## Testing Workflow

1. **Apply configuration**:
   ```powershell
   .\scripts\Update-Configs.ps1 -Environment MinTest
   ```

2. **Run Metricus**:
   ```powershell
   cd .\metricus\bin\Debug
   .\metricus.exe
   ```

3. **View metrics**: Open http://10.0.0.14:8080 in browser

4. **Restore when done**:
   ```powershell
   .\scripts\Update-Configs.ps1 -Restore
   ```

## Files Modified

The script updates these configuration files:
- `metricus\bin\Debug\config.json` - Main service configuration
- `metricus\bin\Debug\Plugins\GraphiteOut\config.json` - Graphite output settings
- `metricus\bin\Debug\Plugins\SitesFilter\config.json` - Site filtering rules
- `metricus\bin\Debug\Plugins\PerfCounter\config.json` - Performance counter definitions
- `metricus\bin\Debug\Plugins\ConsoleOut\config.json` - Console output settings

## Troubleshooting

### Configuration not applied correctly
- Ensure you're running from the project root directory
- Check that the target build configuration exists (Debug/Release)
- Verify PowerShell execution policy allows script execution

### Metrics not appearing in Graphite
- Verify Graphite is running: http://10.0.0.14:8080
- Check Metricus console output for connection errors
- Ensure Windows performance counters are accessible
- Try MinTest environment first (simpler configuration)

### Restore backup
If configuration gets corrupted, use the restore command:
```powershell
.\scripts\Update-Configs.ps1 -Restore
```
