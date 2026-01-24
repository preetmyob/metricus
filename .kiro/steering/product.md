---
inclusion: always
---

# Metricus Product Overview

Metricus is a lightweight Windows metrics collection service inspired by collectd. It collects performance metrics from various sources, optionally transforms them, and then forwards them to monitoring systems like Graphite or Sumologic.

## Core Purpose

Collect Windows performance metrics (CPU, memory, disk, IIS, .NET runtime) and forward them to monitoring backends for visualization and alerting.

## Architecture

Pipeline-based architecture with three plugin types:

- **Input Plugins**: Collect metrics from sources (Performance Counters, etc.)
- **Filter Plugins**: Process, transform, or filter metrics (e.g., IIS site separation)
- **Output Plugins**: Forward metrics to monitoring systems (Graphite, Console, Sumologic)

## Key Characteristics

- Runs as a Windows service using TopShelf
- JSON-based configuration for all components
- Plugin-based extensibility without factory pattern complexity
- Configurable collection intervals (typically 5-10 seconds)
- Supports ephemeral instance handling (dynamic IIS worker processes)

## Target Environment

- Windows servers running IIS and .NET applications
- Production monitoring with Graphite/Grafana visualization
- Development and test environments with local Graphite instances
