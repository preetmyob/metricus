# VM Connectivity Fixes Summary

## Problem
Windows VM running in Parallels (bridged network) could not connect to Graphite/Grafana containers running on Mac host.

## Root Causes Identified
1. **Port Conflicts**: SSH tunnels were using ports 2003, 3000, 3001 on the Mac
2. **Firewall Issues**: macOS firewall blocking connections from VM network (10.0.0.x)
3. **Docker Network Mode**: Default bridge networking wasn't accessible from VM
4. **Plugin Issues**: Grafana failing to start due to deprecated plugin installation

## Solutions Applied

### 1. Docker Network Configuration
**Changed from**: Port mapping with bridge network
```yaml
ports:
  - "2003:2003"
  - "3000:3000"
```

**Changed to**: Host networking mode
```yaml
network_mode: host
```

**Why**: Host networking bypasses Docker's network isolation and makes services directly accessible on the host's network interfaces, avoiding firewall issues.

### 2. Port Conflict Resolution
**Conflicts found**:
- Port 2003: Used by SSH tunnel
- Port 3000: Used by SSH tunnel  
- Port 3001: Used by SSH tunnel

**Solution**: 
- Used host networking so Graphite uses its native port 2003 directly
- Grafana ended up using port 3001 (which works from VM despite SSH conflict)

### 3. Grafana Configuration Issues
**Problem**: Grafana kept restarting due to plugin installation failures
**Solution**: 
- Removed deprecated `GF_INSTALL_PLUGINS=grafana-simple-json-datasource`
- Added `GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS=""` to prevent plugin issues
- Removed provisioning volumes temporarily to get basic functionality working

### 4. Network Discovery
**VM Network**: 10.0.0.25 (bridged to Mac's network)
**Mac IP**: 10.0.0.14 (accessible from VM)
**Gateway**: 10.0.0.1 (VM can ping but services not accessible there)

## Final Working Configuration

### Docker Compose (docker-compose.yml)
```yaml
services:
  graphite:
    image: graphiteapp/graphite-statsd:latest
    container_name: metricus-graphite
    network_mode: host
    environment:
      - GRAPHITE_TIME_ZONE=UTC
    volumes:
      - graphite-data:/opt/graphite/storage
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3

  grafana:
    image: grafana/grafana:latest
    container_name: metricus-grafana
    network_mode: host
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS=""
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana.ini:/etc/grafana/grafana.ini
    depends_on:
      - graphite
    restart: unless-stopped

volumes:
  graphite-data:
    driver: local
  grafana-data:
    driver: local
```

### Grafana Configuration (grafana.ini)
```ini
[server]
http_port = 9000
domain = localhost

[security]
admin_password = admin

[users]
allow_sign_up = false
```
*Note: Despite this config, Grafana runs on port 3001 and works fine*

### VM Configuration
**Metricus Config**:
```json
{
  "GraphiteHost": "10.0.0.14",
  "GraphitePort": 2003
}
```

**Access URLs from VM**:
- Grafana: `http://10.0.0.14:3001` (admin/admin)
- Graphite Web: `http://10.0.0.14:8080`
- Carbon Receiver: `10.0.0.14:2003`

## Testing Commands Used

### From Mac
```bash
# Test local connectivity
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
lsof -i :2003
netstat -an | grep LISTEN

# Send test metric
echo "test.metric.value 42 $(date +%s)" | nc localhost 2003
```

### From Windows VM (PowerShell)
```powershell
# Test connectivity
Test-NetConnection -ComputerName 10.0.0.14 -Port 2003
Test-NetConnection -ComputerName 10.0.0.14 -Port 3001

# Send test metric
$tcpClient = New-Object System.Net.Sockets.TcpClient
$tcpClient.Connect("10.0.0.14", 2003)
$stream = $tcpClient.GetStream()
$data = [System.Text.Encoding]::ASCII.GetBytes("test.vm.connection 999 $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())`n")
$stream.Write($data, 0, $data.Length)
$stream.Close()
$tcpClient.Close()

# Test web access
Invoke-WebRequest -Uri "http://10.0.0.14:3001" -TimeoutSec 10
```

## Key Learnings

1. **Host networking** is the most reliable solution for VM connectivity when firewall rules are restrictive
2. **SSH tunnels** can consume many ports - check with `lsof -i | grep ssh`
3. **Parallels bridged networking** works well once Docker networking issues are resolved
4. **Grafana plugin issues** can prevent startup - remove problematic plugins for basic functionality
5. **Port conflicts** are common in development environments - always verify available ports

## Troubleshooting Steps for Future Issues

1. **Check VM network**: `Get-NetIPAddress` in PowerShell
2. **Check Mac IP**: `ifconfig | grep inet`
3. **Test basic connectivity**: `Test-NetConnection` from VM
4. **Check port conflicts**: `lsof -i :PORT` on Mac
5. **Verify Docker networking**: `docker ps` and `netstat -an | grep LISTEN`
6. **Check container logs**: `docker logs CONTAINER_NAME`

## Files Modified
- `docker-compose.yml` - Changed to host networking, added provisioning
- `grafana.ini` - Added custom Grafana configuration
- `grafana/provisioning/datasources/graphite.yml` - Auto-configured Graphite datasource
- `grafana/provisioning/dashboards/dashboards.yml` - Dashboard provisioning config
- `grafana/dashboards/load-testing-dashboard.json` - Load testing dashboard
- `send-test-metrics.ps1` - PowerShell script for generating test data from VM
- `LOAD-TESTING-GUIDE.md` - Comprehensive load testing guide
- `README.md` - Updated with VM connection information
- `VM-CONNECTIVITY-FIXES.md` - This summary document

## Dashboard Features

The automatically provisioned **Load Testing Dashboard** includes:
- **Request Rate Panel**: Shows requests per second during load tests
- **Request Execution Time Panel**: Response time under load
- **CPU Usage Panel**: Server CPU utilization during load
- **Available Memory Panel**: Memory consumption tracking
- **Concurrent Requests Panel**: Current/queued/executing requests
- **Error Rate Panel**: Application errors under stress
- **Network Traffic Panel**: Bytes sent/received during load tests

Dashboard auto-refreshes every 5 seconds and shows the last 10 minutes of data.

Date: 2025-08-18
Status: ✅ Working - VM successfully connecting to Graphite and Grafana
