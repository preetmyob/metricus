# Metricus Testing Environment

## Local Graphite + Grafana Testing

This directory contains Docker Compose configuration for running a local Graphite instance with Grafana dashboard for testing Metricus.

**✅ VM Connectivity Configured**: This setup works with Windows VMs running in Parallels (bridged network mode).

### Starting the Test Environment

```bash
cd tests
docker-compose up -d
```

### Accessing Services

**From Mac (localhost):**
- **Grafana Dashboard**: http://localhost:9000 (admin/admin)
- **Graphite Web Interface**: http://localhost:8080
- **Carbon Receiver (plaintext)**: localhost:2003
- **StatsD UDP**: localhost:8125

**From Windows VM (Parallels - Bridged Network):**
- **Grafana Dashboard**: http://10.0.0.14:9000 (admin/admin) ✅
- **Graphite Web Interface**: http://10.0.0.14:8080 ✅
- **Carbon Receiver (plaintext)**: 10.0.0.14:2003 ✅
- **StatsD UDP**: 10.0.0.14:8125

### Metricus Configuration for VM

Update your Metricus configuration to use:
```json
{
  "GraphiteHost": "10.0.0.14",
  "GraphitePort": 2003
}
```

### Network Configuration Notes

- **Docker Network Mode**: Uses `host` networking to bypass firewall issues
- **VM Network**: Assumes VM has IP in 10.0.0.x range (bridged mode)
- **Mac IP**: 10.0.0.14 (accessible from VM)
- **Port Conflicts**: SSH tunnels may use ports 2003, 3000, 3001 - host networking resolves this

### Testing VM Connectivity

From Windows VM (PowerShell):
```powershell
# Test Graphite connection
Test-NetConnection -ComputerName 10.0.0.14 -Port 2003

# Test Grafana web access
Invoke-WebRequest -Uri "http://10.0.0.14:3001" -TimeoutSec 10

# Send test metric
$tcpClient = New-Object System.Net.Sockets.TcpClient
$tcpClient.Connect("10.0.0.14", 2003)
$stream = $tcpClient.GetStream()
$data = [System.Text.Encoding]::ASCII.GetBytes("test.vm.metric 123 $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())`n")
$stream.Write($data, 0, $data.Length)
$stream.Close()
$tcpClient.Close()
```

### Grafana Dashboard Setup

1. Access Grafana at http://10.0.0.14:9000 (from VM) or http://localhost:9000 (from Mac)
2. Login with admin/admin
3. The **Metricus Load Testing Dashboard** is automatically provisioned and includes:
   - **Request Rate**: Requests per second being processed
   - **Request Execution Time**: Response time under load
   - **CPU Usage**: Server CPU utilization during load
   - **Concurrent Requests**: Number of simultaneous requests
   - **Error Rate**: Application errors under stress
   - **Network Traffic**: Bytes sent/received during load tests

4. **Graphite datasource** is automatically configured and connected

**Dashboard Link:**
- **Load Testing Dashboard**: http://10.0.0.14:9000/d/load-testing-dashboard/metricus-load-testing-dashboard

### Load Testing with Generate-Load.ps1

The **Load Testing Dashboard** is specifically designed to show metrics that change when using `Generate-Load.ps1`:

**Key Metrics Monitored:**
- **Request Rate**: Requests per second being processed
- **Request Execution Time**: Response time under load
- **CPU Usage**: Server CPU utilization during load
- **Concurrent Requests**: Number of simultaneous requests
- **Error Rate**: Application errors under stress
- **Network Traffic**: Bytes sent/received during load tests

**Usage:**
```powershell
# Light load test
.\Generate-Load.ps1 -DurationMinutes 5 -RequestsPerMinute 30 -BaseUrl "http://localhost:8080"

# Heavy load test  
.\Generate-Load.ps1 -DurationMinutes 15 -RequestsPerMinute 120 -BaseUrl "http://localhost:8080"
```

See `LOAD-TESTING-GUIDE.md` for detailed load testing procedures and expected results.

### Testing the Dashboard

From your Windows VM, you can generate test data using the provided PowerShell script:

```powershell
# Copy the script from the tests directory to your VM
# Then run:
.\send-test-metrics.ps1

# Or with custom parameters:
.\send-test-metrics.ps1 -GraphiteHost "10.0.0.14" -GraphitePort 2003 -IntervalSeconds 5
```

This will generate realistic CPU, memory, response time, and network metrics that will appear in the dashboard in real-time.

### Stopping the Test Environment

```bash
docker-compose down
```

### Cleaning Up Data

To remove all stored metrics and dashboard data:

```bash
docker-compose down -v
```

### Troubleshooting

See `VM-CONNECTIVITY-FIXES.md` for detailed troubleshooting steps and the complete history of changes made to enable VM connectivity.

**Common Issues:**
- **VM can't connect**: Check VM IP with `Get-NetIPAddress` and ensure it's in 10.0.0.x range
- **Port conflicts**: Check `lsof -i :PORT` on Mac for SSH tunnel conflicts
- **Container issues**: Check logs with `docker logs metricus-graphite` or `docker logs metricus-grafana`

### Configuration Files

- `docker-compose.yml`: Main service configuration with host networking
- `grafana.ini`: Custom Grafana configuration
- `VM-CONNECTIVITY-FIXES.md`: Complete troubleshooting and fix history
