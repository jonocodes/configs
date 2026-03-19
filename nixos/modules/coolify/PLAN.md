# Coolify on NixOS — Packaging Plan

## Background

Coolify is an open-source, self-hostable PaaS (Platform as a Service) alternative to Vercel, Heroku, and Netlify. It is a Laravel (PHP) application that depends on PostgreSQL, Redis, and Soketi (for websockets). Critically, Coolify doesn't just run inside Docker — it uses Docker as its primary mechanism for deploying and managing applications on behalf of its users. Docker is not an implementation detail that can be swapped out; it is core to Coolify's purpose.

The goal of this project is to package Coolify for NixOS in a way that:

- Applies custom patches to the source before the image is built (not after, on a running container)
- Uses Coolify's own Dockerfile for the build, rather than recreating the build steps in Nix
- Runs locally on a single NixOS machine without requiring CI infrastructure or a private container registry
- Integrates with the NixOS module system so the service can be managed declaratively

## Why patching is needed

Coolify's upstream source assumes a conventional Linux environment (Ubuntu/Debian) and a specific Docker Compose-based deployment model. Running it on NixOS requires modifications to PHP configuration files, Dockerfiles, and docker-compose files to account for NixOS-specific paths, service wiring, and system conventions.

Currently, these patches are applied directly to the already-built Docker image — modifying files inside the running container or on a manually built image. This is fragile: patches are not version-controlled in a structured way, they can be lost when the image is updated, and the process is not reproducible.

## Alternatives considered

### 1. Full native NixOS module (no Docker)

This would mean packaging Coolify entirely as a native NixOS service: running the Laravel application directly with PHP-FPM, wiring up PostgreSQL and Redis via standard NixOS modules, and managing everything through systemd. This is how services like Nextcloud and WordPress are packaged in nixpkgs.

**Why it was rejected:** Coolify is not just a web application — it is a container orchestration tool. Its core functionality depends on Docker to deploy and manage user applications. Removing Docker from Coolify would mean rewriting significant parts of the application. Additionally, running the Laravel control plane natively with `php artisan serve` is not a supported or well-tested configuration upstream. A GitHub discussion exists where someone attempted this for development purposes, but it is not production-ready.

### 2. Rebuild entirely with Nix dockerTools

Nix provides `dockerTools.buildImage` and `dockerTools.buildLayeredImage`, which can produce OCI-compliant container images purely from Nix derivations — no Docker daemon needed at build time. This would mean replicating every step of Coolify's Dockerfile (installing PHP extensions, running Composer, building frontend assets with Node.js, etc.) as Nix build steps.

**Why it was rejected:** Coolify's Dockerfile contains substantial build logic specific to its Laravel + Node.js stack. Translating all of this into Nix derivations would be a large amount of work, would diverge from upstream's tested build process, and would create an ongoing maintenance burden as Coolify evolves. The upstream Dockerfile is the canonical way to build the application, and using it directly means we inherit upstream's tested build pipeline.

### 3. Build in CI, push to a private registry

The standard DevOps approach: a CI pipeline (GitHub Actions, etc.) fetches the source, applies patches, runs `docker build`, and pushes the resulting image to a private container registry. The NixOS configuration then references that image by digest.

**Why it was rejected:** This project targets a single-machine deployment without CI infrastructure. Adding a CI pipeline and private registry introduces operational complexity that is not justified for the use case. This remains a valid option for the future if the deployment grows to multiple machines.

### 4. Use the upstream image with volume-mounted patches

Pull the stock Coolify Docker image from the registry and override specific files by mounting patched versions as Docker volumes. This avoids rebuilding the image entirely.

**Why it was rejected:** This approach is limited to patching individual files and cannot modify the Dockerfile itself or change anything about the build process (PHP extensions, system packages, build steps). Some of the required changes affect the Dockerfile and docker-compose files, which must be present at build time, not runtime.

### 5. Use oci-containers with the upstream image as-is

NixOS provides `virtualisation.oci-containers` for running pre-built Docker images as systemd services. Tools like `compose2nix` can auto-generate this configuration from a docker-compose.yml. Arion provides a similar capability with deeper NixOS module integration.

**Why it was rejected as the sole approach:** These tools are designed for running unmodified upstream images. They solve the "manage containers declaratively" problem but do not address the need to patch source files before the image is built. However, `oci-containers` is still used in the chosen approach to manage the running container after it has been built.

## Chosen approach

The chosen approach splits the work into two phases:

### Phase 1: Patch the source (pure Nix, runs in the sandbox)

Nix fetches Coolify's source from GitHub at a pinned revision, then applies patch files using `applyPatches`. This step is pure, deterministic, and cached by Nix. The output is a patched source tree in the Nix store.

```nix
coolify-patched-src = pkgs.applyPatches {
  src = pkgs.fetchFromGitHub {
    owner = "coollabsio";
    repo = "coolify";
    rev = "v4.0.0-beta.374";
    hash = "sha256-...";
  };
  name = "coolify-patched-source";
  patches = [
    ./patches/0001-dockerfile-changes.patch
    ./patches/0002-php-fixes.patch
    ./patches/0003-compose-adjustments.patch
  ];
};
```

### Phase 2: Build the Docker image (impure, runs on the machine)

A systemd oneshot service runs `docker build` against the patched source tree, using Coolify's own Dockerfile. This produces a local Docker image. The service is ordered to run before the Coolify container starts, and includes a condition check so it only rebuilds when the patched source derivation changes.

```nix
systemd.services.coolify-build = {
  description = "Build Coolify Docker image from patched source";
  after = [ "docker.service" ];
  requires = [ "docker.service" ];
  path = [ pkgs.docker ];
  unitConfig.ConditionPathExists =
    "!%t/coolify-built-${coolify-patched-src.name}";
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
  };
  script = ''
    docker build \
      -t coolify-local:latest \
      -f ${coolify-patched-src}/docker/production/Dockerfile \
      ${coolify-patched-src}
    touch /run/coolify-built-${coolify-patched-src.name}
  '';
};
```

### Phase 3: Run the container (declarative, via oci-containers)

The locally-built image is run using NixOS's `oci-containers` module, with a systemd dependency ensuring the build completes first.

```nix
virtualisation.oci-containers.backend = "docker";
virtualisation.oci-containers.containers.coolify = {
  image = "coolify-local:latest";
  ports = [ "8000:8000" ];
  volumes = [
    "/data/coolify:/data/coolify"
    "/var/run/docker.sock:/var/run/docker.sock"
  ];
  environment = {
    # Coolify environment variables
  };
};

systemd.services.docker-coolify.after = [ "coolify-build.service" ];
systemd.services.docker-coolify.requires = [ "coolify-build.service" ];
```

## Known tradeoffs of this approach

**Image builds happen at runtime, not at Nix build time.** When `nixos-rebuild switch` runs and the patches have changed, the systemd service triggers `docker build`, which can take several minutes. The Coolify service is unavailable during this time. By contrast, a fully native NixOS service (like Nextcloud) would be pre-built and start immediately.

**No binary cache.** The Docker image is built locally and cannot be shared via a Nix binary cache. If this were deployed to multiple machines, each would need to build the image independently. For a single-machine deployment, this is acceptable.

**Docker layer cache dependency.** Rebuild speed depends on Docker's layer cache. If the cache is cleared (disk cleanup, Docker daemon reset), the next build starts from scratch. The Nix portion (fetching source and applying patches) is always cached in the Nix store and unaffected.

**First boot is slow.** On a fresh machine, the first `docker build` must download base images and run the full build. Subsequent rebuilds with minor patch changes benefit from Docker's layer caching.

## Project structure

```
coolify-nixos/
├── flake.nix
├── module.nix              # NixOS module (services.coolify)
├── package.nix             # Source fetching and patching
└── patches/
    ├── 0001-dockerfile-changes.patch
    ├── 0002-php-fixes.patch
    └── 0003-compose-adjustments.patch
```

Patches are generated with `git format-patch` against the pinned upstream revision. When upgrading to a new Coolify version, the patches are rebased onto the new revision. Any patches that no longer apply cleanly indicate upstream changes that need review.

## Future considerations

- If the deployment expands to multiple machines, moving the Docker build to CI and pushing to a private registry would eliminate the runtime build step and its associated downtime.
- If Coolify's upstream becomes more modular or provides better support for non-Docker installation, revisiting the fully native NixOS module approach may become viable.
- The NixOS module could be extended with options for database backend selection (`services.coolify.database = "postgresql"`) and integration with Nix-managed PostgreSQL and Redis services instead of containerized ones.