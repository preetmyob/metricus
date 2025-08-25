# Metricus Setup Notes

## Environment Configuration
- **Current Setup**: Development environment with Test configuration active
- **Graphite Server**: 10.0.0.14:8080 (web) / 10.0.0.14:2003 (carbon)
- **Metric Paths**: 
  - Test: `advanced.development.preet.i-9999999.*` (121 metrics)
  - Minimal: `minimal.test.minimal.test.*` (3 metrics)

## Key Commands Used
```bash
# Clear Graphite metrics
docker exec metricus-graphite find /opt/graphite/storage -name "*.wsp" -delete
docker restart metricus-graphite

# Apply configurations
pwsh scripts/Update-Configs.ps1 -Configuration Debug -Environment Test

# Check metrics
curl "http://10.0.0.14:8080/metrics/find?query=advanced.development.**&format=json"
```

## Configuration Issues Resolved
- **Production 0.5.0**: Fixed malformed prefix `advanced.env>` → `advanced.production`
- **Metric Path Duplication**: Understanding `{Prefix}.{Servername}.{metric_path}` structure
- **PowerShell Path Issues**: Network mount vs local execution differences

## Environment Overrides
- Development: advanced.development prefix
- Test: advanced.development prefix  
- MinTest: minimal.test prefix (3 counters only)
- Prod: advanced.production prefix

## Workflow Streamlined
- Removed bash scripts for Windows-only development
- PowerShell-based configuration management
- Docker-based Graphite metrics storage
