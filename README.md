````markdown
Metricus
========
Metricus is a .Net metric collection service inspired by collectd but far less sophisticated.  

### Key features

* JSON configuration
* Input/Filter/Output plugins
* ZeroFactories&trade;
    * Seriously though, it's very easy to read the code.
    * And yes, no factories.
* Ephemeral instance support for performance counters.

### Installation
Metricus is impleneted as a [TopShelf](https://github.com/Topshelf/Topshelf) service.  Running the executable without options will start a standard process, or add "--help" to see all the service related options.  I'll leave it to the user to figure out how to install it as a service.

ProTip:  It's super easy ;)

### Configuration
Configuration is handled through config.json files.  The ~~daemon~~ service configuration file is in the base directory, and each of the plugins has their own file in their respective directories.

#### Service Configuration

```json
{
  "Host" : "laptop_co_nz",
  "Interval" : "10000",
  "ActivePlugins" : [
  	"PerformanceCounter",
  	"Graphite",
  	"ConsoleOut"
  ]
}

```

## Development Setup (This Branch)

This branch (`local-work`) includes development improvements and project structure enhancements:

### Added Features

* **Comprehensive .gitignore**: Added a complete .NET gitignore file that properly excludes:
  - Build outputs (`bin/`, `obj/`, Debug/Release folders)
  - NuGet packages folder (`packages/`)
  - IDE-specific files (`.vs/`, `.idea/`, `*.user`, `*.suo`)
  - Build artifacts (`*.dll`, `*.exe`, `*.pdb`, etc.)
  - XML documentation files (with exceptions for project files)
  - OS-specific files (`.DS_Store`, `Thumbs.db`)
  - ILLink build artifacts

### Project Structure

The solution includes the following projects:

* **metricus**: Main service application
* **ConsoleOut**: Console output plugin for debugging
* **GraphiteOut**: Graphite output plugin with TCP client
* **PerformanceCounter**: Windows Performance Counter input plugin
* **PluginInterface**: Core plugin interface definitions and base classes
* **SitesFilter**: Site-based filtering plugin
* **SumoOut**: Sumo Logic output plugin

### Development Benefits

* Clean repository without build artifacts
* Proper IDE integration with ignored user-specific files
* Comprehensive coverage of .NET build outputs
* Maintains important configuration files while ignoring generated content

### Building

This project uses .NET Framework with NuGet package management. Build artifacts are automatically ignored by the comprehensive .gitignore.

```bash
# Clone the repository
git clone https://github.com/preetmyob/metricus.git
cd metricus

# Switch to development branch
git checkout local-work

# Build solution (requires .NET Framework)
msbuild met.sln
```

````
