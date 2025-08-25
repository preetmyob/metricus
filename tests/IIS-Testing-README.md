# IIS Testing Setup for Metricus

This directory contains scripts to create IIS test websites and generate traffic for testing Metricus IIS performance monitoring capabilities.

## Scripts Overview

### 1. Setup-IISTestSites.ps1
Creates multiple IIS test websites with ASP.NET applications.

**Features:**
- Creates 3 test sites by default (MetricusTest1, MetricusTest2, MetricusTest3)
- Each site runs on a different port (8001, 8002, 8003)
- Includes various performance test endpoints:
  - `/` - Home page
  - `/api/fast` - Fast response (< 100ms)
  - `/api/medium` - Medium response (500ms)
  - `/api/slow` - Slow response (2s)
  - `/api/memory` - Memory intensive operations
  - `/api/cpu` - CPU intensive operations

**Usage:**
```powershell
# Run as Administrator
.\Setup-IISTestSites.ps1

# Custom configuration
.\Setup-IISTestSites.ps1 -BasePort 9001 -SiteCount 5 -BasePath "C:\temp\test-sites"
```

### 2. Generate-TestTraffic.ps1
Generates realistic HTTP traffic to the test sites.

**Features:**
- Configurable duration and request rate
- Weighted request patterns (home page gets more traffic)
- Statistics tracking and reporting
- Realistic response time simulation

**Usage:**
```powershell
# Generate traffic for 5 minutes at 60 requests/minute
.\Generate-TestTraffic.ps1

# Custom traffic pattern
.\Generate-TestTraffic.ps1 -DurationMinutes 10 -RequestsPerMinute 120
```

### 3. Cleanup-IISTestSites.ps1
Removes all test sites and cleans up files.

**Usage:**
```powershell
# Interactive cleanup
.\Cleanup-IISTestSites.ps1

# Force cleanup without prompts
.\Cleanup-IISTestSites.ps1 -Force
```

## Complete Testing Workflow

### Step 1: Setup Test Environment
```powershell
# In your Parallels VM, run as Administrator:
cd Z:\code\metricus-refactor\tests
.\Setup-IISTestSites.ps1
```

This creates:
- 3 IIS websites with ASP.NET applications
- Application pools configured for .NET Framework 4.0
- Test pages with various performance characteristics

### Step 2: Generate Traffic
```powershell
# Generate traffic for 5 minutes
.\Generate-TestTraffic.ps1 -DurationMinutes 5 -RequestsPerMinute 60
```

This will:
- Make requests to all test sites
- Use realistic traffic patterns
- Create CPU, memory, and I/O load
- Generate IIS performance counter activity

### Step 3: Run Metricus with SitesFilter
Update your Metricus configuration to include the SitesFilter plugin:

```json
{
  "Host": "test-machine",
  "Interval": "5000",
  "ActivePlugins": [
    "PerformanceCounter",
    "SitesFilter",
    "GraphiteOut",
    "ConsoleOut"
  ]
}
```

Then run Metricus to capture the IIS metrics.

### Step 4: Monitor Results
Check Graphite at `http://10.0.0.14:8080` for new metrics under:
- `advanced.development.unused_graphite_web_udp_hostname.web_service.*`
- IIS-specific performance counters
- Site-specific metrics from SitesFilter

### Step 5: Cleanup
```powershell
.\Cleanup-IISTestSites.ps1
```

## Expected Metrics

After running this test, you should see additional metrics in Graphite:

**IIS Web Service Counters:**
- Requests per second
- Current connections
- Bytes sent/received per second
- Request execution time
- Requests queued

**Site-Specific Metrics (via SitesFilter):**
- Per-site request rates
- Response times by site
- Error rates by site
- Bandwidth usage by site

**System Impact:**
- Increased CPU usage during traffic generation
- Memory allocation from ASP.NET applications
- Network I/O from HTTP requests
- Disk I/O from IIS logging

## Troubleshooting

**Permission Issues:**
- Ensure PowerShell is running as Administrator
- Check that IIS is installed and enabled

**Port Conflicts:**
- Modify `-BasePort` parameter if default ports are in use
- Check `netstat -an` for port availability

**ASP.NET Issues:**
- Ensure .NET Framework 4.0+ is installed
- Check IIS application pool settings

**Traffic Generation Issues:**
- Verify sites are running: `Get-Website`
- Check site accessibility in browser first
- Monitor Windows Event Log for errors

## Files Created

- `test-sites.json` - Site configuration for traffic generation
- `traffic-stats.json` - Detailed traffic statistics
- `C:\inetpub\metricus-test\` - Physical site files

All files are automatically cleaned up by the cleanup script.
