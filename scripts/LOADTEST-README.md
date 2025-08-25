# Metricus Load Testing

This directory contains scripts for comprehensive load testing of Metricus metric collection.

**Compatible with PowerShell 5.1 and PowerShell 7.x**

## Quick Start

```powershell
# Run a 2-minute load test (default)
.\Run-MetricusLoadTest.ps1

# Run a 5-minute test with higher load
.\Run-MetricusLoadTest.ps1 -LoadDurationMinutes 5 -RequestsPerMinute 120

# Run test and leave resources for inspection
.\Run-MetricusLoadTest.ps1 -SkipCleanup

# Clean up resources manually
.\Cleanup-LoadTest.ps1
```

## PowerShell Version Support

The scripts automatically detect and work with:
- **PowerShell 5.1** (Windows PowerShell)
- **PowerShell 7.x** (PowerShell Core)

### Batch Files
- `run-load-test.bat` - Automatically detects and uses the best available PowerShell version
- `cleanup-load-test.bat` - Compatible cleanup using available PowerShell version

## What the Test Does

1. **Setup Phase**
   - Detects PowerShell version and adjusts compatibility
   - Checks prerequisites (Administrator rights, IIS installed)
   - Creates a test ASP.NET application with various load scenarios
   - Sets up IIS application pool and website
   - Verifies the site is responding

2. **Load Generation Phase**
   - Generates HTTP requests at specified rate using compatible HTTP client
   - Randomly selects different test actions:
     - Normal requests
     - CPU-intensive operations
     - Memory allocation tests
     - File I/O operations
     - Exception handling
     - Slow response simulation
   - Reports progress and statistics

3. **Cleanup Phase** (unless skipped)
   - Stops and removes IIS website
   - Removes application pool
   - Deletes test files

## Test Actions

The test application includes several endpoints to generate different types of load:

- **Normal**: Standard page requests
- **CPU**: Intensive mathematical calculations
- **Memory**: Large memory allocations
- **I/O**: File read/write operations
- **Exception**: Handled exception generation
- **Sleep**: Slow response simulation (2-second delay)

## Parameters

### Run-MetricusLoadTest.ps1

| Parameter | Default | Description |
|-----------|---------|-------------|
| `LoadDurationMinutes` | 2 | Duration to generate load |
| `RequestsPerMinute` | 60 | Request rate |
| `SiteName` | MetricusLoadTest | IIS site name |
| `Port` | 8080 | Website port |
| `SkipCleanup` | false | Leave resources running |
| `Force` | false | Skip confirmation prompts |

### Cleanup-LoadTest.ps1

| Parameter | Default | Description |
|-----------|---------|-------------|
| `SiteName` | MetricusLoadTest | Site name to clean up |
| `Port` | 8080 | Website port |

## Prerequisites

- Windows with IIS installed and enabled
- **PowerShell 5.1+ or PowerShell 7.x** (automatically detected)
- Administrator privileges
- .NET Framework 4.8 (for ASP.NET application)

### PowerShell Version Detection

The scripts automatically detect your PowerShell version:

```powershell
# PowerShell 5.1 (Windows PowerShell)
PS C:\> $PSVersionTable.PSVersion
Major  Minor  Build  Revision
-----  -----  -----  --------
5      1      19041  4648

# PowerShell 7.x (PowerShell Core)  
PS C:\> $PSVersionTable.PSVersion
Major  Minor  Patch  PreReleaseLabel BuildLabel
-----  -----  -----  --------------- ----------
7      4      0
```

### Compatibility Features

- **IIS Detection**: Uses Windows-specific cmdlets in PS 5.1, service-based detection in PS 7+
- **Module Loading**: Handles `WebAdministration` module differences between versions
- **HTTP Requests**: Compatible `Invoke-WebRequest` usage with proper SSL/TLS handling
- **Port Checking**: Graceful fallback from `Get-NetTCPConnection` to `netstat` when needed

## Monitoring

The test automatically checks for the Metricus service and reports its status. For best results:

1. Install and start Metricus before running the test
2. Configure Metricus to monitor IIS metrics
3. Check Metricus logs and output during/after the test

## Example Output

```
============================================================
 Metricus Load Test
============================================================
> Checking prerequisites...
  ✓ Running as Administrator
  ✓ IIS is installed and enabled
  ✓ WebAdministration module loaded
  ✓ Port 8080 is available

> Checking Metricus service status...
  ✓ Metricus service found - Status: Running

> Creating test application...
  ✓ Created directory: C:\inetpub\wwwroot\MetricusLoadTest
  ✓ Created Default.aspx
  ✓ Created web.config

> Creating IIS application pool and website...
  ✓ Created application pool: MetricusLoadTestPool
  ✓ Created website: MetricusLoadTest on port 8080
  ✓ Started application pool and website

> Waiting for website to be ready...
  ✓ Website is responding (HTTP 200)

> Starting load generation for 2 minutes...
  ℹ Target: http://localhost:8080
  ℹ Rate: 60 requests/minute
  ℹ Duration: 2 minutes
  ℹ End time: 14:32:15

  📊 Requests: 20 | Success: 100.0% | Rate: 62.1/min | Remaining: 01:41 | Action: cpu
  📊 Requests: 40 | Success: 100.0% | Rate: 61.8/min | Remaining: 01:21 | Action: memory
  📊 Requests: 60 | Success: 100.0% | Rate: 60.2/min | Remaining: 01:01 | Action: io
  📊 Requests: 80 | Success: 100.0% | Rate: 59.9/min | Remaining: 00:41 | Action: 
  📊 Requests: 100 | Success: 100.0% | Rate: 60.1/min | Remaining: 00:21 | Action: exception
  📊 Requests: 120 | Success: 100.0% | Rate: 60.0/min | Remaining: 00:01 | Action: sleep

  ✓ Load generation completed!
  ℹ Total requests: 120
  ℹ Successful: 120 (100.0%)
  ℹ Errors: 0
  ℹ Actual rate: 60.0 requests/minute
  ℹ Duration: 02:00

> Cleaning up test resources...
  ✓ Removed website: MetricusLoadTest
  ✓ Removed application pool: MetricusLoadTestPool
  ✓ Removed files: C:\inetpub\wwwroot\MetricusLoadTest

============================================================
 Test Summary
============================================================
Test Configuration:
  Site Name: MetricusLoadTest
  Port: 8080
  Load Duration: 2 minutes
  Request Rate: 60 requests/minute

Results:
  Total Test Duration: 02:15
  Base URL: http://localhost:8080
  Cleanup: Completed

✅ Test completed successfully and resources cleaned up!
```

## Troubleshooting

### Common Issues

1. **"Must be run as Administrator"**
   - Right-click PowerShell and "Run as Administrator"

2. **"IIS is not installed"**
   - Install IIS via Windows Features or Server Manager

3. **"Port already in use"**
   - Use a different port: `-Port 8081`
   - Or stop the service using the port

4. **Website not responding**
   - Check Windows Firewall
   - Verify IIS is running: `Get-Service W3SVC`
   - Check application pool status

5. **Metricus not collecting metrics**
   - Verify Metricus service is running
   - Check Metricus configuration
   - Review Metricus logs

### Manual Cleanup

If the script fails and leaves resources:

```powershell
# Remove website and app pool manually
Remove-Website -Name "MetricusLoadTest"
Remove-WebAppPool -Name "MetricusLoadTestPool"

# Remove files
Remove-Item "C:\inetpub\wwwroot\MetricusLoadTest" -Recurse -Force

# Or use the cleanup script
.\Cleanup-LoadTest.ps1
```

## Integration with CI/CD

The scripts support automation:

```powershell
# Automated test run
.\Run-MetricusLoadTest.ps1 -Force -LoadDurationMinutes 1 -RequestsPerMinute 30

# Check exit code
if ($LASTEXITCODE -eq 0) {
    Write-Host "Load test passed"
} else {
    Write-Host "Load test failed"
    exit 1
}
```
