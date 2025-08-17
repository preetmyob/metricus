# Metricus Scripts

This folder contains build, deployment, and testing scripts for the Metricus project, along with production configuration files.

## 🚀 Build & Deployment Scripts

### **Publish-Metricus-Zip.ps1** - *Main Build Script*
**Purpose:** Builds and packages Metricus for deployment

**Usage:**
```powershell
.\Publish-Metricus-Zip.ps1           # Production deployment
.\Publish-Metricus-Zip.ps1 -Dev      # Development testing
.\Publish-Metricus-Zip.ps1 -Test     # Test environment
.\Publish-Metricus-Zip.ps1 -MinTest  # Minimal monitoring
```

**What it does:**
- Builds the solution in Release mode
- Copies binaries and dependencies to structured folder
- Applies environment-specific configuration
- Creates versioned zip package (e.g., `metricus-1.1.0.zip`)
- Ready-to-deploy package matching production structure

**Options:**
- **No options** = Production build (localhost Graphite, no console output)
- **-Dev** = Development build (external Graphite, console output, debug mode)
- **-Test** = Test build (local test Graphite 10.0.0.14, debug mode)
- **-MinTest** = Minimal build (basic counters only, test Graphite)

**Output:** `scripts/releases/metricus-1.1.0.zip`

---

## 🧪 Testing & Development Scripts

### **Setup-TestIIS.ps1** - *IIS Test Environment Setup*
**Purpose:** Sets up IIS test websites for Metricus testing

**When to use:** Before running Metricus to test IIS performance counter collection

**What it does:**
- Creates test IIS sites and application pools
- Configures ASP.NET applications for metric generation
- Sets up test endpoints for load generation

### **Setup-TestIIS-WinPS.ps1** - *Windows PowerShell Version*
**Purpose:** Same as Setup-TestIIS.ps1 but for Windows PowerShell (not PowerShell Core)

**When to use:** On Windows systems without PowerShell Core

### **Cleanup-TestIIS.ps1** - *IIS Test Cleanup*
**Purpose:** Removes test IIS sites and application pools

**When to use:** After testing to clean up the test environment

**What it does:**
- Removes test sites and app pools created by Setup-TestIIS.ps1
- Cleans up test configurations

### **Generate-Load.ps1** - *Load Testing*
**Purpose:** Generates HTTP load against test websites

**When to use:** To create measurable activity for Metricus to collect

**What it does:**
- Makes GET and POST requests to test sites
- Simulates different types of load (CPU, memory, I/O, exceptions)
- Runs for specified duration with configurable request rate

**Usage:**
```powershell
.\Generate-Load.ps1                                    # Default: 60 min, 30 req/min
.\Generate-Load.ps1 -DurationMinutes 30 -RequestsPerMinute 60
.\Generate-Load.ps1 -BaseUrl "http://mytest:8080"
```

### **Rebuild-ConsoleOut.ps1** - *Plugin Development*
**Purpose:** Rebuilds the ConsoleOut plugin for development

**When to use:** During plugin development to quickly test changes

---

## ⚙️ Configuration Management Scripts

### **Update-Configs.ps1** - *Configuration Deployment*
**Purpose:** Updates configuration files across environments

**When to use:** To deploy configuration changes without rebuilding

**What it does:**
- Applies environment-specific overrides to deployed configurations
- Updates running Metricus instances with new settings

---

## 📋 Configuration Files

### **Production Defaults** *(Base configuration)*

#### **config-main.json** - *Service Configuration*
- **Interval:** 10 seconds between collections
- **Plugins:** PerformanceCounter → SitesFilter → GraphiteOut
- **Host:** Placeholder for unused UDP hostname

#### **config-graphiteout.json** - *Graphite Output*
- **Hostname:** 127.0.0.1 (localhost)
- **Port:** 2003 (Carbon plaintext protocol)
- **Prefix:** advanced.env> (template for environment substitution)
- **Protocol:** TCP with 2000-byte buffer
- **Debug:** false (production)

#### **config-sitesfilter.json** - *IIS Site Separation*
- **Purpose:** Routes metrics by IIS site vs server
- **Categories:** ASP.NET Applications, Process, .NET CLR, W3SVC_W3WP
- **Filters:** lmw3svc, w3wp.process, w3wp.net, w3svc
- **Debug:** false (production)

#### **config-perfcounter.json** - *Performance Counter Collection*
**System Counters:**
- Processor (CPU usage)
- Memory (available MB, paging)
- Network Interface (bytes/packets)
- Physical/Logical Disk (I/O, free space)
- System (processes, threads, context switches)

**IIS/Web Counters:**
- ASP.NET Applications (requests/sec, errors, execution time)
- ASP.NET (application restarts, requests queued)
- Web Service (bytes sent/received)
- W3SVC_W3WP (active requests)

**.NET Runtime Counters:**
- .NET CLR Memory (GC, heap sizes, allocations)
- .NET CLR Exceptions (exceptions/sec)
- .NET CLR JIT (compilation time, methods)
- .NET CLR LocksAndThreads (contention)

**Process Monitoring:**
- Dynamic discovery of w3wp processes (IIS worker processes)
- Specific monitoring of metricus and nxlog processes

#### **config-consoleout.json** - *Console Debug Output*
- Empty configuration (plugin disabled in production)

### **Environment Overrides**

#### **environment-overrides.json** - *Environment-Specific Settings*

**Development Environment:**
- **Graphite:** External server (graphite.edops.myob.com:2010)
- **Prefix:** advanced.development
- **Console:** Enabled for debugging
- **Debug:** Enabled for all plugins
- **Server:** preet.i-9999999

**Test Environment:**
- **Graphite:** Local test server (10.0.0.14:2003)
- **Prefix:** advanced.production (for testing production routing)
- **Interval:** 5 seconds (faster collection)
- **Console:** Enabled for debugging
- **Debug:** Enabled for all plugins
- **Server:** preet.i-9999999

**MinTest Environment:**
- **Graphite:** Local test server (10.0.0.14:2003)
- **Prefix:** minimal.test
- **Plugins:** PerformanceCounter → GraphiteOut (no SitesFilter)
- **Counters:** Only Processor, Memory, System (minimal set)
- **Server:** minimal

---

## 🎯 Common Workflows

### **Development Testing**
1. `.\Setup-TestIIS.ps1` - Set up test IIS sites
2. `.\Publish-Metricus-Zip.ps1 -Dev` - Build development package
3. Deploy and run Metricus with development config
4. `.\Generate-Load.ps1` - Generate test load
5. Monitor metrics in Graphite/Grafana
6. `.\Cleanup-TestIIS.ps1` - Clean up when done

### **Production Deployment**
1. `.\Publish-Metricus-Zip.ps1` - Build production package
2. Deploy `metricus-1.1.0.zip` to production server
3. Extract and run as Windows service
4. Monitor metrics in production Graphite

### **Test Environment Validation**
1. `.\Publish-Metricus-Zip.ps1 -Test` - Build test package
2. Deploy to test environment
3. Verify metrics flow to test Graphite (10.0.0.14:8080)
4. Validate metric routing and site separation

### **Plugin Development**
1. Make code changes to plugin
2. `.\Rebuild-ConsoleOut.ps1` - Quick rebuild
3. Test with console output enabled
4. `.\Publish-Metricus-Zip.ps1 -Dev` - Full build when ready

---

## 📦 Package Structure

All builds create packages matching production structure:
```
metricus-1.1.0/
├── metricus.exe                    # Main service
├── metricus.exe.config            # .NET config
├── config.json                    # Service config
├── PluginInterface.dll            # Plugin interface
├── [Dependencies]                 # TopShelf, NLog, Newtonsoft.Json
└── Plugins/
    ├── ConsoleOut/ConsoleOut.dll
    ├── GraphiteOut/GraphiteOut.dll + config.json
    ├── PerfCounter/PerformanceCounter.dll + config.json
    └── SitesFilter/SitesFilter.dll + config.json
```

## 🔧 Version Management

- Version automatically extracted from `GlobalAssemblyInfo.cs`
- Current version: **1.1.0**
- Package naming: `metricus-{version}.zip`
- All assemblies use centralized versioning
```powershell
# Production build (default)
.\scripts\Publish-Metricus.ps1

# Development build with debug enabled
.\scripts\Publish-Metricus.ps1 -Environment Development

# Test build with minimal plugins
.\scripts\Publish-Metricus.ps1 -Environment Test
```

### Advanced Usage
```powershell
# Custom output path
.\scripts\Publish-Metricus.ps1 -OutputPath "C:\Deploy\Metricus"

# Debug build configuration
.\scripts\Publish-Metricus.ps1 -Configuration Debug -Environment Development
```

## Environment Configurations

### Production
- **Plugins**: PerformanceCounter, SitesFilter, GraphiteOut
- **Debug**: Disabled
- **Interval**: 10 seconds
- **Purpose**: Production monitoring with full metric collection

### Development
- **Plugins**: PerformanceCounter, SitesFilter, GraphiteOut, ConsoleOut
- **Debug**: Enabled in GraphiteOut and SitesFilter
- **Interval**: 10 seconds
- **Purpose**: Development with console output and debug information

### Test
- **Plugins**: PerformanceCounter, ConsoleOut
- **Debug**: Enabled in all plugins
- **Interval**: 5 seconds
- **Purpose**: Testing with minimal plugins and fast feedback

## Configuration Management

### Modifying Configurations
1. Edit the appropriate `config-*.json` file
2. For environment-specific changes, modify `environment-overrides.json`
3. Run the build script to apply changes

### Adding New Environments
1. Add a new section to `environment-overrides.json`
2. Update the `ValidateSet` in `Publish-Metricus.ps1` to include the new environment
3. Document the new environment in this README

### Configuration Precedence
1. Base configuration from `config-*.json` files
2. Environment overrides from `environment-overrides.json`
3. Final configuration written to deployment package

## Output

The script creates a deployment package with:
- Compiled Metricus service and all plugins
- Applied configuration files
- Windows service installation scripts (`install.bat`, `uninstall.bat`)
- Documentation (`README.md`)

## Requirements

- PowerShell 5.1 or PowerShell Core
- .NET SDK or Visual Studio Build Tools
- Windows (for final deployment)

## Troubleshooting

### Build Failures
- Ensure .NET SDK or MSBuild is installed
- Check that all project dependencies are restored
- Verify solution file exists in parent directory

### Configuration Errors
- Validate JSON syntax in configuration files
- Check that all required properties are present
- Ensure environment names match exactly (case-sensitive)

### Deployment Issues
- Run installation scripts as Administrator on target machine
- Verify .NET Framework 4.8 is installed on target
- Check Windows Event Log for service startup errors
