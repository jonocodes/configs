# coolify

NixOS modules for self-hosting [Coolify v4.x](https://coolify.io).

Three approaches are provided, each with different tradeoffs. Pick one and
import it in your host configuration:

```nix
imports = [ ../../modules/coolify/from-compose ];  # or from-image, from-source
services.coolify.enable = true;
```

## Approaches

| Approach | How it works | Status |
|---|---|---|
| [from-compose](from-compose/) | Downloads compose files from CDN, runs `docker compose up`. All services in Docker. Closest to the official install. | Working (zeeba) |
| [from-source](from-source/) | Pins source via `fetchFromGitHub`, bundles patched PHP files, still uses docker-compose. | Working (lute) |
| [from-image](from-image/) | Native PostgreSQL/Redis, only app + realtime in Docker via `oci-containers`. | Implemented, builds (lute) |

## Background

Coolify doesn't officially support NixOS. All three approaches patch the
upstream image to add NixOS to `SUPPORTED_OS` and handle the prerequisite
checks that assume Ubuntu/Debian. See [PLAN.md](PLAN.md) for the full
design rationale and alternatives considered.

## NixOS patches needed

Coolify's PHP code checks the host OS and installs prerequisites (Docker,
etc.) assuming a conventional Linux distro. On NixOS these checks need to
be patched to verify tools exist rather than trying to install them.
PR [#7170](https://github.com/coollabsio/coolify/pull/7170) adds partial
NixOS support upstream; these modules fill the remaining gaps.

Key files patched:
- `constants.php` -- adds `'nixos'` to `SUPPORTED_OS`
- `InstallPrerequisites.php` -- NixOS branch that verifies tools exist
- `InstallDocker.php` -- NixOS branch that checks Docker is available
