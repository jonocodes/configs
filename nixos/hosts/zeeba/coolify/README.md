# Coolify on NixOS (zeeba) -- PR #7170 Overlay

Coolify does not ship with NixOS support. The OS validation rejects NixOS
servers. [PR #7170](https://github.com/coollabsio/coolify/pull/7170) adds
NixOS detection and is the basis for this workaround.

## How it works

Instead of building Coolify from source, we patch the official Docker image:

1. `Dockerfile.overlay` clones the PR branch in a throwaway stage, then copies
   only the 6 changed PHP/Blade files on top of `ghcr.io/coollabsio/coolify:latest`.
2. `docker-compose.override.yml` tells compose to use our local `coolify-nixos:local`
   image instead of pulling from the registry.
3. `coolify-next.nix` wires this into systemd so the image is built during
   `coolify-setup` and the override file is included in every compose invocation.

The overlay build takes seconds -- it just downloads the git branch and copies
files, no PHP/Node compilation required.

## Activating

In `nixos/hosts/zeeba/default.nix`, swap the import:

```nix
# before
imports = [ ./coolify-opus46.nix ... ];

# after
imports = [ ./coolify-next.nix ... ];
```

Then rebuild and start:

```bash
sudo nixos-rebuild switch
sudo systemctl start coolify-setup   # first time only
# Coolify is now at http://zeeba:8000
```

## Manual usage

If you prefer to run things by hand (or need to debug), the supporting files
are copied to `/data/coolify/source/` during setup:

```bash
cd /data/coolify/source

# Build the overlay image
docker build -t coolify-nixos:local -f Dockerfile.overlay .

# Start everything
docker compose --env-file .env \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.override.yml \
  up -d --remove-orphans --force-recreate
```

## Upgrading

A weekly timer (`coolify-upgrade.timer`) re-downloads compose files from the
CDN, rebuilds the overlay on top of the latest official image, and recreates
containers. To trigger it manually:

```bash
sudo systemctl start coolify-upgrade
```

## Rollback (after PR #7170 merges)

Once the PR ships in an official Coolify release, the overlay is no longer
needed. To go back to stock:

1. Switch the import in `default.nix` back to `coolify-opus46.nix`:
   ```nix
   imports = [ ./coolify-opus46.nix ... ];
   ```
2. Rebuild:
   ```bash
   sudo nixos-rebuild switch
   sudo systemctl restart coolify
   ```
3. Clean up the local image and override (optional):
   ```bash
   rm /data/coolify/source/Dockerfile.overlay
   rm /data/coolify/source/docker-compose.override.yml
   docker rmi coolify-nixos:local
   ```

The `coolify-opus46.nix` module uses `--pull always` which will pull the
official image (now with NixOS support baked in), so everything just works.

## Files

| File | Purpose |
|------|---------|
| `Dockerfile.overlay` | Multi-stage build: clones PR, copies patches onto official image |
| `docker-compose.override.yml` | Points compose at `coolify-nixos:local` |
| `README.md` | This file |
| `../coolify-next.nix` | NixOS module that integrates the above into systemd |
