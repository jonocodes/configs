# Coolify Build from Source

Build Coolify from the jonocodes/coolify-nix fork instead of patching the official image.

**Repo:** https://github.com/jonocodes/coolify-nix
**Branch:** `jono/nix-with-compose`

## Notes

- The build script overrides `POSTGRES_VERSION=16` because Alpine 3.23 dropped PostgreSQL 15
- On NixOS, the script works around a docker buildx plugin bug by calling the buildx binary directly

## Prerequisites

Same as the overlay approach - you need the standard Coolify directory layout at `/data/coolify/source/`. See `../coolify/README.md` for setup instructions.

## Steps

**1. Copy the override file into the Coolify source directory:**

```bash
cp ~/configs/nixos/hosts/zeeba/coolify-build/docker-compose.override.yml /data/coolify/source/
```

**2. Build the image from source:**

```bash
~/configs/nixos/hosts/zeeba/coolify-build/build.sh
```

**3. Start everything:**

```bash
cd /data/coolify/source
docker compose --env-file .env \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.override.yml \
  up -d --remove-orphans --force-recreate
```

## Upgrading

Re-run the build script to pull the latest from the branch and rebuild:

```bash
~/configs/nixos/hosts/zeeba/coolify-build/build.sh
docker compose --env-file .env \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.override.yml \
  up -d --remove-orphans --force-recreate
```

## Files

| File | Purpose |
|------|---------|
| `build.sh` | Clones the repo and builds the Docker image |
| `docker-compose.override.yml` | Points compose at `coolify-nixos:local` |
| `README.md` | This file |
