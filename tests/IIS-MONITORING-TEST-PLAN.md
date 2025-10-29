# IIS Monitoring Configuration Testing Plan

This document describes how to test the new IIS monitoring configuration added in the `feature/iis-monitoring-config` branch.

## Changes Overview

### PerfCounter Plugin Configuration
Added comprehensive IIS performance counter monitoring covering all layers:

**Kernel Layer (HTTP.sys)**
- HTTP Service Request Queues: RejectedRequests, ArrivalRate, CurrentQueueSize

**IIS Worker Layer**
- W3SVC_W3WP: Active Requests, Requests/Sec, Active/Total Threads

**Application Runtime Layer**
- ASP.NET: Application Restarts, Requests Rejected/Queued/Current
- ASP.NET Applications: Requests Executing, Queue, Rate, Timeouts, Execution Time, Failures

**CLR Runtime Layer**
- .NET CLR Memory (w3wp): GC collections, heap sizes, allocation rates
- .NET CLR Exceptions (w3wp): Exception throw rates and handling
- .NET CLR LocksAndThreads (w3wp): Thread contention and counts

**Process Layer**
- Process (w3wp): CPU, memory, I/O, threads, handles for IIS worker processes

### SitesFilter Plugin Configuration
Added filter mappings for all IIS categories to transform instance names to AppPool names:
- ASP.NET Applications → Site Name (= AppPool in this environment)
- .NET CLR Memory/Exceptions/LocksAndThreads → AppPool Name (via PID join)
- Process → AppPool Name (via PID join)
- W3SVC_W3WP → AppPool Name (via regex extraction)

## Testing Prerequisites

### Windows VM Requirements
- Windows Server with IIS installed
- .NET Framework 4.8 installed
- Administrator privileges
- Parallels VM with bridged network (or any Windows environment with IIS)

### Mac/Linux Requirements (for Graphite/Grafana)
- Docker and Docker Compose installed
- Network connectivity to Windows VM

## Testing Procedure

### Phase 1: Build and Deploy Metricus

#### 1.1 Build the Solution (on Windows VM)

```powershell
# Navigate to the project directory
cd C:\code\metricus

# Switch to the test branch
git checkout feature/iis-monitoring-config

# Restore NuGet packages
nuget restore metricus.sln

# Build in Debug mode for testing
msbuild metricus.sln /p:Configuration=Debug

# Or build in Release mode
msbuild metricus.sln /p:Configuration=Release
```

#### 1.2 Verify Plugin Configuration Files

Confirm the updated config files are in place:

```powershell
# Check PerfCounter config
Get-Content .\metricus\bin\Debug\Plugins\PerfCounter\config.json

# Check SitesFilter config
Get-Content .\metricus\bin\Debug\Plugins\SitesFilter\config.json
```

Expected: PerfCounter config should include IIS counters, SitesFilter should include all category mappings.

#### 1.3 Update Main Metricus Config

Edit `metricus\bin\Debug\config.json` to enable SitesFilter:

```json
{
  "Host": "10.0.0.14",
  "Interval": "10000",
  "ActivePlugins": [
    "PerformanceCounter",
    "SitesFilter",
    "GraphiteOut",
    "ConsoleOut"
  ]
}
```

Update GraphiteOut plugin config (`Plugins\GraphiteOut\config.json`):

```json
{
  "Hostname": "10.0.0.14",
  "Port": 2003,
  "Protocol": "tcp",
  "Debug": false,
  "Servername": "test-machine"
}
```

### Phase 2: Setup Test Environment

#### 2.1 Start Graphite/Grafana (on Mac)

```bash
cd tests
docker-compose up -d

# Verify services are running
docker ps

# Check logs if needed
docker logs metricus-graphite
docker logs metricus-grafana
```

Access points:
- Graphite: http://localhost:8080 (or http://10.0.0.14:8080 from VM)
- Grafana: http://localhost:9000 (or http://10.0.0.14:9000 from VM)

#### 2.2 Create IIS Test Sites (on Windows VM)

```powershell
# Navigate to tests directory
cd C:\code\metricus\tests

# Run setup script as Administrator
.\Setup-IISTestSites.ps1

# Verify sites were created
Get-Website | Where-Object { $_.Name -like "MetricusTest*" }

# Verify application pools
Get-IISAppPool | Where-Object { $_.Name -like "MetricusTest*" }

# Test sites are accessible
Invoke-WebRequest -Uri "http://localhost:8001" -UseBasicParsing
Invoke-WebRequest -Uri "http://localhost:8002" -UseBasicParsing
Invoke-WebRequest -Uri "http://localhost:8003" -UseBasicParsing
```

Expected: 3 test sites (MetricusTest1, MetricusTest2, MetricusTest3) running on ports 8001-8003.

### Phase 3: Baseline Testing (Without Load)

#### 3.1 Run Metricus in Console Mode

```powershell
# Navigate to build output
cd C:\code\metricus\metricus\bin\Debug

# Run Metricus in console mode
.\metricus.exe

# Watch for console output showing:
# - "Loading config from..." messages from plugins
# - "Registering instance..." messages for IIS counters
# - "Collected X metrics" after each collection cycle
# - Metric output from ConsoleOut plugin (if enabled)
```

#### 3.2 Verify Counter Registration

Look for console output like:
```
Registering instance: HTTP Service Request Queues - RejectedRequests - ...
Registering instance: W3SVC_W3WP - Active Requests - ...
Registering regex instance: .NET CLR Memory - # Gen 0 Collections - w3wp
Registering regex instance: Process - % Processor Time - w3wp
```

Expected counters:
- HTTP Service Request Queues instances (one per site)
- W3SVC_W3WP instances (one per app pool)
- ASP.NET Applications instances (one per site: `_LM_W3SVC_<ID>_ROOT`)
- .NET CLR Memory instances for w3wp processes
- Process instances for w3wp processes

#### 3.3 Verify SitesFilter Transformations

If Debug is enabled in SitesFilter config, you should see transformation messages like:
```
ASP.NET Applications: _LM_W3SVC_1_ROOT -> MetricusTest1
Process: w3wp -> MetricusTest1
.NET CLR Memory: w3wp#1 -> MetricusTest2
W3SVC_W3WP: 1_MetricusTest1 -> MetricusTest1
```

#### 3.4 Check Graphite for Baseline Metrics

Access Graphite web interface: http://10.0.0.14:8080

Navigate to the metrics tree and look for:
```
stats
└── test-machine
    ├── HTTP Service Request Queues
    │   ├── <queue-instance>
    │   │   ├── ArrivalRate
    │   │   ├── CurrentQueueSize
    │   │   └── RejectedRequests
    ├── W3SVC_W3WP
    │   ├── MetricusTest1
    │   │   ├── Active Requests
    │   │   ├── Requests / Sec
    │   │   ├── Active Threads Count
    │   │   └── Total Threads
    │   ├── MetricusTest2
    │   └── MetricusTest3
    ├── ASP.NET
    │   ├── Application Restarts
    │   ├── Requests Rejected
    │   ├── Requests Queued
    │   └── Requests Current
    ├── ASP.NET Applications
    │   ├── MetricusTest1
    │   │   ├── Requests Executing
    │   │   ├── Requests In Application Queue
    │   │   ├── Requests/Sec
    │   │   └── ...
    ├── .NET CLR Memory
    │   ├── MetricusTest1
    │   ├── MetricusTest2
    │   └── MetricusTest3
    ├── Process
    │   ├── MetricusTest1
    │   │   ├── % Processor Time
    │   │   ├── Private Bytes
    │   │   └── ...
    └── Processor
        └── _total
            └── % Processor Time
```

**Key Verification Points:**
- ✅ Instance names are transformed to AppPool/Site names (not `w3wp#1`, `_LM_W3SVC_1_ROOT`)
- ✅ All three test sites appear in metrics
- ✅ HTTP Service Request Queues counters are present
- ✅ W3SVC_W3WP counters show per-AppPool data
- ✅ ASP.NET and ASP.NET Applications counters are captured

### Phase 4: Load Testing

#### 4.1 Generate Test Traffic

```powershell
# In a separate PowerShell window on the VM
cd C:\code\metricus\tests

# Generate moderate traffic for 10 minutes
.\Generate-TestTraffic.ps1 -DurationMinutes 10 -RequestsPerMinute 60

# Or for heavier load testing:
.\Generate-TestTraffic.ps1 -DurationMinutes 15 -RequestsPerMinute 120
```

#### 4.2 Monitor Real-Time Metrics

While traffic is being generated, watch Metricus console output for increasing values in:
- **Active Requests**: Should increase during load
- **Requests/Sec**: Should reflect the traffic rate
- **CPU %**: Should increase with load
- **Request Execution Time**: May increase under load
- **Active Threads Count**: Should adjust to handle load

#### 4.3 Verify Metric Changes in Graphite

Access Graphite and create graphs for:

**Request Rate:**
```
stats.test-machine.W3SVC_W3WP.MetricusTest*.Requests_/_Sec
```

**Active Requests:**
```
stats.test-machine.W3SVC_W3WP.MetricusTest*.Active_Requests
```

**Response Time:**
```
stats.test-machine.ASP_NET_Applications.MetricusTest*.Request_Execution_Time
```

**CPU Usage:**
```
stats.test-machine.Process.MetricusTest*.%_Processor_Time
```

**Memory Usage:**
```
stats.test-machine.Process.MetricusTest*.Private_Bytes
```

**Expected behavior:**
- Requests/Sec should show traffic pattern (60 or 120 req/min)
- Active Requests should spike during load
- CPU % should increase during CPU-intensive requests
- Memory should increase during memory-intensive requests
- Request Execution Time should vary based on endpoint called

### Phase 5: Validation Tests

#### 5.1 Test Counter Name Accuracy

Verify specific counter names match Windows Performance Monitor:

```powershell
# Open Performance Monitor
perfmon

# Add counters manually:
# - HTTP Service Request Queues\ArrivalRate
# - W3SVC_W3WP(*)\Active Requests
# - ASP.NET Applications(*)\Requests/Sec
# - .NET CLR Memory(w3wp*)\# Gen 0 Collections
# - Process(w3wp*)\% Processor Time

# Compare values to those in Graphite
```

Counter names should match exactly between Metricus and perfmon.

#### 5.2 Test Dynamic Instance Detection

Test that new IIS sites are automatically detected:

```powershell
# Create a new test site
New-Website -Name "DynamicTest" -Port 8010 -PhysicalPath "C:\inetpub\wwwroot"
Start-Website -Name "DynamicTest"

# Wait for next Metricus collection cycle (10 seconds by default)
# Check Metricus console output for new "Registering instance" messages
# Check Graphite for new "DynamicTest" metrics

# Cleanup
Stop-Website -Name "DynamicTest"
Remove-Website -Name "DynamicTest"
```

Expected: New site should appear in metrics within 1-2 collection cycles.

#### 5.3 Test Filter Preservation

Verify PreserveOriginal setting works by temporarily enabling it:

Edit `Plugins\SitesFilter\config.json`:
```json
{
  "Categories": {
    "Process": {
      "Filters": ["w3wp.process"],
      "PreserveOriginal": true
    }
  }
}
```

Restart Metricus and check Graphite for:
- Both `w3wp` and `MetricusTest1` instances in Process counters

Change back to `false` to keep metrics clean.

#### 5.4 Test Error Handling

Test resilience when sites are stopped:

```powershell
# Stop one test site
Stop-Website -Name "MetricusTest2"

# Check Metricus console for:
# - No error messages or exceptions
# - Metrics continue for MetricusTest1 and MetricusTest3
# - MetricusTest2 metrics disappear gracefully

# Restart the site
Start-Website -Name "MetricusTest2"

# Verify MetricusTest2 metrics reappear
```

### Phase 6: Performance Validation

#### 6.1 Measure Collection Performance

```powershell
# In Metricus console output, look for:
"Collected X metrics"

# Typical ranges with IIS monitoring:
# - No load: 80-150 metrics per cycle
# - With 3 test sites: 150-250 metrics per cycle
# - Collection time should be < 1 second
```

#### 6.2 Check Memory Usage

```powershell
# While Metricus is running
Get-Process metricus | Select-Object WS, PM, CPU

# Working Set (WS) should be stable < 200MB
# Private Memory (PM) should not grow continuously
# Monitor for 30+ minutes to check for memory leaks
```

#### 6.3 Verify No Counter Leaks

```powershell
# Check for "does not exist in the specified Category" messages
# These indicate stale counter references

# Should only appear when:
# - Sites are stopped/removed
# - App pools are recycled
# And should be followed by counter cleanup
```

## Success Criteria

### ✅ Core Functionality
- [ ] Metricus builds without errors
- [ ] All IIS performance counters are registered successfully
- [ ] Metrics are collected every 10 seconds (default interval)
- [ ] ConsoleOut shows metric output if enabled
- [ ] Metrics appear in Graphite within 30 seconds

### ✅ Counter Coverage
- [ ] HTTP Service Request Queues counters present
- [ ] W3SVC_W3WP counters show per-AppPool data
- [ ] ASP.NET global counters captured
- [ ] ASP.NET Applications per-site counters captured
- [ ] .NET CLR Memory counters for w3wp processes
- [ ] .NET CLR Exceptions counters for w3wp processes
- [ ] .NET CLR LocksAndThreads counters for w3wp processes
- [ ] Process counters for w3wp processes

### ✅ Instance Transformation
- [ ] ASP.NET Applications instances show Site names (not `_LM_W3SVC_*`)
- [ ] .NET CLR counters show AppPool names (not `w3wp#1`)
- [ ] Process counters show AppPool names (not `w3wp`)
- [ ] W3SVC_W3WP instances show AppPool names (not `<ID>_<AppPool>`)

### ✅ Dynamic Behavior
- [ ] New IIS sites are detected automatically
- [ ] Stopped sites disappear from metrics cleanly
- [ ] App pool recycling is handled gracefully
- [ ] No memory leaks during extended operation (1+ hours)

### ✅ Load Testing
- [ ] Metrics change appropriately under load
- [ ] Request rate metrics reflect actual traffic
- [ ] CPU metrics increase during CPU-intensive requests
- [ ] Memory metrics increase during memory-intensive requests
- [ ] Response time metrics vary based on endpoint

### ✅ Error Handling
- [ ] No exceptions when sites are stopped
- [ ] No exceptions when app pools are recycled
- [ ] Stale counters are detected and removed
- [ ] Missing counters don't crash Metricus

## Troubleshooting

### Issue: No IIS metrics appear

**Check:**
1. IIS is installed and running: `Get-Service W3SVC`
2. At least one website is running: `Get-Website | Where-Object {$_.State -eq 'Started'}`
3. Performance counter config includes IIS categories
4. Metricus has permissions to read performance counters (run as admin for testing)

### Issue: Instance names not transformed

**Check:**
1. SitesFilter plugin is enabled in main config.json
2. SitesFilter config includes the category being monitored
3. Console output shows SitesFilter loading and registering
4. Filter names match exactly (case-sensitive)

### Issue: w3wp instances not detected

**Check:**
1. IIS application pools are started: `Get-IISAppPool`
2. Worker processes are running: `Get-Process w3wp`
3. instance_regex is set to `^w3wp` in PerfCounter config
4. dynamic is set to `true` for CLR and Process categories

### Issue: Metrics not appearing in Graphite

**Check:**
1. GraphiteOut plugin is enabled
2. Graphite hostname/port are correct in config
3. Network connectivity: `Test-NetConnection -ComputerName 10.0.0.14 -Port 2003`
4. Graphite is receiving data: Check logs with `docker logs metricus-graphite`
5. ConsoleOut enabled to verify metrics are being collected

### Issue: High memory usage

**Check:**
1. PreserveOriginal is set to `false` in SitesFilter to avoid duplicate metrics
2. No stale counter leak messages in console
3. dynamic_interval is set appropriately (default 30000ms)
4. Not collecting too many instances (filter with instance_regex)

## Cleanup

After testing is complete:

```powershell
# Stop Metricus (Ctrl+C in console)

# Cleanup IIS test sites
cd C:\code\metricus\tests
.\Cleanup-IISTestSites.ps1 -Force

# Verify cleanup
Get-Website | Where-Object { $_.Name -like "MetricusTest*" }
```

On Mac, stop Graphite/Grafana:

```bash
cd tests
docker-compose down

# Optional: Remove all data
docker-compose down -v
```

## Next Steps

If all tests pass:
1. Commit the changes
2. Push the branch: `git push origin feature/iis-monitoring-config`
3. Create a pull request to merge into master
4. Deploy to production environment
5. Monitor production metrics in Grafana

## Notes

- Collection interval is configurable in main config.json (default: 10000ms = 10 seconds)
- dynamic_interval for counter refresh is configurable per category (default: 30000ms)
- Debug mode can be enabled in SitesFilter config for detailed transformation logging
- PreserveOriginal = true will create duplicate metrics (original + transformed)
- Counter names with special characters (/, %, #) are escaped in Graphite metric paths
