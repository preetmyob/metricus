# Grafana Dashboard Access

## Current Status ✅
- **Containers**: Running and healthy
- **Data Flow**: Confirmed working (test metrics sent successfully)
- **Dashboard**: Updated with correct datasource configuration

## Access Information
- **Grafana URL**: http://localhost:3000
- **Login**: admin / admin
- **Dashboard**: "Metricus - Test Dashboard" in the Metricus folder

## Dashboard Panels
1. **Test Metrics Table** (Last 10 min) - Shows recent test data
2. **Test Metric Graph** (Last 10 min) - Live test metric visualization  
3. **Historical Metricus Data** (Last 7 days) - Shows CPU, Memory, Site metrics from previous runs
4. **CPU Usage Over Time** - Historical CPU performance graph

## Data Sources
- **Fresh Data**: Test metrics being sent every few seconds
- **Historical Data**: Metricus data from August 17th (yesterday)
- **Live Updates**: Dashboard refreshes every 5 seconds

## To Send Fresh Metricus Data
Run Metricus with local environment config pointing to `localhost:2003`

## Test Data Sent
- `test.cpu.usage`: Random values 40-60
- `test.memory.usage`: Random values 60-90  
- `test.metric.value`: Static value 42

Last updated: $(date)
