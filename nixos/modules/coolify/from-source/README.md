# from-source

Pinned-source NixOS module for self-hosting
[Coolify v4.x](https://coolify.io).

This approach pins the Coolify source via `fetchFromGitHub` so that compose
files and the `.env` template come from the Nix store (not the CDN). NixOS
patches are pre-built PHP files in `./patched/` that are exact copies of the
upstream files with NixOS branches added.

## Status

Work in progress. Builds and runs on lute (tested 2026-03-16). See the TODO
list in `default.nix` for remaining work.

## Usage

```nix
imports = [ ../../modules/coolify/from-source ];

services.coolify = {
  enable = true;
  openFirewall = true;
};
```

## How it works

1. `fetchFromGitHub` pins Coolify source at `v4.0.0-beta.468` with a hash.
2. A Nix derivation (`coolify-patched`) copies compose files from the pinned
   source and bundles the pre-patched PHP files.
3. At service start, the setup service copies compose files from the Nix
   store (not CDN), generates secrets, and builds a Docker image that layers
   the 3 patched PHP files onto the official image.
4. Docker compose runs the containers as in the compose approach.

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `false` | Enable the module |
| `nixosOverlay` | bool | `true` | Build patched image with NixOS support |
| `openFirewall` | bool | `false` | Open TCP 80, 443, 6001, 6002, 8000 and UDP 443 |
| `upgradeCalendar` | string | `"Sun 03:00"` | systemd OnCalendar for upgrade timer |

## Patched files

The `patched/` directory contains complete PHP files from `v4.0.0-beta.468`
with NixOS support added:

| File | Change |
|---|---|
| `constants.php` | Adds `'nixos'` to `SUPPORTED_OS` |
| `InstallPrerequisites.php` | Adds NixOS branch (verify tools exist) |
| `InstallDocker.php` | Adds NixOS branch (check Docker is available) |

## Upgrading

To bump the Coolify version:

1. Update `version` and `hash` in `default.nix`
2. Diff the new upstream PHP files against the ones in `patched/`
3. Re-apply the NixOS additions to the new versions
4. `nixos-rebuild switch`

## Tradeoffs vs from-compose

- Compose files are pinned in Nix (reproducible, no CDN dependency)
- NixOS patches fail at `nixos-rebuild` time if files are missing (not at boot)
- Docker image version is pinned (not `latest`)
- Requires manual work when upgrading (updating patched files)
- Still uses docker-compose for orchestration
