# garm-provider-vultr

## Project Overview

Crystal-based external provider for [garm](https://github.com/cloudbase/garm) (GitHub Actions Runner Manager) targeting Vultr cloud. Implements the garm external provider interface v0.1.1 — a stdin/stdout/env-var protocol with 7 commands.

## Architecture

```
src/
├── main.cr              # Entry point: dispatches GARM_COMMAND
├── version.cr           # Version constant, EXIT_NOT_FOUND=5
├── config.cr            # 3-layer config: ProviderConfig → ExtraSpecs → ResolvedConfig
├── provider/
│   ├── types.cr         # garm-compatible types (BootstrapInstance, ProviderInstance, etc.)
│   ├── userdata.cr      # cloud-init user data generation (JIT + token modes)
│   ├── create.cr        # CreateInstance command
│   ├── delete.cr        # DeleteInstance (idempotent)
│   ├── get.cr           # GetInstance
│   ├── list.cr          # ListInstances (by pool tag, filtered by controller)
│   ├── remove_all.cr    # RemoveAllInstances
│   ├── start.cr         # Start
│   └── stop.cr          # Stop (Vultr "halt")
├── vultr/
│   ├── client.cr        # Vultr API v2 HTTP client (retry, pagination)
│   └── status_map.cr    # Vultr→garm status mapping, tag utilities
└── util/
    └── env.cr           # GARM_* environment variable helpers
```

## Code Style

- **Language**: Crystal >= 1.14.0
- **Dependencies**: Zero external shards — stdlib only (HTTP::Client, JSON, Base64, OpenSSL)
- **Naming**: Crystal conventions — `snake_case` methods/variables, `PascalCase` types/modules
- **JSON fields**: Use `@[JSON::Field(key: "snake_case")]` annotations to match garm's wire format
- **Error output**: All diagnostic/log messages go to STDERR; only JSON results go to STDOUT
- **Modules**: `GarmProviderVultr` (top-level), `GarmProvider` (types), `Vultr` (API client)

## Build and Test

```bash
# Install dependencies
shards install

# Build (debug)
crystal build src/main.cr -o bin/garm-provider-vultr

# Build (release)
crystal build src/main.cr -o bin/garm-provider-vultr --release --no-debug

# Run tests
crystal spec
```

## Conventions

### garm External Provider Protocol
- Commands received via `GARM_COMMAND` env var: `CreateInstance`, `DeleteInstance`, `GetInstanceInfo`, `ListInstances`, `RemoveAllInstances`, `StartInstance`, `StopInstance`
- `CreateInstance` reads `BootstrapInstance` JSON from stdin
- All commands output `ProviderInstance` (or array) JSON to stdout
- Config file path from `GARM_PROVIDER_CONFIG_FILE`; pool overrides from `GARM_POOL_EXTRASPECS` (base64-encoded JSON)
- Exit code 5 = NOT_FOUND (garm convention)

### Vultr API
- Base URL: `https://api.vultr.com/v2`
- Auth: `Authorization: Bearer {api_key}`
- Instance tagging: `garm-controller-id:{id}`, `garm-pool-id:{id}`
- Retry: 3 retries with exponential backoff for 429/5xx
- Delete is idempotent (404 = success)

### User Data / Startup Script
- Linux only — uses cloud-init (`#cloud-config` YAML)
- Install script mirrors garm-provider-common's CloudConfigTemplate
- Supports both JIT config and token-based runner registration
- Double Base64: script→b64 in cloud-config write_files, then entire cloud-config→b64 for Vultr API

### Testing
- Specs in `spec/` — unit tests for config, types, status mapping, userdata
- No integration tests (require live Vultr API key)
- Run `crystal spec` before committing

## Key Design Decisions

1. **No external shards**: Minimizes supply chain risk and build complexity for a security-sensitive binary
2. **Tag-based instance identification**: Enables multi-tenant garm controllers on one Vultr account
3. **Fallback name search**: If GARM_INSTANCE_ID isn't a Vultr UUID, search by label/hostname via controller tag
4. **OS source priority**: image_id > snapshot_id > os_id (checked in that order in ResolvedConfig)
