# from-compose

Docker Compose-based NixOS module for self-hosting
[Coolify v4.x](https://coolify.io).

This is the simplest approach: it mirrors the official manual install by
downloading compose files from Coolify's CDN and running `docker compose up`.
All four services (app, PostgreSQL, Redis, realtime) run as Docker containers
managed by compose.

NixOS support is patched onto the official image by cloning the
[rockofox/coolify](https://github.com/rockofox/coolify)
`feature/nixos-support` branch (PR #7170) and layering the changed files
on top. An additional PHP script patches `InstallPrerequisites.php` (a gap
in that PR).

## Status

Working. This was the first approach developed and is the most battle-tested.
It is currently used on zeeba (via the compose-based install).

## Usage

```nix
imports = [ ../../modules/coolify/from-compose ];

services.coolify = {
  enable = true;
  openFirewall = true;  # if firewall is enabled on this host

  # Optional: pin the base image by digest
  # imageDigest = "sha256:5ac58c4f2aed0fa6e9c093947303d266babfcaf18cac1b6c6d671d1093b38c33";
};
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `false` | Enable the module |
| `imageDigest` | string or null | `null` | Pin the Docker image by digest. Uses `latest` when null |
| `nixosOverlay` | bool | `true` | Build patched image with NixOS support |
| `openFirewall` | bool | `false` | Open TCP 80, 443, 6001, 6002, 8000 and UDP 443 |
| `upgradeCalendar` | string | `"Sun 03:00"` | systemd OnCalendar for the weekly upgrade timer |

## How it works

1. **Setup service** downloads compose files and `.env` from CDN (first boot
   only), generates SSH keys and secrets, builds the NixOS overlay image.
2. **Coolify service** runs `docker compose up` with the official compose
   files (plus an override that swaps in the patched image).
3. **Upgrade timer** re-downloads compose files weekly, rebuilds the overlay,
   and recreates containers.

## Systemd units

| Unit | Purpose |
|---|---|
| `coolify-setup.service` | First-time setup (idempotent) |
| `coolify.service` | Runs `docker compose up` |
| `coolify-upgrade.service` | Re-downloads compose files, rebuilds overlay |
| `coolify-upgrade.timer` | Triggers upgrade weekly |

## Files

| File | Purpose |
|---|---|
| `default.nix` | NixOS module |
| `Dockerfile.overlay` | Multi-stage build: clones PR branch, copies patches onto official image |
| `docker-compose.override.yml` | Points compose at `coolify-nixos:local` |
| `patch-prerequisites.php` | Patches `InstallPrerequisites.php` (gap in PR #7170) |

## Tradeoffs

- Compose files are downloaded from CDN at runtime (not pinned in Nix)
- NixOS patches are applied by cloning a fork at Docker build time (fragile
  if the fork diverges or the PHP string match breaks)
- All services run in Docker (no native NixOS PostgreSQL/Redis)
- Simple and close to the official install process
