# Metricus Modernization Plan

## Goal
Bring the current development codebase in line with the production xwing (0.5.0) capabilities while maintaining our modernization improvements (PackageReference, .NET 4.8, System.Text.Json).

## Tasks to Address Production Gaps

### Configuration Enhancements
• Add Debug configuration option to GraphiteOut plugin
• Add Debug configuration option to SitesFilter plugin  
• Add SendBufferSize configuration to GraphiteOut plugin
• Add Servername configuration to GraphiteOut plugin
• Update main config.json to match xwing structure and formatting
• Update all plugin config.json files to use proper indented formatting

### Dependency Management
• Investigate why xwing has expanded System.* dependency tree
• Determine if System.Buffers, System.Memory, etc. are needed for performance
• Evaluate if plugins need local copies of ServiceStack.Text (vs shared)
• Assess Windows-specific dependencies in SitesFilter (Registry, EventLog, etc.)
• Review if plugin-specific .dll.config files are needed

### Code Functionality Gaps
• Implement SendBufferSize functionality in GraphiteOut plugin
• Implement Debug logging in GraphiteOut plugin
• Implement Debug logging in SitesFilter plugin
• Add Servername field handling in GraphiteOut plugin
• Review if Process monitoring instances need adjustment (remove chef_runner_service)

### Build and Deployment
• Ensure proper dependency resolution for expanded library set
• Verify plugin isolation works correctly
• Test that modernized JSON libraries work with production configs
• Validate .NET 4.8 compatibility with production environment

### Documentation and Testing
• Update README with new configuration options
• Document debug capabilities and usage
• Test performance impact of buffer management
• Validate Windows-specific functionality on target platforms

### Version Alignment
• Consider version numbering strategy (current vs 0.5.0)
• Plan migration path from ServiceStack.Text to System.Text.Json in production
• Ensure backward compatibility with existing production configs

## Current State vs Target
- **Current**: Modernized build system, partial JSON library conversion
- **Target**: Production-ready with enhanced configuration, debugging, and performance features
- **Gap**: Missing debug capabilities, buffer management, and some dependency optimizations

## Priority Considerations
- Configuration enhancements are likely quick wins
- Dependency investigation may reveal performance optimizations
- Debug capabilities will improve operational support
- Buffer management could impact performance significantly
