# Coolify on NixOS — Image Patching Approach

## Overview

This document describes the architecture for running Coolify on NixOS using a hybrid approach: native NixOS services for infrastructure (PostgreSQL, Redis), Docker containers for application components (Coolify app, realtime server), and image patching to apply NixOS-specific modifications to the Coolify application container.

## Architecture

The deployment consists of five components:

| Component | Runs as | Notes |
|---|---|---|
| PostgreSQL | Native NixOS service | Or remote |
| Redis | Native NixOS service | Or remote |
| Coolify app | Docker container (patched image) | Built locally from patched upstream image |
| Coolify realtime | Docker container (stock image) | Pulled from ghcr.io, pinned version |
| Docker engine | NixOS service | Required for Coolify's core container orchestration |

## Component Details

### 1. PostgreSQL

Coolify's internal database. This is not configurable — Coolify is a Laravel application hardcoded to use PostgreSQL (`DB_CONNECTION=pgsql`). There is no SQLite or MySQL option for Coolify's own data store. (Note: Coolify can deploy many database types for its *users'* applications, but its own configuration, users, and project definitions are always stored in PostgreSQL.)

PostgreSQL is one of the best-supported services in NixOS and runs natively as a systemd service.

**Local configuration:**

```nix
services.postgresql = {
  enable = true;
  package = pkgs.postgresql_15;
  ensureDatabases = [ "coolify" ];
  ensureUsers = [{
    name = "coolify";
    ensureDBOwnership = true;
  }];
  # Allow connections from Docker containers
  settings = {
    listen_addresses = "127.0.0.1,172.17.0.1";
  };
  authentication = ''
    # Local unix socket
    local coolify coolify peer
    # Docker bridge network
    host coolify coolify 172.17.0.0/16 md5
  '';
};
```

**Remote configuration:** Coolify connects to PostgreSQL over standard TCP. The `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, and `DB_DATABASE` environment variables can point to any reachable PostgreSQL instance — a separate NixOS machine, a managed service (Neon, RDS, etc.), or any other host. No local PostgreSQL service is needed in this case.

**NixOS module design:** The module should expose a `services.coolify.database.createLocally` option (following the pattern used by the Nextcloud module in nixpkgs). When `true`, the module provisions the local PostgreSQL service with the correct configuration. When `false`, the user provides connection details and is responsible for the database.

### 2. Redis

Used by Coolify for queue processing (Laravel Horizon), caching, and session management. Like PostgreSQL, Redis is required and has no alternative — the Laravel application expects `QUEUE_CONNECTION=redis`.

Redis has a mature NixOS module.

**Local configuration:**

```nix
services.redis.servers.coolify = {
  enable = true;
  port = 6379;
  bind = "127.0.0.1 172.17.0.1";
  requirePass = "your-redis-password";
  settings = {
    save = "20 1";
    loglevel = "warning";
  };
};
```

**Remote configuration:** Same as PostgreSQL — `REDIS_HOST` and `REDIS_PASSWORD` can point to any reachable Redis instance (another machine, Upstash, ElastiCache, etc.).

**NixOS module design:** Same pattern as the database — `services.coolify.redis.createLocally` controls whether the module provisions a local Redis instance.

### 3. Coolify Application Container

The main Coolify application. This is a Laravel (PHP) application served via PHP-FPM behind an internal web server, with Laravel Horizon managing background queue workers. It is the only component that requires patching.

**Image:** `ghcr.io/coollabsio/coolify`

**Current upstream version:** Tags follow the pattern `v4.0.0-beta.NNN` (e.g., `v4.0.0-beta.468` as of March 2026). The `latest` tag tracks the most recent stable release.

**Patching method:** The image is patched by building a thin layer on top of the upstream image. A local Dockerfile uses the stock Coolify image as a base and applies modifications:

```dockerfile
FROM ghcr.io/coollabsio/coolify:v4.0.0-beta.468

# Apply PHP configuration patches
COPY patched-files/config/app.php /var/www/html/config/app.php
COPY patched-files/some-other-file.php /var/www/html/app/some-other-file.php

# Install additional system packages if needed
RUN apt-get update && apt-get install -y some-package && rm -rf /var/lib/apt/lists/*

# Adjust file permissions if needed
RUN chown -R www-data:www-data /var/www/html/storage
```

This approach:
- Preserves the upstream build exactly as tested and released
- Allows any kind of modification (file changes, package installation, permission fixes, build steps)
- Produces a new image layer that is fast to rebuild when only patches change
- Avoids rebuilding the entire application from source

**Nix integration:** The patched files and Dockerfile are managed as a Nix derivation. A systemd service runs `docker build` on the machine to produce the local image, then `oci-containers` runs the result.

```nix
let
  coolify-patch-context = pkgs.runCommand "coolify-patch-context" {} ''
    mkdir -p $out/patched-files/config
    cp ${./patched-files/config/app.php} $out/patched-files/config/app.php
    cp ${./Dockerfile.patch} $out/Dockerfile
  '';
in
{
  systemd.services.coolify-build = {
    description = "Build patched Coolify Docker image";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    path = [ pkgs.docker ];
    unitConfig.ConditionPathExists =
      "!%t/coolify-built-${coolify-patch-context.name}";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker build -t coolify-local:latest ${coolify-patch-context}
      touch /run/coolify-built-${coolify-patch-context.name}
    '';
  };

  virtualisation.oci-containers.containers.coolify = {
    image = "coolify-local:latest";
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"
      "--network=coolify"
    ];
    ports = [ "8000:8080" ];
    volumes = [
      "/data/coolify/source/.env:/var/www/html/.env:ro"
      "/data/coolify/ssh:/var/www/html/storage/app/ssh"
      "/data/coolify/applications:/var/www/html/storage/app/applications"
      "/data/coolify/databases:/var/www/html/storage/app/databases"
      "/data/coolify/services:/var/www/html/storage/app/services"
      "/data/coolify/backups:/var/www/html/storage/app/backups"
      "/data/coolify/webhooks-during-maintenance:/var/www/html/storage/app/webhooks-during-maintenance"
      "/var/run/docker.sock:/var/run/docker.sock"
    ];
    environment = {
      APP_ENV = "production";
      DB_CONNECTION = "pgsql";
      DB_HOST = "host.docker.internal";
      DB_PORT = "5432";
      DB_DATABASE = "coolify";
      DB_USERNAME = "coolify";
      REDIS_HOST = "host.docker.internal";
      QUEUE_CONNECTION = "redis";
      SSL_MODE = "off";
      PHP_PM_CONTROL = "dynamic";
      PHP_PM_START_SERVERS = "1";
      PHP_PM_MIN_SPARE_SERVERS = "1";
      PHP_PM_MAX_SPARE_SERVERS = "10";
      # Secrets (DB_PASSWORD, REDIS_PASSWORD, APP_KEY, PUSHER_*) should
      # be provided via environmentFiles or the .env bind mount
    };
  };

  systemd.services.docker-coolify.after = [ "coolify-build.service" ];
  systemd.services.docker-coolify.requires = [ "coolify-build.service" ];
}
```

**Key environment variables:**

| Variable | Purpose | Example |
|---|---|---|
| `APP_ID` | Unique instance identifier | (auto-generated) |
| `APP_KEY` | Laravel encryption key | `base64:...` |
| `APP_URL` | Public URL of the Coolify instance | `https://coolify.example.com` |
| `DB_CONNECTION` | Database driver (always `pgsql`) | `pgsql` |
| `DB_HOST` | PostgreSQL host | `host.docker.internal` |
| `DB_PORT` | PostgreSQL port | `5432` |
| `DB_DATABASE` | Database name | `coolify` |
| `DB_USERNAME` | Database user | `coolify` |
| `DB_PASSWORD` | Database password | (secret) |
| `REDIS_HOST` | Redis host | `host.docker.internal` |
| `REDIS_PASSWORD` | Redis password | (secret) |
| `QUEUE_CONNECTION` | Queue backend (always `redis`) | `redis` |
| `HORIZON_BALANCE` | Horizon balancing strategy | `100` |
| `HORIZON_MAX_PROCESSES` | Max queue worker processes | `10` |
| `HORIZON_BALANCE_MAX_SHIFT` | Horizon balance max shift | `10` |
| `HORIZON_BALANCE_COOLDOWN` | Horizon balance cooldown | `10` |
| `PUSHER_HOST` | Soketi host | `host.docker.internal` |
| `PUSHER_BACKEND_HOST` | Soketi backend host | `host.docker.internal` |
| `PUSHER_PORT` | Soketi WebSocket port | `6001` |
| `PUSHER_BACKEND_PORT` | Soketi backend port | `6001` |
| `PUSHER_SCHEME` | Soketi connection scheme | `http` |
| `PUSHER_APP_ID` | Pusher/Soketi app ID | `coolify` |
| `PUSHER_APP_KEY` | Pusher/Soketi app key | (secret) |
| `PUSHER_APP_SECRET` | Pusher/Soketi app secret | (secret) |
| `SSL_MODE` | SSL mode | `off` |
| `PHP_MEMORY_LIMIT` | PHP memory limit | `256M` |
| `PHP_PM_CONTROL` | PHP-FPM process manager | `dynamic` |
| `AUTOUPDATE` | Enable auto-updates | `false` |

### 4. Coolify Realtime Server

The realtime server is a custom container that bundles two Node.js services:

**Port 6001 — Soketi WebSocket server.** A Pusher-compatible WebSocket server that handles real-time event broadcasting for the Coolify UI. When a deployment log streams in, a status changes, or any live update occurs in the browser, Soketi is pushing those events via the Pusher protocol. Laravel broadcasts events on the backend, and Soketi relays them to connected browser clients.

**Port 6002 — Terminal server.** A Node.js WebSocket server (`terminal-server.js`) that powers Coolify's web-based terminal. It uses `node-pty` and xterm.js to proxy SSH terminal sessions. The connection flow is: browser → WebSocket to port 6002 → terminal server authenticates → SSH connection to the target server or container. This is why the realtime container needs access to SSH keys.

**Image:** `ghcr.io/coollabsio/coolify-realtime`

**Current version:** `1.0.10`. This image changes very infrequently — it has stayed at the same version across many Coolify application releases. It is available for both amd64 and aarch64 architectures.

**Source:** The Dockerfile lives at `docker/coolify-realtime/Dockerfile` in the Coolify repository. The terminal server source is at `docker/coolify-realtime/terminal-server.js`. The entrypoint is a shell script (`soketi-entrypoint.sh`) that starts both Soketi and the terminal server.

#### Preferred approach: Docker container (stock image)

The realtime server does not typically require patching and is best run as an unmodified Docker container pulled from the registry.

```nix
virtualisation.oci-containers.containers.coolify-realtime = {
  image = "ghcr.io/coollabsio/coolify-realtime:1.0.10";
  extraOptions = [
    "--add-host=host.docker.internal:host-gateway"
    "--network=coolify"
  ];
  ports = [
    "6001:6001"
    "6002:6002"
  ];
  volumes = [
    "/data/coolify/ssh:/var/www/html/storage/app/ssh"
  ];
  environment = {
    APP_NAME = "Coolify";
    SOKETI_DEBUG = "false";
    SOKETI_DEFAULT_APP_ID = "\${PUSHER_APP_ID}";
    SOKETI_DEFAULT_APP_KEY = "\${PUSHER_APP_KEY}";
    SOKETI_DEFAULT_APP_SECRET = "\${PUSHER_APP_SECRET}";
  };
};
```

This is the recommended approach because:
- The image is small, stable, and rarely updated
- No patching is needed
- It is the tested and known-working configuration
- It avoids dealing with `node-pty` native compilation on NixOS

#### Alternative approach: Native NixOS services

Since the realtime server is just two Node.js processes, it could run natively on NixOS as two systemd services — one for Soketi and one for the terminal server. Soketi is a standalone npm package (`@soketi/soketi`) and may be available in nixpkgs. The terminal server is a single JavaScript file from the Coolify repository.

Potential benefits of running natively:
- No Docker overhead for two small Node.js processes
- Proper systemd service integration, logging, and resource management
- SSH key access is simpler on the host than via volume mounts

Potential drawbacks:
- `node-pty` has native compilation dependencies that can be finicky
- Requires matching the exact Node.js version and dependency tree that Coolify expects
- One more thing to build and maintain outside of the upstream-tested configuration
- Marginal benefit given that Docker is already required for the Coolify app

If the native approach is pursued, the implementation would look approximately like:

```nix
# Soketi
systemd.services.coolify-soketi = {
  description = "Coolify Soketi WebSocket Server";
  after = [ "network.target" ];
  wantedBy = [ "multi-user.target" ];
  environment = {
    SOKETI_DEFAULT_APP_ID = "coolify";
    SOKETI_DEFAULT_APP_KEY = "...";
    SOKETI_DEFAULT_APP_SECRET = "...";
    SOKETI_DEBUG = "false";
  };
  serviceConfig = {
    ExecStart = "${pkgs.soketi}/bin/soketi start";
    Restart = "always";
    DynamicUser = true;
  };
};

# Terminal server
systemd.services.coolify-terminal = {
  description = "Coolify Terminal WebSocket Server";
  after = [ "network.target" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    ExecStart = "${pkgs.nodejs}/bin/node ${coolify-src}/docker/coolify-realtime/terminal-server.js";
    Restart = "always";
    # Needs access to SSH keys
    ReadOnlyPaths = [ "/data/coolify/ssh" ];
  };
};
```

### 5. Docker Engine

Docker is not an optional dependency. Coolify is a container orchestration platform — deploying and managing Docker containers on behalf of its users is its core purpose. The Coolify application container needs access to the Docker socket to create, start, stop, and manage containers.

```nix
virtualisation.docker.enable = true;
```

The Docker network for inter-container communication should also be created:

```nix
systemd.services.coolify-network = {
  description = "Create Coolify Docker network";
  after = [ "docker.service" ];
  requires = [ "docker.service" ];
  before = [ "docker-coolify.service" "docker-coolify-realtime.service" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
  };
  path = [ pkgs.docker ];
  script = ''
    docker network inspect coolify >/dev/null 2>&1 || \
      docker network create --attachable coolify
  '';
};
```

## Networking

When PostgreSQL and Redis run as native NixOS services, the Docker containers need a way to reach them on the host. The recommended approach is `host.docker.internal`, which Docker resolves to the host's gateway address.

This requires `--add-host=host.docker.internal:host-gateway` on each container (set via `extraOptions` in `oci-containers`), and the host services must bind to an address reachable from Docker's bridge network:

- PostgreSQL: `listen_addresses = "127.0.0.1,172.17.0.1"`
- Redis: `bind = "127.0.0.1 172.17.0.1"`
- PostgreSQL authentication must allow connections from Docker's subnet (`172.17.0.0/16`)

When using remote databases, this is not a concern — the containers reach the external hosts via normal network routing.

## Data Directories

Coolify expects certain directories on the host for persistent data:

| Path | Purpose |
|---|---|
| `/data/coolify/source/.env` | Main environment configuration file |
| `/data/coolify/ssh` | SSH keys for server management |
| `/data/coolify/applications` | Application deployment data |
| `/data/coolify/databases` | Database configuration data |
| `/data/coolify/services` | Service configuration data |
| `/data/coolify/backups` | Backup storage |
| `/data/coolify/webhooks-during-maintenance` | Queued webhooks during maintenance |

The NixOS module should ensure these directories exist (via `systemd.tmpfiles.rules` or a pre-start script).

## NixOS Module Interface

The module should expose options following standard NixOS conventions:

```nix
services.coolify = {
  enable = true;

  # Coolify version to deploy
  version = "v4.0.0-beta.468";

  # Realtime server version (changes infrequently)
  realtimeVersion = "1.0.10";

  # Public URL
  appUrl = "https://coolify.example.com";

  # Port configuration
  port = 8000;
  soketiPort = 6001;
  terminalPort = 6002;

  # Database
  database = {
    createLocally = true;          # Provision local PostgreSQL
    host = "host.docker.internal"; # Ignored when createLocally = true
    port = 5432;
    name = "coolify";
    username = "coolify";
    passwordFile = "/run/secrets/coolify-db-password";
  };

  # Redis
  redis = {
    createLocally = true;          # Provision local Redis
    host = "host.docker.internal"; # Ignored when createLocally = true
    port = 6379;
    passwordFile = "/run/secrets/coolify-redis-password";
  };

  # Patching
  patchFiles = {
    # Paths to files to overlay onto the upstream image
    # "container/path" = ./local/path;
  };
  extraDockerfileCommands = ''
    # Additional Dockerfile RUN commands for the patch layer
  '';

  # Secrets
  appKeyFile = "/run/secrets/coolify-app-key";
  pusherAppId = "coolify";
  pusherAppKeyFile = "/run/secrets/coolify-pusher-key";
  pusherAppSecretFile = "/run/secrets/coolify-pusher-secret";

  # Data directory
  dataDir = "/data/coolify";

  # PHP tuning
  phpMemoryLimit = "256M";
  phpPmControl = "dynamic";
  phpPmStartServers = 1;
  phpPmMinSpareServers = 1;
  phpPmMaxSpareServers = 10;

  # Horizon (queue workers)
  horizonBalance = 100;
  horizonMaxProcesses = 10;

  # Realtime server
  realtime = {
    useContainer = true;  # Preferred: use stock Docker image
    # useContainer = false would run Soketi + terminal server natively
  };
};
```

## Project Structure

```
coolify-nixos/
├── flake.nix
├── module.nix                    # NixOS module definition
├── Dockerfile.patch              # Thin layer on top of upstream image
├── patched-files/                # Files to overlay into the image
│   ├── config/
│   │   └── app.php
│   └── ...
└── README.md
```

## Upgrade Process

To upgrade Coolify:

1. Update `services.coolify.version` to the new tag
2. Verify patches still apply cleanly against the new version (the `FROM` line in `Dockerfile.patch` references the version tag)
3. Run `nixos-rebuild switch` — this triggers a rebuild of the patched image
4. The systemd service detects the changed derivation hash and runs `docker build`
5. The `oci-containers` service restarts with the new image

The realtime server version (`services.coolify.realtimeVersion`) is updated independently and changes far less frequently.

## Comparison to Source Patching Approach

This image patching approach differs from the source patching approach (documented separately) in several ways:

| | Image patching | Source patching |
|---|---|---|
| **Base** | Pre-built upstream image from ghcr.io | Upstream source from GitHub |
| **Build time** | Fast — only builds a thin layer | Slow — full `docker build` from source |
| **Patch scope** | Can modify files, add packages, change permissions | Can modify anything including the Dockerfile itself |
| **Rebuild on upgrade** | Fast — Docker pulls new base, rebuilds layer | Slow — full rebuild from scratch |
| **When to use** | Patches are limited to file overrides and package additions | Patches require changes to the build process itself |

Image patching is preferred when the required modifications can be expressed as file overlays and additional commands on top of the stock image. Source patching is necessary when the Dockerfile itself must be changed (e.g., modifying base images, changing build stages, altering the compilation process).
