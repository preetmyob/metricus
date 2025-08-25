# Metricus Load Testing Guide

## Overview

This guide explains how to use `Generate-Load.ps1` with the Metricus monitoring dashboard to perform comprehensive load testing.

## Load Testing Dashboard

**Access**: `http://10.0.0.14:9000/d/load-testing-dashboard/metricus-load-testing-dashboard`

### Key Metrics to Monitor

#### 🚀 **Request Rate** 
- **What it shows**: Requests per second being processed
- **Expected during load**: Should increase proportionally with load generation
- **Watch for**: Plateauing indicates server capacity limits

#### ⏱️ **Request Execution Time**
- **What it shows**: How long each request takes to process
- **Expected during load**: Should remain stable initially, then increase under stress
- **Watch for**: Sudden spikes indicate performance degradation

#### 🖥️ **CPU Usage**
- **What it shows**: Server CPU utilization percentage
- **Expected during load**: Gradual increase with request volume
- **Watch for**: >90% indicates CPU bottleneck

#### 💾 **Available Memory**
- **What it shows**: Free memory on the server
- **Expected during load**: Should decrease as load increases
- **Watch for**: Rapid drops indicate memory leaks or excessive allocation

#### 🔄 **Concurrent Requests**
- **What it shows**: Number of requests being processed simultaneously
- **Expected during load**: Should track with incoming request rate
- **Watch for**: Queued requests indicate server overload

#### ❌ **Error Rate**
- **What it shows**: Errors per second
- **Expected during load**: Should remain at zero or very low
- **Watch for**: Any increase indicates application stress

#### 🌐 **Network Traffic**
- **What it shows**: Bytes sent/received per second
- **Expected during load**: Should increase with request volume
- **Watch for**: Network saturation limits

## Load Testing Workflow

### 1. Baseline Measurement
```powershell
# Start with no load - observe baseline metrics
# Access dashboard: http://10.0.0.14:9000/d/load-testing-dashboard/
```

### 2. Light Load Test
```powershell
# Generate light load (10 requests/minute for 5 minutes)
.\Generate-Load.ps1 -DurationMinutes 5 -RequestsPerMinute 10 -BaseUrl "http://localhost:8080"
```

**Expected Results:**
- Request Rate: ~0.17 req/sec
- CPU Usage: Slight increase
- Response Time: Should remain low (<100ms)
- Errors: Zero

### 3. Medium Load Test
```powershell
# Generate medium load (30 requests/minute for 10 minutes)
.\Generate-Load.ps1 -DurationMinutes 10 -RequestsPerMinute 30 -BaseUrl "http://localhost:8080"
```

**Expected Results:**
- Request Rate: ~0.5 req/sec
- CPU Usage: Moderate increase (20-40%)
- Response Time: Still low (<200ms)
- Concurrent Requests: 1-3

### 4. Heavy Load Test
```powershell
# Generate heavy load (120 requests/minute for 15 minutes)
.\Generate-Load.ps1 -DurationMinutes 15 -RequestsPerMinute 120 -BaseUrl "http://localhost:8080"
```

**Expected Results:**
- Request Rate: ~2 req/sec
- CPU Usage: High (60-80%)
- Response Time: May increase (200-500ms)
- Concurrent Requests: 5-10

### 5. Stress Test
```powershell
# Generate stress load (300 requests/minute for 20 minutes)
.\Generate-Load.ps1 -DurationMinutes 20 -RequestsPerMinute 300 -BaseUrl "http://localhost:8080"
```

**Watch For:**
- CPU Usage: >90%
- Response Time: >1000ms
- Error Rate: >0
- Memory: Significant decrease
- Queued Requests: >0

## Performance Counter Mapping

The dashboard shows these Windows Performance Counters:

### Server-Level Metrics
- `advanced.production.server.*.*.processor._total.%_processor_time` → CPU Usage
- `advanced.production.server.*.*.memory._total.available_mbytes` → Available Memory
- `advanced.production.server.*.*.asp_net._total.*` → ASP.NET Global Metrics

### Site-Level Metrics  
- `advanced.production.site.metricustestsite.*.*.asp_net_applications.requests_sec` → Request Rate
- `advanced.production.site.metricustestsite.*.*.asp_net_applications.request_execution_time` → Response Time
- `advanced.production.site.metricustestsite.*.*.asp_net_applications.errors_total_sec` → Error Rate

### Web Service Metrics
- `advanced.production.server.*.*.web_service.metricustestsite.bytes_*_sec` → Network Traffic

## Load Test Actions

The `Generate-Load.ps1` script tests these endpoints:

1. **GET /** - Basic page load
2. **POST /cpu** - CPU intensive operation
3. **POST /memory** - Memory allocation test
4. **POST /io** - I/O intensive operation  
5. **POST /exception** - Error handling test

Each action will show different patterns in the performance counters.

## Troubleshooting

### High CPU, Low Request Rate
- **Cause**: CPU-bound operations (POST /cpu)
- **Solution**: Optimize CPU-intensive code

### High Memory Usage
- **Cause**: Memory leaks or large allocations (POST /memory)
- **Solution**: Check memory management

### High Error Rate
- **Cause**: Application exceptions (POST /exception)
- **Solution**: Review error logs and exception handling

### Queued Requests
- **Cause**: Server overload
- **Solution**: Reduce load or scale server resources

## Best Practices

1. **Start Small**: Begin with light load and gradually increase
2. **Monitor Continuously**: Watch dashboard during entire test
3. **Document Results**: Record metrics at each load level
4. **Test Recovery**: Allow server to recover between tests
5. **Test Different Actions**: Use all POST actions to test different code paths

## Dashboard URLs

- **Load Testing Dashboard**: `http://10.0.0.14:9000/d/load-testing-dashboard/metricus-load-testing-dashboard`

## Files

- `Generate-Load.ps1` - Load generation script
- `send-test-metrics.ps1` - Direct metric injection (for testing dashboard)
- `Setup-TestIIS-WinPS.ps1` - IIS test site setup
