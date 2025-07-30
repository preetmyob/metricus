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
  - `IInputPlugin`: Interface for metric collection plugins
  - `IOutputPlugin`: Interface for metric output plugins
  - `IFilterPlugin`: Interface for metric processing plugins
  - `metric`: Core data structure for metric information
  - `PluginManager`: Base plugin management functionality

### Input Plugins
- **📁 PerformanceCounter**: Windows Performance Counter input plugin
  - Collects system performance metrics (CPU, Memory, Network, Disk, etc.)
  - Supports multiple categories: Processor, Memory, Network Interface, PhysicalDisk, etc.
  - Handles both static and dynamic counter instances
  - Configuration: Detailed JSON mapping of categories, counters, and instances

### Filter Plugins
- **📁 SitesFilter**: Site-based metric filtering plugin
  - Filters metrics based on site categories and custom rules
  - Supports include/exclude patterns
  - Allows metric transformation and categorization
  - Configuration: Rule-based filtering criteria

### Output Plugins
- **📁 ConsoleOut**: Console output plugin for debugging and testing
  - Outputs formatted JSON metrics to console
  - Useful for development and troubleshooting
  - No additional configuration required

- **📁 GraphiteOut**: Graphite metrics output plugin
  - Forwards metrics to Graphite monitoring systems
  - Supports both TCP and UDP protocols
  - Configurable connection settings and prefixes
  - Batched sending with configurable buffer sizes
  - Configuration: Hostname, port, protocol, and formatting options

- **📁 SumoOut**: Sumo Logic output plugin
  - Sends metrics to Sumo Logic cloud monitoring platform
  - HTTP/HTTPS endpoint support
  - Configurable formatting and metadata
  - Configuration: Endpoint URLs, authentication, and format settings

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
      "counters": ["% Processor Time"],
      "instances": ["_Total"]
    },
    {
      "name": "Memory", 
      "counters": ["Available MBytes", "Pages/sec"]
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
  "Debug": false
}
```

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
public class MyInputPlugin : InputPlugin, IInputPlugin
{
    public override List<metric> Work()
    {
        var metrics = new List<metric>();
        // Collect your metrics here
        return metrics;
    }
}
```

### Creating an Output Plugin
```csharp
public class MyOutputPlugin : OutputPlugin, IOutputPlugin
{
    public override void Work(List<metric> metrics)
    {
        foreach (var metric in metrics)
        {
            // Process each metric
        }
    }
}
```

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
