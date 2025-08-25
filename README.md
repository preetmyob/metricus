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
* **Enhanced Build System**: Comprehensive dependency management and build scripts
* **Improved Testing**: Complete test coverage with usability scripts

## Architecture

The system uses a pipeline-based architecture:

```
[Input Plugins] → [Filter Plugins] → [Output Plugins]
```

- **Input Plugins**: Collect metrics from various sources (Performance Counters, etc.)
- **Filter Plugins**: Process, transform, or filter collected metrics
- **Output Plugins**: Forward processed metrics to monitoring systems

[Rest of the content remains the same until "Development Setup" section]

## Development Setup

### Prerequisites
- .NET Framework 4.0 or later
- Windows Operating System (for Performance Counter plugin)
- Administrator privileges (for service installation)
- Git for version control

### Development Environment

* **Source Control**: Complete .gitignore configuration for .NET development:
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

# Restore NuGet packages
nuget restore met.sln

# Build solution (requires .NET Framework)
msbuild met.sln /p:Configuration=Release
```

[Rest of the content remains the same]
