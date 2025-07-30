# Metricus

A .NET metrics collection service inspired by collectd but far less sophisticated. Metricus provides a flexible, plugin-based architecture for collecting performance metrics from various sources and forwarding them to different monitoring systems.

## Overview

Metricus is designed as a lightweight metrics collection service that runs as a Windows service using TopShelf. It follows a simple pipeline architecture where data flows through Input → Filter → Output plugins, allowing for flexible metric collection, processing, and forwarding.

## Key Features

* **JSON Configuration**: Simple JSON-based configuration for all components
* **Plugin Architecture**: Extensible Input/Filter/Output plugin system
* **ZeroFactories™**: Clean, readable code without factory pattern complexity
* **TopShelf Integration**: Runs as a Windows service with easy installation
* **Ephemeral Instance Support**: Automatic handling of performance counter instances
* **Real-time Processing**: Configurable collection intervals for near real-time metrics

## Architecture

The system uses a pipeline-based architecture:

```
[Input Plugins] → [Filter Plugins] → [Output Plugins]
```

- **Input Plugins**: Collect metrics from various sources (Performance Counters, etc.)
- **Filter Plugins**: Process, transform, or filter collected metrics
- **Output Plugins**: Forward processed metrics to monitoring systems

## Project Structure

### Core Service
- **📁 metricus**: Main service application that orchestrates the entire pipeline
  - Implements TopShelf service hosting
  - Manages plugin lifecycle and execution intervals
  - Coordinates data flow between plugins
  - Configuration: `config.json` with host, interval, and active plugin settings

### Plugin Framework
- **📁 PluginInterface**: Core interfaces and base classes for plugin development
  - **IInputPlugin**: Interface for metric collection plugins
    - `List<metric> Work()`: Main method to collect and return metrics
    - Called on each collection interval by the service
  - **IOutputPlugin**: Interface for metric output plugins
    - `void Work(List<metric> metrics)`: Processes collected metrics for output
    - Receives filtered metrics from the pipeline
  - **IFilterPlugin**: Interface for metric processing plugins
    - `List<metric> Work(List<metric> metrics)`: Transforms/filters metric collections
    - Enables metric enrichment and filtering between input and output
  - **metric**: Core data structure containing:
    - `string site`: Site/environment identifier
    - `string category`: Performance counter category
    - `string type`: Specific metric type/counter name
    - `string instance`: Instance identifier (process, disk, etc.)
    - `double value`: Numeric metric value
    - `DateTime timestamp`: When the metric was collected
  - **PluginManager**: Base plugin management functionality
    - Configuration loading and management
    - Plugin lifecycle coordination
    - Logging and error handling infrastructure
  - **Plugin Base Classes**:
    - `InputPlugin`: Base implementation for input plugins
    - `OutputPlugin`: Base implementation for output plugins  
    - `FilterPlugin`: Base implementation for filter plugins### Input Plugins
- **📁 PerformanceCounter**: Windows Performance Counter input plugin
  - **Purpose**: Collects system performance metrics from Windows Performance Counters
  - **Metrics Collected**: CPU usage, Memory utilization, Network traffic, Disk I/O, Process statistics
  - **Supported Categories**: 
    - Processor (% Processor Time, % User Time, % Privileged Time)
    - Memory (Available MBytes, Pages/sec, Pool Paged Bytes)
    - Network Interface (Bytes Total/sec, Packets/sec, Output Queue Length)
    - PhysicalDisk (Disk Read/Write Bytes/sec, % Disk Time, Avg. Disk Queue Length)
    - Process (Working Set, % Processor Time, Thread Count)
    - TCPv4/TCPv6 (Connections Established, Segments/sec)
  - **Instance Support**: Handles both static instances (_Total) and dynamic instances (per-process, per-disk)
  - **Ephemeral Instances**: Automatically manages performance counters for processes that start/stop
  - **Configuration**: JSON mapping of categories, counters, and instances to collect

### Filter Plugins  
- **📁 SitesFilter**: Site-based metric filtering and categorization plugin
  - **Purpose**: Filters and categorizes metrics based on site rules and patterns
  - **Functionality**:
    - Include/exclude patterns for metric filtering
    - Site-based metric categorization
    - Metric transformation and enrichment
    - Rule-based processing logic
  - **Use Cases**: 
    - Filter metrics by application or service
    - Add site/environment tags to metrics
    - Exclude noisy or irrelevant metrics
    - Transform metric names and values
  - **Configuration**: Rule-based filtering criteria with regex support### Output Plugins
- **📁 ConsoleOut**: Console output plugin for debugging and testing
  - **Purpose**: Outputs formatted JSON metrics to console for development and troubleshooting
  - **Output Format**: Pretty-printed JSON with indentation for readability
  - **Use Cases**: 
    - Development and debugging
    - Testing metric collection pipelines
    - Troubleshooting metric formatting issues
    - Validating metric data before production deployment
  - **Features**: 
    - Real-time metric display
    - JSON formatting with indentation
    - No external dependencies
  - **Configuration**: No additional configuration required

- **📁 GraphiteOut**: Graphite metrics output plugin
  - **Purpose**: Forwards metrics to Graphite monitoring systems for visualization and alerting
  - **Supported Protocols**: TCP and UDP transport protocols
  - **Metric Format**: Standard Graphite plaintext protocol (`<metric.path> <value> <timestamp>`)
  - **Features**:
    - Configurable connection settings (hostname, port, protocol)
    - Custom metric prefixes for namespace organization
    - Batched sending with configurable buffer sizes (default: 1000 metrics)
    - Background processing with separate worker thread
    - TCP connection pooling and management
    - Error handling and connection retry logic
  - **Performance**: 
    - Asynchronous metric delivery
    - Buffered batching reduces network overhead
    - Configurable send buffer size (default: 2000 metrics)
  - **Configuration Options**:
    - `Hostname`: Graphite server address
    - `Port`: Graphite plaintext port (typically 2003)
    - `Protocol`: "tcp" or "udp"
    - `Prefix`: Metric namespace prefix
    - `SendBufferSize`: Batching buffer size
    - `Debug`: Enable debug logging

- **📁 SumoOut**: Sumo Logic cloud output plugin
  - **Purpose**: Sends metrics to Sumo Logic cloud monitoring platform for analysis and alerting
  - **Architecture**: Inherits from GraphiteOut for buffering and processing infrastructure
  - **Transport**: HTTP/HTTPS POST to Sumo Logic HTTP collector endpoints
  - **Metric Format**: Converts metrics to Graphite format before HTTP transmission
  - **Data Flow**:
    1. Receives metrics from Metricus pipeline
    2. Buffers metrics using inherited GraphiteOut infrastructure
    3. Formats metrics as Graphite plaintext: `<site>.<category>.<type>.<instance> <value> <timestamp>`
    4. Sends via HTTP POST to Sumo Logic collector endpoint
  - **Features**:
    - Asynchronous HTTP delivery
    - Metric path construction with site categorization
    - Unix timestamp conversion
    - Space-to-underscore normalization in metric names
    - Error handling and logging for HTTP failures
  - **Regional Support**: Currently configured for Australia region (collectors.au.sumologic.com)
  - **Use Cases**:
    - Cloud-based metric storage and analysis
    - Integration with Sumo Logic dashboards and alerts
    - Centralized monitoring across multiple servers
    - Long-term metric retention and historical analysis
  - **Configuration**: Inherits GraphiteOut configuration (SendBufferSize, Debug flags)
  - **Limitations**: 
    - Hard-coded collector endpoint (should be configurable)
    - Collector token embedded in code (security concern)
    - Basic error handling without retry logic

## Configuration

### Service Configuration (`metricus/config.json`)
```json
{
  "Host": "your-hostname",
  "Interval": "10000",
  "ActivePlugins": [
    "PerformanceCounter",
    "SitesFilter", 
    "GraphiteOut",
    "ConsoleOut"
  ]
}
```

- **Host**: Identifier for the metrics source
- **Interval**: Collection interval in milliseconds (10000 = 10 seconds)
- **ActivePlugins**: List of plugins to load and execute (prefix with # to disable)

### Plugin Configurations
Each plugin has its own `config.json` file in its directory:

#### PerformanceCounter Configuration
```json
{
  "categories": [
    {
      "name": "Processor",
      "counters": [
        "% Processor Time",
        "% User Time", 
        "% Privileged Time"
      ],
      "instances": ["_Total"]
    },
    {
      "name": "Memory",
      "counters": [
        "Available MBytes",
        "Pages/sec",
        "Pool Paged Bytes",
        "Pool Nonpaged Bytes"
      ]
    },
    {
      "name": "Network Interface",
      "counters": [
        "Bytes Total/sec",
        "Packets/sec",
        "Output Queue Length"
      ],
      "instances": ["*"]
    },
    {
      "name": "PhysicalDisk",
      "counters": [
        "Disk Read Bytes/sec",
        "Disk Write Bytes/sec",
        "% Disk Time",
        "Avg. Disk Queue Length"
      ],
      "instances": ["_Total"]
    },
    {
      "name": "TCPv4",
      "counters": [
        "Connections Established",
        "Segments/sec",
        "Segments Received/sec",
        "Segments Sent/sec",
        "Segments Retransmitted/sec"
      ]
    }
  ]
}
```

#### GraphiteOut Configuration
```json
{
  "Hostname": "graphite.example.com",
  "Port": "2003",
  "Prefix": "servers.myserver",
  "Protocol": "tcp",
  "SendBufferSize": 2000,
  "Servername": "graphite-server",
  "Debug": false
}
```

#### SumoOut Configuration
```json
{
  "SendBufferSize": 2000,
  "Debug": true
}
```
*Note: SumoOut inherits GraphiteOut configuration structure but only uses SendBufferSize and Debug settings. The HTTP collector endpoint is currently hard-coded.*

#### SitesFilter Configuration (Example)
```json
{
  "rules": [
    {
      "pattern": ".*Processor.*",
      "action": "include",
      "site": "production"
    },
    {
      "pattern": ".*Memory.*",
      "action": "include", 
      "site": "production"
    },
    {
      "pattern": ".*idle.*",
      "action": "exclude"
    }
  ],
  "defaultSite": "unknown"
}
```
*Note: Actual SitesFilter configuration format may vary - this is a conceptual example.*

## Installation

Metricus is implemented as a [TopShelf](https://github.com/Topshelf/Topshelf) service:

```bash
# Run as console application (for testing)
metricus.exe

# Install as Windows service
metricus.exe install

# Start the service
metricus.exe start

# Stop the service  
metricus.exe stop

# Uninstall the service
metricus.exe uninstall

# See all options
metricus.exe --help
```

**ProTip**: TopShelf makes service management super easy! 😉

## Development Setup (This Branch)

This branch (`local-work`) includes development improvements and project structure enhancements:

### Development Enhancements

* **Comprehensive .gitignore**: Complete .NET gitignore excluding:
  - Build outputs (`bin/`, `obj/`, Debug/Release folders)
  - NuGet packages (`packages/` folder)
  - IDE files (`.vs/`, `.idea/`, `*.user`, `*.suo`)
  - Build artifacts (`*.dll`, `*.exe`, `*.pdb`, XML docs)
  - OS files (`.DS_Store`, `Thumbs.db`)
  - ILLink build artifacts

### Building

```bash
# Clone the repository
git clone https://github.com/preetmyob/metricus.git
cd metricus

# Switch to development branch
git checkout local-work

# Restore NuGet packages
nuget restore met.sln

# Build solution (requires .NET Framework)
msbuild met.sln /p:Configuration=Release
```

### Development Benefits

* Clean repository without build artifacts
* Proper IDE integration with ignored user-specific files
* Comprehensive coverage of .NET build outputs
* Configuration files preserved while generated content ignored

## Plugin Development

### Creating an Input Plugin
```csharp
using System;
using System.Collections.Generic;
using Metricus.Plugin;

public class MyInputPlugin : InputPlugin, IInputPlugin
{
    public override List<metric> Work()
    {
        var metrics = new List<metric>();
        
        // Example: Collect custom application metrics
        var cpuMetric = new metric
        {
            site = "myapp",
            category = "Application",
            type = "CPU Usage",
            instance = "MyService",
            value = GetCpuUsage(), // Your custom logic
            timestamp = DateTime.UtcNow
        };
        
        metrics.Add(cpuMetric);
        
        // Add more metrics as needed
        var memoryMetric = new metric
        {
            site = "myapp", 
            category = "Application",
            type = "Memory Usage MB",
            instance = "MyService",
            value = GetMemoryUsageMB(),
            timestamp = DateTime.UtcNow
        };
        
        metrics.Add(memoryMetric);
        
        return metrics;
    }
    
    private double GetCpuUsage()
    {
        // Your implementation to get CPU usage
        return 0.0;
    }
    
    private double GetMemoryUsageMB()
    {
        // Your implementation to get memory usage
        return 0.0;
    }
}
```

### Creating a Filter Plugin
```csharp
using System.Collections.Generic;
using System.Linq;
using Metricus.Plugin;

public class MyFilterPlugin : FilterPlugin, IFilterPlugin
{
    public override List<metric> Work(List<metric> metrics)
    {
        var filteredMetrics = new List<metric>();
        
        foreach (var metric in metrics)
        {
            // Example: Filter by category
            if (metric.category == "Processor" || metric.category == "Memory")
            {
                // Example: Add site information
                if (string.IsNullOrEmpty(metric.site))
                {
                    metric.site = "default";
                }
                
                // Example: Transform metric names
                if (metric.type.Contains(" "))
                {
                    metric.type = metric.type.Replace(" ", "_");
                }
                
                filteredMetrics.Add(metric);
            }
            
            // Example: Exclude noisy metrics
            if (metric.type.Contains("idle") && metric.value < 1.0)
            {
                continue; // Skip low-value idle metrics
            }
        }
        
        return filteredMetrics;
    }
}
```

### Creating an Output Plugin
```csharp
using System;
using System.Collections.Generic;
using System.IO;
using Metricus.Plugin;
using Newtonsoft.Json;

public class MyOutputPlugin : OutputPlugin, IOutputPlugin
{
    private readonly string _outputPath;
    
    public MyOutputPlugin(PluginManager pm) : base(pm)
    {
        _outputPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "metrics.log");
    }
    
    public override void Work(List<metric> metrics)
    {
        foreach (var metric in metrics)
        {
            // Example: Log to file
            var logEntry = new
            {
                Timestamp = metric.timestamp,
                Site = metric.site,
                Category = metric.category,
                Type = metric.type,
                Instance = metric.instance,
                Value = metric.value
            };
            
            var json = JsonConvert.SerializeObject(logEntry);
            File.AppendAllText(_outputPath, json + Environment.NewLine);
            
            // Example: Send to external API
            SendToExternalApi(metric);
        }
    }
    
    private void SendToExternalApi(metric metric)
    {
        // Your implementation to send to external system
        Console.WriteLine($"Sending metric: {metric.category}.{metric.type} = {metric.value}");
    }
}
```

### Plugin Configuration Template
Create a `config.json` file in your plugin directory:
```json
{
  "enabled": true,
  "interval": 30000,
  "customSettings": {
    "apiEndpoint": "https://api.example.com/metrics",
    "apiKey": "your-api-key",
    "timeout": 5000
  }
}
```

### Plugin Registration
1. **Build your plugin** as a .NET library (.dll)
2. **Place the compiled plugin** in the appropriate subdirectory:
   - Input plugins: `bin/Debug/Plugins/YourInputPlugin/`
   - Filter plugins: `bin/Debug/Plugins/YourFilterPlugin/`
   - Output plugins: `bin/Debug/Plugins/YourOutputPlugin/`
3. **Add configuration** file in the same directory
4. **Enable in main config** by adding to ActivePlugins list in `metricus/config.json`

## Requirements

- .NET Framework 4.0 or later
- Windows Operating System (for Performance Counter plugin)
- Administrator privileges (for service installation)

## Monitoring Integrations

- **Graphite**: Real-time graphing and dashboards
- **Sumo Logic**: Cloud-based log management and analytics
- **Console**: Local debugging and development
- **Custom**: Extend with your own output plugins

## License

[Add your license information here]

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a Pull Request
