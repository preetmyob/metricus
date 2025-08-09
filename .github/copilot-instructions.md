# Copilot Instructions for Metricus

## Overview
Metricus is a .NET metric collection service inspired by collectd, designed for extensibility and simplicity. The architecture is plugin-based, supporting input, filter, and output plugins, each with their own configuration files. The main service is configured via a root `config.json`.

## Architecture & Key Patterns
- **Plugin System:**
  - Plugins are located in `plugins/` and loaded dynamically at runtime.
  - Each plugin (e.g., `PerfCounter`, `SitesFilter`, `GraphiteOut`, `ConsoleOut`, `SumoOut`) has its own directory, code, and `config.json`.
  - Plugins implement interfaces from `PluginInterface/`.
  - No factory pattern is used; plugin instantiation is direct and simple.
- **Configuration:**
  - Main service config: `metricus/config.json` (specifies host, interval, and active plugins).
  - Each plugin has its own `config.json` for plugin-specific settings.
  - Example: `PerfCounter` configures Windows performance counters by category/counter/instance.
  - Example: `SitesFilter` transforms metric names for IIS/ASP.NET apps.
- **Data Flow:**
  - Metrics are collected by input plugins, optionally filtered, and sent to output plugins.
  - Data flows: Input → (Filter) → Output.

## Developer Workflows
- **Build:**
  - Use the solution file `metricus.sln` to build all projects (main service, plugins, interfaces).
  - Standard .NET build commands apply: `dotnet build metricus.sln`.
- **Run:**
  - The service runs as a [TopShelf](https://github.com/Topshelf/Topshelf) service, but can also be run as a console app for development.
  - Use `--help` for service options.
- **Debug:**
  - Debug plugins independently by running them as part of the main service with only the relevant plugin enabled in `config.json`.

## Project-Specific Conventions
- **No Factories:**
  - Plugin instantiation is intentionally direct for code clarity.
- **Ephemeral Instances:**
  - Some plugins (e.g., `PerfCounter`) support ephemeral instances for dynamic metric sources.
- **JSON Configs:**
  - All configuration is JSON-based, both for the service and plugins.
- **Naming:**
  - Plugin directories and config files are named after the plugin (e.g., `PerfCounter`, `SitesFilter`).

## Integration & Extension
- **Adding Plugins:**
  - Implement plugin interfaces from `PluginInterface/`.
  - Place new plugin in `plugins/`, add config, and reference in main `config.json`.
- **External Dependencies:**
  - Uses TopShelf for service management.
  - Output plugins may integrate with external systems (e.g., Graphite, Sumo Logic).

## References
- Main config: `metricus/config.json`
- Plugin interface: `PluginInterface/`
- Example plugin: `plugins/PerfCounter/`, `plugins/SitesFilter/`
- Build: `metricus.sln`
- Service entry: `metricus/Program.cs`

---

_If any conventions or workflows are unclear or missing, please provide feedback to improve these instructions._
