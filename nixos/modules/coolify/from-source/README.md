# from-source

Pinned-source NixOS module for self-hosting
[Coolify v4.x](https://coolify.io).

## Status

**Working.** Builds and runs on lute.

## Usage

```nix
imports = [ ../../modules/coolify/from-source ];

services.coolify = {
  enable = true;
  
  # Version to deploy (optional, defaults to 4.0.0-beta.468)
  # version = "4.0.0-beta.500";
  
  # Hash is required when changing version (nix will tell you the correct value)
  # hash = "sha256-abc123...";
  
  openFirewall = true;
};
```

To upgrade Coolify:
1. Update `services.coolify.version` to the new version
2. Run `nixos-rebuild switch` — Nix will error and tell you the correct hash
3. Update `services.coolify.hash` with the value from the error
4. Run `nixos-rebuild switch` again

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the module |
| `version` | string | `"4.0.0-beta.468"` | Coolify version (without 'v' prefix) |
| `hash` | string | *(hash)* | Nix store hash of fetched source |
| `nixosOverlay` | bool | `true` | Build patched image with NixOS support |
| `openFirewall` | bool | `false` | Open TCP 80,443,6001,6002,8000 + UDP 443 |
| `upgradeCalendar` | string | `"Sun 03:00"` | Upgrade timer schedule |

## How it works

1. `fetchFromGitHub` pins Coolify source at a specific version/tag
2. A Nix derivation copies compose files from the pinned source
3. Patched PHP files (from `./patched/`) are overlaid onto the source:
   - `constants.php` — adds `'nixos'` to `SUPPORTED_OS`
   - `InstallPrerequisites.php` — adds NixOS branch
   - `InstallDocker.php` — adds NixOS branch
4. A Dockerfile is generated that layers the patched files onto the official image
5. At service start, the setup service copies compose files, generates secrets, and builds the Docker image
6. `docker compose` runs the containers

## Patched files

The `patched/` directory contains the modified PHP files with NixOS support:

| File | Change |
|------|--------|
| `constants.php` | Adds `'nixos'` to `SUPPORTED_OS` |
| `InstallPrerequisites.php` | Adds NixOS branch (verify tools exist) |
| `InstallDocker.php` | Adds NixOS branch (check Docker is available) |

Full file copies are used instead of `.patch` files because PHP's `$variable` syntax makes inline patch strings error-prone in Nix. To see what changed, diff against upstream:
```bash
diff -u <(curl -sSL https://raw.githubusercontent.com/coollabsio/coolify/v4.0.0-beta.468/path/to/file.php) \
       ./patched/file.php
```

## Systemd units

| Unit | Purpose |
|------|---------|
| `coolify-setup.service` | SSH key gen, secrets, Docker image build |
| `coolify.service` | Main Coolify docker-compose service |
| `coolify-upgrade.timer` | Weekly upgrade check |
| `coolify-upgrade.service` | Runs the upgrade |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      NixOS Host                              │
│                                                             │
│  ┌─────────────────┐      ┌──────────────────────────────┐ │
│  │  coolify-setup   │─────▶│  Docker Image (coolify-nixos)│ │
│  │    (oneshot)     │      │  - Coolify v4.x + NixOS patches│
│  └─────────────────┘      └──────────────────────────────┘ │
│           │                         │                     │
│           ▼                         ▼                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              docker-compose                         │   │
│  │  ┌─────────┐ ┌──────────┐ ┌─────────┐ ┌─────────┐  │   │
│  │  │coolify │ │postgres  │ │ redis   │ │ soketi  │  │   │
│  │  │(nginx) │ │          │ │         │ │         │  │   │
│  │  └─────────┘ └──────────┘ └─────────┘ └─────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```
