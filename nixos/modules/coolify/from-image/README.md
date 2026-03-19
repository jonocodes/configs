# from-image

Image-patching NixOS module for self-hosting
[Coolify v4.x](https://coolify.io).

This approach runs PostgreSQL and Redis as native NixOS services, and only
the Coolify app and realtime server as Docker containers (via
`virtualisation.oci-containers`). A thin Dockerfile layer patches NixOS
support onto the upstream image.

## Status

Work in progress. The module is implemented and builds, but has not been
deployed to a host yet. Needs testing.

## Usage

```nix
imports = [ ../../modules/coolify/from-image ];

services.coolify = {
  enable = true;

  # Optional: pin the base image by digest
  # imageDigest = "sha256:5ac58c4f2aed0fa6e9c093947303d266babfcaf18cac1b6c6d671d1093b38c33";

  # Secrets (auto-generated if not provided)
  # appKeyFile = "/run/secrets/coolify-app-key";
  # database.passwordFile = "/run/secrets/coolify-db-password";
  # redis.passwordFile = "/run/secrets/coolify-redis-password";
  # pusher.appKeyFile = "/run/secrets/coolify-pusher-key";
  # pusher.appSecretFile = "/run/secrets/coolify-pusher-secret";
};
```

## Architecture

| Component | Runs as | Notes |
|---|---|---|
| PostgreSQL | Native NixOS service | `database.createLocally = true` (default) |
| Redis | Native NixOS service | `redis.createLocally = true` (default) |
| Coolify app | Docker container (patched image) | via `oci-containers` |
| Coolify realtime | Docker container (stock image) | via `oci-containers` |

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `false` | Enable the module |
| `imageDigest` | string or null | `null` | Pin Docker image by digest |
| `nixosOverlay` | bool | `true` | Build patched image with NixOS support |
| `port` | int | `8000` | Host port for web UI |
| `soketiPort` | int | `6001` | Host port for Soketi WebSocket |
| `terminalPort` | int | `6002` | Host port for terminal WebSocket |
| `realtimeVersion` | string | `"1.0.11"` | Realtime server image version |
| `dataDir` | string | `"/data/coolify"` | Base data directory |
| `database.createLocally` | bool | `true` | Provision local PostgreSQL |
| `database.host` | string | `"host.docker.internal"` | DB host (when not local) |
| `database.passwordFile` | path or null | `null` | DB password file |
| `redis.createLocally` | bool | `true` | Provision local Redis |
| `redis.passwordFile` | path or null | `null` | Redis password file |
| `pusher.appId` | string | `"coolify"` | Pusher/Soketi app ID |
| `pusher.appKeyFile` | path or null | `null` | Pusher key file |
| `pusher.appSecretFile` | path or null | `null` | Pusher secret file |
| `appKeyFile` | path or null | `null` | Laravel APP_KEY file |
| `phpMemoryLimit` | string | `"256M"` | PHP memory limit |
| `openFirewall` | bool | `false` | Open firewall ports |

## Systemd units

| Unit | Purpose |
|---|---|
| `coolify-setup.service` | SSH key gen, secrets, .env file creation |
| `coolify-build.service` | Builds patched Docker image |
| `coolify-network.service` | Creates `coolify` Docker network |
| `docker-coolify.service` | Coolify app container (oci-containers) |
| `docker-coolify-realtime.service` | Realtime server container (oci-containers) |

## Files

| File | Purpose |
|---|---|
| `default.nix` | NixOS module |
| `Dockerfile.overlay` | Layers NixOS patches onto upstream image |
| `patch-prerequisites.php` | Patches `InstallPrerequisites.php` |
| `PLAN.md` | Detailed architecture and design document |

## Tradeoffs vs from-compose

- Native PostgreSQL/Redis (better NixOS integration, no extra containers)
- `oci-containers` instead of docker-compose (declarative, proper systemd units)
- Proper secrets management via file options
- More complex module with more options to configure
- Not yet tested in production
