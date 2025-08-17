# Metricus Testing Environment

## Local Graphite Testing

This directory contains Docker Compose configuration for running a local Graphite instance for testing Metricus.

### Starting the Test Environment

```bash
cd tests
docker-compose up -d
```

### Accessing Graphite

- **Web Interface**: http://localhost:8080
- **Carbon Receiver (plaintext)**: localhost:2003
- **StatsD UDP**: localhost:8125

### Stopping the Test Environment

```bash
docker-compose down
```

### Cleaning Up Data

To remove all stored metrics data:

```bash
docker-compose down -v
```

### Configuration

The environment overrides in `scripts/environment-overrides.json` are configured to use this local Graphite instance.
