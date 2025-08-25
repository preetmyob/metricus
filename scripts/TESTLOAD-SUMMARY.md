# Metricus Load Test Implementation Summary

## Created Files

### PowerShell Scripts
1. **Run-MetricusLoadTest.ps1** - Main comprehensive test script
   - Sets up IIS test site with ASP.NET application
   - Generates configurable load for specified duration
   - Includes multiple test scenarios (CPU, memory, I/O, exceptions)
   - Automatic cleanup of resources
   - Comprehensive progress reporting and statistics

2. **Cleanup-LoadTest.ps1** - Simple cleanup helper
   - Removes leftover test resources
   - Calls main script with cleanup-only parameters

### Batch Files (Windows convenience)
3. **run-load-test.bat** - Double-click to run test
   - Simple Windows batch file for non-technical users
   - Runs 2-minute test with default settings

4. **cleanup-load-test.bat** - Double-click to cleanup
   - Removes any leftover test resources

### Documentation
5. **LOADTEST-README.md** - Comprehensive documentation
   - Usage instructions and examples
   - Parameter reference
   - Troubleshooting guide
   - Integration examples

## Key Features

### Test Application
- **ASP.NET application** with multiple load scenarios:
  - Normal page requests
  - CPU-intensive calculations
  - Memory allocation tests
  - File I/O operations
  - Exception handling
  - Slow response simulation (2-second delays)

### Load Generation
- **Configurable request rate** (default: 60 requests/minute)
- **Configurable duration** (default: 2 minutes)
- **Random action selection** for varied load patterns
- **Real-time progress reporting** every 20 requests
- **Success/error rate tracking**
- **Actual vs target rate monitoring**

### IIS Integration
- **Automatic IIS site creation** with proper configuration
- **Application pool management** with .NET Framework 4.8
- **Port conflict detection**
- **Site health verification** before load generation
- **Complete cleanup** of all resources

### Monitoring Integration
- **Metricus service detection** and status reporting
- **Recommendations** for optimal monitoring setup
- **Compatible with existing Metricus configurations**

## Usage Examples

```powershell
# Quick 2-minute test (default)
.\Run-MetricusLoadTest.ps1

# Extended 5-minute test with higher load
.\Run-MetricusLoadTest.ps1 -LoadDurationMinutes 5 -RequestsPerMinute 120

# Test with custom site name and port
.\Run-MetricusLoadTest.ps1 -SiteName "MyTest" -Port 9090

# Leave resources running for inspection
.\Run-MetricusLoadTest.ps1 -SkipCleanup

# Automated/CI mode (no prompts)
.\Run-MetricusLoadTest.ps1 -Force

# Cleanup only
.\Cleanup-LoadTest.ps1
```

## Integration with Metricus Build

The **Publish-Metricus-Zip.ps1** script has been updated to:
1. Create a `testload/` directory in the release package
2. Copy all test load files to this directory
3. Include them in the final metricus-{version}.zip

## Deployment Structure

After running the publish script, the zip will contain:
```
metricus-1.1.0.zip
└── metricus-1.1.0/
    ├── config.json
    ├── metricus.exe
    ├── [other metricus files]
    ├── Plugins/
    └── testload/                    ← New folder
        ├── Run-MetricusLoadTest.ps1
        ├── Cleanup-LoadTest.ps1
        ├── LOADTEST-README.md
        ├── run-load-test.bat
        └── cleanup-load-test.bat
```

## Prerequisites

- Windows with IIS installed and enabled
- PowerShell 5.1 or higher
- Administrator privileges
- .NET Framework 4.8
- Available port (default: 8080)

## Benefits

1. **Complete testing solution** - Setup, load generation, and cleanup in one script
2. **Realistic load patterns** - Multiple test scenarios simulate real-world usage
3. **Easy to use** - Simple parameters and batch files for convenience
4. **Comprehensive reporting** - Detailed statistics and progress monitoring
5. **Safe cleanup** - Automatic resource cleanup prevents leftover test sites
6. **CI/CD ready** - Supports automation with exit codes and Force parameter
7. **Well documented** - Extensive documentation and examples

This implementation provides a complete, professional-grade load testing solution for Metricus that can be easily deployed and used by both technical and non-technical users.
