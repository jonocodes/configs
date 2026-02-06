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

## Running with docker compose directly (no NixOS config)

You can skip the nix module entirely and run everything with plain docker
compose.

### Prerequisites

You need the standard Coolify directory layout at `/data/coolify/source/`.
This is what Coolify's official
[manual install](https://coolify.io/docs/get-started/installation#manual-installation)
creates. If you don't have it yet:

```bash
# Create the directory structure
mkdir -p /data/coolify/{source,ssh/keys,ssh/mux,applications,databases,backups,services,proxy/dynamic,webhooks-during-maintenance}

# Download compose files and env template from Coolify's CDN
cd /data/coolify/source
curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.yml    -o docker-compose.yml
curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.prod.yml -o docker-compose.prod.yml
curl -fsSL https://cdn.coollabs.io/coolify/.env.production         -o .env

# Generate an SSH key for Coolify to manage the host
ssh-keygen -t ed25519 -N "" -C "root@coolify" \
  -f /data/coolify/ssh/keys/id.root@host.docker.internal
cat /data/coolify/ssh/keys/id.root@host.docker.internal.pub >> /root/.ssh/authorized_keys

# Fill in empty secrets in .env (APP_ID, APP_KEY, DB_PASSWORD, etc.)
# You can generate them with: openssl rand -hex 16  (or -base64 32)

# Create the docker network
docker network create --attachable coolify

# Set ownership
chown -R 9999:root /data/coolify
chmod -R 700 /data/coolify
```

This is not a git clone -- the compose files are standalone downloads from
Coolify's CDN. They reference the official Docker images which get pulled
on first `docker compose up`.

### Steps

**1. Copy the overlay files into the Coolify source directory:**

```bash
cd /data/coolify/source
cp ~/configs/nixos/hosts/zeeba/coolify/Dockerfile.overlay .
cp ~/configs/nixos/hosts/zeeba/coolify/docker-compose.override.yml .
```

**2. Build the overlay image:**

```bash
docker build -t coolify-nixos:local -f Dockerfile.overlay .
```

**3. Start everything:**

```bash
docker compose --env-file .env \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.override.yml \
  up -d --remove-orphans --force-recreate
```

**To upgrade later**, rebuild with `--pull` to grab the latest base image:

```bash
docker build --pull -t coolify-nixos:local -f Dockerfile.overlay .
docker compose --env-file .env \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.override.yml \
  up -d --remove-orphans --force-recreate
```

**To roll back to stock** (once PR #7170 ships), just stop using the override:

```bash
rm /data/coolify/source/Dockerfile.overlay
rm /data/coolify/source/docker-compose.override.yml
docker compose --env-file .env \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  up -d --pull always --remove-orphans --force-recreate
docker rmi coolify-nixos:local
```

## Activating via NixOS (alternative)

If you prefer the nix-managed approach, swap the import in
`nixos/hosts/zeeba/default.nix`:

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
