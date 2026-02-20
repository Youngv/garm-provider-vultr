# garm-provider-vultr

A [garm](https://github.com/cloudbase/garm) external provider for [Vultr](https://www.vultr.com/), written in [Crystal](https://crystal-lang.org/).

This provider enables garm to manage GitHub Actions self-hosted runners on Vultr cloud instances.

## Prerequisites

- [Crystal](https://crystal-lang.org/install/) >= 1.14.0
- A Vultr account with API access
- A running [garm](https://github.com/cloudbase/garm) installation

## Building

```bash
shards build --release
```

The binary will be available at `bin/garm-provider-vultr`.

## Configuration

### Provider Config File

Create a JSON configuration file (e.g., `/etc/garm/vultr-provider.json`):

```json
{
  "api_key": "",
  "region": "ewr",
  "plan": "vc2-1c-1gb",
  "os_id": 1743,
  "sshkey_id": [],
  "enable_ipv6": false,
  "firewall_group_id": "",
  "enable_vpc": false,
  "attach_vpc": []
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `api_key` | string | No* | Vultr API key. Prefer using `VULTR_API_KEY` env var instead. |
| `region` | string | Yes | Default Vultr region (e.g., `ewr`, `lax`, `ord`). See [Vultr regions](https://www.vultr.com/features/datacenter-locations/). |
| `plan` | string | Yes | Default instance plan (e.g., `vc2-1c-1gb`). See [Vultr plans](https://www.vultr.com/pricing/). |
| `os_id` | int | Yes** | Default OS template ID (e.g., `1743` for Ubuntu 22.04 x64). |
| `sshkey_id` | string[] | No | SSH key IDs to inject into instances. |
| `enable_ipv6` | bool | No | Enable IPv6 on instances. |
| `firewall_group_id` | string | No | Vultr firewall group ID to apply. |
| `enable_vpc` | bool | No | Enable VPC for instances. |
| `attach_vpc` | string[] | No | VPC IDs to attach to instances. |

\* The API key can be provided via the `VULTR_API_KEY` environment variable (recommended) or in the config file.

\** At least one OS source must be provided: `os_id`, `snapshot_id`, or `image_id` (via pool extra_specs).

### Pool Extra Specs

Per-pool overrides can be set in the garm pool configuration under `extra_specs`:

```json
{
  "region": "lax",
  "plan": "vc2-2c-4gb",
  "os_id": 2136,
  "snapshot_id": "",
  "image_id": "",
  "sshkey_id": ["ssh-key-1"],
  "enable_ipv6": true,
  "firewall_group_id": "fw-123",
  "enable_vpc": true,
  "attach_vpc": ["vpc-1"]
}
```

Pool extra_specs override the provider config defaults.

### Environment Variables

| Variable | Description |
|----------|-------------|
| `VULTR_API_KEY` | Vultr API key (preferred over config file). |

The following are set by garm automatically:

| Variable | Description |
|----------|-------------|
| `GARM_COMMAND` | The operation to execute. |
| `GARM_PROVIDER_CONFIG_FILE` | Path to the provider config file. |
| `GARM_CONTROLLER_ID` | Unique garm controller ID. |
| `GARM_POOL_ID` | Pool ID (for CreateInstance, ListInstances). |
| `GARM_INSTANCE_ID` | Instance provider ID (for GetInstance, DeleteInstance, Start, Stop). |
| `GARM_POOL_EXTRASPECS` | Base64-encoded pool extra specs JSON. |
| `GARM_INTERFACE_VERSION` | Provider interface version. |

### Garm Configuration

Add the provider to your garm config:

```toml
[[provider]]
name = "vultr"
description = "Vultr provider"
provider_type = "external"
  [provider.external]
  config_file = "/etc/garm/vultr-provider.json"
  provider_executable = "/usr/local/bin/garm-provider-vultr"
  interface_version = "0.1.1"
  environment_variables = ["VULTR_API_KEY=your-api-key-here"]
```

## Supported Commands

| Command | Description |
|---------|-------------|
| `CreateInstance` | Creates a new Vultr instance with cloud-init for runner bootstrap. |
| `DeleteInstance` | Deletes a Vultr instance (idempotent - no-op if already deleted). |
| `GetInstance` | Returns instance details. |
| `ListInstances` | Lists all instances for a given pool. |
| `RemoveAllInstances` | Removes all instances tagged with the controller ID. |
| `Start` | Starts (boots) a stopped instance. |
| `Stop` | Stops (halts) a running instance. |

## Common Vultr OS IDs

| OS ID | OS |
|-------|----|
| 1743 | Ubuntu 22.04 x64 |
| 2136 | Ubuntu 24.04 x64 |
| 1946 | Debian 12 x64 |
| 2076 | Rocky Linux 9 x64 |
| 2187 | AlmaLinux 9 x64 |

## Troubleshooting

- **API errors**: Check that `VULTR_API_KEY` is set and valid.
- **Instance not creating**: Verify `region`, `plan`, and `os_id` are valid Vultr values.
- **Runner not registering**: Check the instance's cloud-init logs at `/var/log/cloud-init-output.log`.
- **Logs**: The provider writes diagnostic logs to stderr. Check garm's logs for provider output.

## License

Apache-2.0
