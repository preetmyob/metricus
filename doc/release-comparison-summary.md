# Metricus Production Release Comparison: Chef vs Xwing

## Overview
Comparison between two production Metricus installations captured from live environments:
- **Chef** (older version 0.3.2): Basic installation with minimal dependencies
- **Xwing** (newer version 0.5.0): Enhanced installation with expanded dependency tree

## File Structure Differences

### Version Information
- **Chef**: Version 0.3.2
- **Xwing**: Version 0.5.0

### Root Directory Changes

#### New Files in Xwing
- `metricus.exe.config` - Application configuration file
- `System.Buffers.dll` + `.xml` - Memory management optimizations
- `System.Diagnostics.DiagnosticSource.dll` + `.xml` - Enhanced diagnostics
- `System.Memory.dll` + `.xml` - Memory management APIs
- `System.Numerics.Vectors.dll` + `.xml` - SIMD vector operations
- `System.Runtime.CompilerServices.Unsafe.dll` + `.xml` - Unsafe memory operations
- `Topshelf.NLog.xml` - Documentation (was missing in chef)
- `Topshelf.xml` - Documentation (was missing in chef)

#### Removed Files from Chef
- `Newtonsoft.Json.xml` - Documentation removed from root (still in ConsoleOut plugin)

### Plugin Directory Changes

#### ConsoleOut Plugin
**Chef**: 
- `ConsoleOut.dll`
- `Newtonsoft.Json.dll`
- `Newtonsoft.Json.xml`

**Xwing**:
- `ConsoleOut.dll`
- `Newtonsoft.Json.dll` (xml documentation removed)

#### GraphiteOut Plugin
**Chef**:
- `config.json`
- `Graphite.dll`
- `GraphiteOut.dll`

**Xwing** (significantly expanded):
- `config.json`
- `Graphite.dll`
- `GraphiteOut.dll`
- `GraphiteOut.dll.config` - Plugin-specific configuration
- `ServiceStack.Text.dll` - Local copy for plugin
- Complete System.* dependency set (8 additional DLLs + XML docs)

#### PerfCounter Plugin
**Chef**:
- `config.json`
- `PerformanceCounter.dll`

**Xwing** (significantly expanded):
- `config.json`
- `PerformanceCounter.dll`
- `PerformanceCounter.dll.config` - Plugin-specific configuration
- `ServiceStack.Text.dll` - Local copy for plugin
- Complete System.* dependency set (8 additional DLLs + XML docs)

#### SitesFilter Plugin
**Chef**:
- `config.json`
- `Microsoft.Web.Administration.dll`
- `ServiceStack.Text.dll`
- `ServiceStack.Text.xml`
- `SitesFilter.dll`

**Xwing** (massively expanded):
- `config.json`
- `Microsoft.Web.Administration.dll`
- `SitesFilter.dll`
- `SitesFilter.dll.config` - Plugin-specific configuration
- `ServiceStack.Text.dll` (xml documentation removed)
- **New Windows-specific dependencies**:
  - `Microsoft.Win32.Registry.dll` + `.xml`
  - `System.Diagnostics.EventLog.dll` + `.xml`
  - `System.Reflection.TypeExtensions.dll` + `.xml`
  - `System.Security.AccessControl.dll` + `.xml`
  - `System.Security.Principal.Windows.dll` + `.xml`
  - `System.ServiceProcess.ServiceController.dll` + `.xml`
- Complete System.* dependency set (8 additional DLLs + XML docs)

## Configuration File Differences

### Main config.json

#### Chef (0.3.2)
```json
{
  "Host" : "iis-i-03159e5f47ef85387_stack-740_production-Web-Demo26",
  "Interval" : "10000",
  "ActivePlugins" : ["GraphiteOut", "PerformanceCounter", "SitesFilter"]
}
```

#### Xwing (0.5.0)
```json
{
    "Host":  "unused_graphite_web_udp_hostname",
    "Interval":  "10000",
    "ActivePlugins":  [
                          "PerformanceCounter",
                          "SitesFilter",
                          "GraphiteOut"
                      ]
}
```

**Key Changes**:
- Host changed from specific AWS instance identifier to generic placeholder
- Plugin order changed (PerformanceCounter moved to first)
- JSON formatting improved (indented, structured)

### GraphiteOut Plugin config.json

#### Chef (0.3.2)
```json
{"Hostname":"graphite.edops.myob.com","Port":"2010","Prefix":"natasha.production.stack-servers.740","Protocol":"tcp"}
```

#### Xwing (0.5.0)
```json
{
    "Hostname":  "graphite.edops.myob.com",
    "Port":  "2010",
    "Prefix":  "advanced.production",
    "SendBufferSize":  "5000",
    "Protocol":  "tcp",
    "Servername": "production-hosting-default-web0001.i-0a3ba838fd49c783a",
    "Debug":  true
}
```

**Key Changes**:
- **New fields**: `SendBufferSize`, `Servername`, `Debug`
- Prefix changed from `natasha.production.stack-servers.740` to `advanced.production`
- JSON formatting improved (indented)
- Debug mode enabled

### PerfCounter Plugin config.json

#### Chef (0.3.2)
- Single-line compressed JSON format
- Process instances: `["_Total","chef_runner_service","metricus","nxlog"]`

#### Xwing (0.5.0)
- Multi-line formatted JSON with proper indentation
- Process instances: `["_Total","metricus","nxlog"]` (removed `chef_runner_service`)
- **Identical performance counter categories and metrics**

### SitesFilter Plugin config.json

#### Chef (0.3.2)
```json
{"Categories":{"ASP.NET Applications":{"PreserveOriginal":false,"Filters":["lmw3svc"]},...}}
```

#### Xwing (0.5.0)
```json
{
        "Debug": false,
        "Categories": {...}
}
```

**Key Changes**:
- **New field**: `Debug` configuration option
- JSON formatting improved (indented, structured)
- **Identical category filters and settings**

## Summary of Key Improvements in Xwing (0.5.0)

### Dependency Management
- **Expanded dependency tree**: Each plugin now includes its own copy of required dependencies
- **System.* libraries**: Modern .NET runtime dependencies for better performance
- **Windows-specific libraries**: Enhanced Windows integration capabilities
- **Plugin isolation**: Each plugin has its own .dll.config files

### Configuration Enhancements
- **Debug capabilities**: Debug flags added to GraphiteOut and SitesFilter
- **Buffer management**: SendBufferSize configuration for GraphiteOut
- **Server identification**: Servername field for better tracking
- **Improved formatting**: All JSON configs now properly formatted and readable

### Operational Improvements
- **Better monitoring**: Enhanced diagnostic capabilities
- **Performance optimization**: Memory management and vector operation libraries
- **Environment flexibility**: More generic host configuration
- **Maintainability**: Better structured configuration files

### Version Evolution
The progression from 0.3.2 to 0.5.0 shows significant maturation:
- More robust dependency management
- Enhanced debugging and monitoring capabilities
- Better configuration structure and flexibility
- Improved Windows platform integration
