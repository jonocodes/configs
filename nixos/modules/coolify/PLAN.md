# Coolify on NixOS

## Overview

This directory contains NixOS modules for self-hosting [Coolify v4.x](https://coolify.io).

## Modules

### `from-source`

Pinned source approach — fetches Coolify from GitHub at a specific version, overlays patched PHP files, and builds a local Docker image.

- **Pros:** Compose files pinned in Nix (reproducible, no CDN at runtime)
- **Cons:** Docker image built at service start (first boot is slow)

```nix
imports = [ ../../modules/coolify/from-source ];
services.coolify = {
  enable = true;
  # version = "4.0.0-beta.468";  # optional
  # hash = "sha256-...";          # required when changing version
  openFirewall = true;
};
```

### `from-compose`

Docker Compose approach — downloads compose files from Coolify's CDN, builds a NixOS-patched overlay image.

- **Pros:** Simpler, mirrors official install exactly
- **Cons:** CDN dependency at first boot, no version pinning

```nix
imports = [ ../../modules/coolify/from-compose ];
services.coolify = {
  enable = true;
  openFirewall = true;
};
```

### `from-image`

OCI containers approach — uses NixOS's `oci-containers` with native PostgreSQL and Redis.

- **Pros:** Native NixOS services for databases (cleaner), no runtime Docker build
- **Cons:** Still needs overlay image for NixOS patches

```nix
imports = [ ../../modules/coolify/from-image ];
services.coolify = {
  enable = true;
  openFirewall = true;
};
```

## Why patching is needed

Coolify doesn't support NixOS out of the box. The modules add NixOS to `SUPPORTED_OS` and provide branch logic in:
- `bootstrap/helpers/constants.php` — adds `'nixos'`
- `app/Actions/Server/InstallPrerequisites.php` — verifies tools exist
- `app/Actions/Server/InstallDocker.php` — verifies Docker is available

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      NixOS Host                          │
│                                                         │
│  ┌─────────────────┐      ┌─────────────────────────┐  │
│  │  coolify-setup  │─────▶│  Docker Image (overlay)  │  │
│  │    (oneshot)    │      │  - Coolify + NixOS patches│ │
│  └─────────────────┘      └─────────────────────────┘  │
│           │                         │                   │
│           ▼                         ▼                   │
│  ┌───────────────────────────────────────────────┐    │
│  │              docker-compose                     │    │
│  │  ┌─────────┐ ┌────────┐ ┌────────┐ ┌──────┐ │    │
│  │  │coolify  │ │postgres │ │ redis  │ │soketi│ │    │
│  │  └─────────┘ └────────┘ └────────┘ └──────┘ │    │
│  └───────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Upgrading (from-source)

1. Update `services.coolify.version` in your host config
2. Run `nixos-rebuild switch` — Nix will error with the correct hash
3. Update `services.coolify.hash` with the provided value
4. Run `nixos-rebuild switch` again

## Systemd Units

All modules create:
- `coolify-setup.service` — SSH keys, secrets, Docker image build
- `coolify.service` — Main Coolify docker-compose service
- `coolify-upgrade.timer` + `coolify-upgrade.service` — Weekly upgrade check
