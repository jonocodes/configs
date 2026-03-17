# coolify NixOS module

NixOS module for self-hosting [Coolify v4.x](https://coolify.io). Manages
Coolify via systemd + docker compose, following the official manual install
layout at `/data/coolify/`.

## TODO

make nix tests?


## Background

Coolify does not ship with NixOS support. Its OS detection rejects NixOS
hosts, and its prerequisites installer has no NixOS branch. Two upstream
items are relevant:

- **[PR #7170](https://github.com/coollabsio/coolify/pull/7170)** — adds
  NixOS OS detection. Not yet merged as of 2026-03.
- **[rockofox/coolify](https://github.com/rockofox/coolify)** — the fork
  that PR #7170 comes from (`feature/nixos-support` branch).

Until the PR ships in an official release, this module builds a patched
Docker image that layers the PR's changed files on top of the official
`ghcr.io/coollabsio/coolify:latest`.

## How the overlay patch works

The overlay is a fast multi-stage Docker build — it doesn't recompile PHP
or Node, just copies a handful of files:

1. **`Dockerfile.overlay`** — clones the `feature/nixos-support` branch
   from `rockofox/coolify` in a throwaway stage, then copies the 6 changed
   PHP/Blade files onto the official image.
2. **`patch-prerequisites.php`** — a gap in PR #7170: it adds NixOS to
   `SUPPORTED_OS` but doesn't add a branch to `InstallPrerequisites::handle()`,
   so NixOS passes OS validation and then hits "Unsupported OS type for
   prerequisites installation". This script patches that file at image-build
   time to add a NixOS branch that verifies tools exist rather than trying
   to install them imperatively.
3. **`docker-compose.override.yml`** — tells compose to use
   `coolify-nixos:local` instead of pulling from the registry.

The result is tagged `coolify-nixos:local`. The weekly upgrade timer
rebuilds it with `--pull` to pick up new official releases.

## Module options

| Option | Type | Default | Description |
|---|---|---|---|
| `services.coolify.enable` | bool | `false` | Enable the module |
| `services.coolify.nixosOverlay` | bool | `true` | Build and use the patched image. Set to `false` once PR #7170 ships natively |
| `services.coolify.openFirewall` | bool | `false` | Open TCP 80, 443, 6001, 6002, 8000 and UDP 443 |
| `services.coolify.upgradeCalendar` | string | `"Sun 03:00"` | systemd OnCalendar for the weekly upgrade timer |

The module does **not** enable Docker, SSH, or configure the firewall by
default — those are expected to be handled by the host config (e.g.
`common-nixos.nix` already enables Docker and SSH).

## Usage

```nix
# in a host's default.nix
imports = [ ../../modules/coolify ];

services.coolify.enable = true;

# optional — only needed if firewall is enabled on this host
services.coolify.openFirewall = true;
```

First boot: after `nixos-rebuild switch`, the `coolify-setup` service runs
once and:
- generates an SSH key at `/data/coolify/ssh/keys/id.root@host.docker.internal`
  and appends the public key to `/root/.ssh/authorized_keys`
- downloads `docker-compose.yml`, `docker-compose.prod.yml`, and `.env`
  from Coolify's CDN into `/data/coolify/source/`
- generates random secrets for any empty values in `.env`
- creates the `coolify` Docker network
- (if `nixosOverlay = true`) copies overlay files and builds
  `coolify-nixos:local`

Coolify is then available at `http://<host>:8000`.

## Systemd units

| Unit | Type | Purpose |
|---|---|---|
| `coolify-setup.service` | oneshot, RemainAfterExit | First-time setup (idempotent) |
| `coolify.service` | oneshot, RemainAfterExit | Runs `docker compose up` |
| `coolify-upgrade.service` | oneshot | Re-downloads compose files, rebuilds overlay, recreates containers |
| `coolify-upgrade.timer` | timer | Triggers `coolify-upgrade` weekly |

```bash
# Trigger an upgrade manually
sudo systemctl start coolify-upgrade

# Re-run setup (e.g. after a wipe of /data/coolify)
sudo systemctl restart coolify-setup
```

## Removing the overlay (once PR #7170 ships)

When Coolify releases native NixOS support:

1. Set `services.coolify.nixosOverlay = false` in the host config.
2. Run `nixos-rebuild switch`.
3. Clean up (optional):
   ```bash
   rm /data/coolify/source/Dockerfile.overlay
   rm /data/coolify/source/patch-prerequisites.php
   rm /data/coolify/source/docker-compose.override.yml
   docker rmi coolify-nixos:local
   ```

## Current state on zeeba (2026-03)

Zeeba is **not** using this module yet. Coolify there was installed
manually via the official install script and is kept alive by Docker's
`restart: always` policy — not by systemd or NixOS.

The zeeba-specific files at `hosts/zeeba/coolify*` were earlier experiments:

| File | Status | Notes |
|---|---|---|
| `coolify-opus46.nix` | superseded | Stock compose module, no NixOS patch |
| `coolify-next.nix` | superseded | Per-host version of this module |
| `coolify-pvul.nix` | abandoned | Old `docker run`-per-service approach |
| `coolify-build/` | **active on zeeba** | Builds from `jonocodes/coolify` fork; the running image is `coolify-nixos:jono` |
| `coolify/` | reference | Overlay support files (copied into this module) |

The `coolify-build/` approach (full source build from jono's fork at a
pinned commit) works but is slow and will go stale as the fork diverges.
Migrating zeeba to this module is the intended next step.

## Files

| File | Purpose |
|---|---|
| `default.nix` | NixOS module |
| `Dockerfile.overlay` | Multi-stage build: clones PR branch, copies patches onto official image |
| `docker-compose.override.yml` | Points compose at `coolify-nixos:local` |
| `patch-prerequisites.php` | Fixes `InstallPrerequisites.php` (gap in PR #7170) |
| `README.md` | This file |
