# NixOS module for self-hosting Coolify v4.x (v2 — pinned source)
#
# Follows the official manual installation layout at /data/coolify/.
# Source is pinned via fetchFromGitHub — compose files and the .env
# template come from the pinned checkout, not the CDN.
#
# NixOS patches (OS detection + prerequisites) are pre-built PHP files
# in ./patched/ that match the pinned version. To upgrade Coolify,
# bump `version` + `hash` and update the patched files if needed.
#
# TODO: This module is a work-in-progress. Remaining work:
#
#   - The patched PHP files in ./patched/ are full copies of the upstream
#     files from v4.0.0-beta.468 with NixOS branches added. When bumping
#     `version`, diff the new upstream files against these and re-apply
#     the NixOS additions. Consider generating a proper .patch file to
#     make version bumps easier.
#
#   - The docker build still happens at service start (needs the daemon).
#     Explore using pkgs.dockerTools.buildLayeredImage to build the
#     overlay image as a Nix derivation (no Docker daemon needed at boot).
#
#   - Add a `version` option so hosts can override the pinned version
#     without editing the module.
#
#   - Add a verification step that compares the patched files against the
#     upstream originals at build time (e.g. diff the unpatched sections)
#     to catch drift when the version is bumped.
#
#   - Once PR #7170 lands upstream, remove the NixOS patches entirely
#     and simplify to just pinned source + compose files.
#
# Minimal usage:
#   imports = [ ../../modules/coolify/from-source ];
#   services.coolify.enable = true;

{ config, lib, pkgs, ... }:

let
  cfg = config.services.coolify;

  # ── Pinned Coolify source ────────────────────────────────────────────
  version = "4.0.0-beta.468";
  gitTag  = "v${version}";          # git uses "v" prefix, Docker does not

  coolify-src = pkgs.fetchFromGitHub {
    owner = "coollabsio";
    repo  = "coolify";
    rev   = gitTag;
    hash  = "sha256-xRwNEKBLJ/YtNaboWX/5JVp5pWr1JYCxxxHYjAT1Yio=";
  };

  # ── Build derivation: compose files from source + patched PHP ────────
  coolify-patched = pkgs.stdenv.mkDerivation {
    name = "coolify-patched-${gitTag}";
    src  = coolify-src;

    phases = [ "unpackPhase" "installPhase" ];

    installPhase = ''
      mkdir -p $out/compose $out/patched-php

      # Compose files and .env template from pinned source
      cp docker-compose.yml       $out/compose/
      cp docker-compose.prod.yml  $out/compose/
      cp .env.production          $out/compose/.env.production

      # Pre-patched PHP files with NixOS support
      cp ${./patched/constants.php}            $out/patched-php/constants.php
      cp ${./patched/InstallPrerequisites.php} $out/patched-php/InstallPrerequisites.php
      cp ${./patched/InstallDocker.php}        $out/patched-php/InstallDocker.php
    '';
  };

  # ── Dockerfile (generated, layers patches onto official image) ───────
  dockerfileContent = ''
    FROM ghcr.io/coollabsio/coolify:${version}

    COPY --chown=9999:9999 constants.php \
      /var/www/html/bootstrap/helpers/constants.php

    COPY --chown=9999:9999 InstallPrerequisites.php \
      /var/www/html/app/Actions/Server/InstallPrerequisites.php

    COPY --chown=9999:9999 InstallDocker.php \
      /var/www/html/app/Actions/Server/InstallDocker.php
  '';

  # ── Compose override (use local patched image) ──────────────────────
  composeOverrideContent = ''
    services:
      coolify:
        image: coolify-nixos:local
  '';

in {

  options.services.coolify = {

    enable = lib.mkEnableOption "Coolify PaaS (v4.x)";

    nixosOverlay = lib.mkOption {
      type        = lib.types.bool;
      default     = true;
      description = ''
        Build and use a patched Coolify image that adds NixOS OS-detection
        support (upstream PR #7170). Required until Coolify ships this
        natively. Set to false to use the official unpatched image.
      '';
    };

    openFirewall = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = ''
        Open the firewall ports Coolify needs:
        TCP 80, 443, 6001, 6002, 8000 and UDP 443.
      '';
    };

    upgradeCalendar = lib.mkOption {
      type        = lib.types.str;
      default     = "Sun 03:00";
      description = "systemd OnCalendar expression for the weekly upgrade timer.";
    };

  };

  config = lib.mkIf cfg.enable {

    # ── Directory structure (mirrors official manual install) ────────────
    systemd.tmpfiles.rules = [
      "d /data/coolify 0700 root root -"
      "d /data/coolify/source 0700 root root -"
      "d /data/coolify/ssh 0700 root root -"
      "d /data/coolify/ssh/keys 0700 root root -"
      "d /data/coolify/ssh/mux 0700 root root -"
      "d /data/coolify/applications 0700 root root -"
      "d /data/coolify/databases 0700 root root -"
      "d /data/coolify/backups 0700 root root -"
      "d /data/coolify/services 0700 root root -"
      "d /data/coolify/proxy 0700 root root -"
      "d /data/coolify/proxy/dynamic 0700 root root -"
      "d /data/coolify/webhooks-during-maintenance 0700 root root -"
    ];

    # ── One-shot first-time setup ────────────────────────────────────────
    systemd.services.coolify-setup = {
      description = "Coolify first-time setup";
      after       = [ "docker.service" "network-online.target" ];
      wants       = [ "docker.service" "network-online.target" ];
      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
      };
      path   = with pkgs; [ openssl docker coreutils gnused gnugrep bash openssh ];
      script = ''
        set -euo pipefail

        SOURCE="/data/coolify/source"
        ENV_FILE="$SOURCE/.env"
        SSH_KEY="/data/coolify/ssh/keys/id.root@host.docker.internal"

        # SSH key for Coolify to manage this host
        if [ ! -f "$SSH_KEY" ]; then
          echo "Generating Coolify SSH key..."
          ssh-keygen -f "$SSH_KEY" -t ed25519 -N "" -C "root@coolify"
          mkdir -p /root/.ssh
          chmod 700 /root/.ssh
          cat "$SSH_KEY.pub" >> /root/.ssh/authorized_keys
          chmod 600 /root/.ssh/authorized_keys
        fi

        # Compose files from pinned source (always overwrite to match config)
        echo "Installing compose files from pinned source (${gitTag})..."
        cp ${coolify-patched}/compose/docker-compose.yml     "$SOURCE/docker-compose.yml"
        cp ${coolify-patched}/compose/docker-compose.prod.yml "$SOURCE/docker-compose.prod.yml"

        # .env template — only copy if no .env exists yet (preserves secrets)
        if [ ! -f "$ENV_FILE" ]; then
          cp ${coolify-patched}/compose/.env.production "$ENV_FILE"
        fi

        # Permissions
        chown -R 9999:root /data/coolify
        chmod -R 700 /data/coolify

        # Generate secrets for any empty values
        generate_if_empty() {
          local key="$1" value="$2"
          if grep -qE "^$key= *$" "$ENV_FILE"; then
            sed -i "s|^$key=.*|$key=$value|g" "$ENV_FILE"
            echo "  Generated $key"
          fi
        }

        generate_if_empty "APP_ID"            "$(openssl rand -hex 16)"
        generate_if_empty "APP_KEY"           "base64:$(openssl rand -base64 32)"
        generate_if_empty "DB_PASSWORD"       "$(openssl rand -base64 32)"
        generate_if_empty "REDIS_PASSWORD"    "$(openssl rand -base64 32)"
        generate_if_empty "PUSHER_APP_ID"     "$(openssl rand -hex 32)"
        generate_if_empty "PUSHER_APP_KEY"    "$(openssl rand -hex 32)"
        generate_if_empty "PUSHER_APP_SECRET" "$(openssl rand -hex 32)"

        # Docker network
        docker network inspect coolify >/dev/null 2>&1 || \
          docker network create --attachable coolify

        ${lib.optionalString cfg.nixosOverlay ''
          # Build patched image from Nix-prepared files
          echo "Building coolify-nixos:local overlay image (${gitTag})..."
          BUILD_DIR=$(mktemp -d)
          cp ${coolify-patched}/patched-php/constants.php            "$BUILD_DIR/"
          cp ${coolify-patched}/patched-php/InstallPrerequisites.php "$BUILD_DIR/"
          cp ${coolify-patched}/patched-php/InstallDocker.php        "$BUILD_DIR/"
          cat > "$BUILD_DIR/Dockerfile" << 'DOCKERFILE'
        ${dockerfileContent}
        DOCKERFILE

          docker build -t coolify-nixos:local "$BUILD_DIR"
          rm -rf "$BUILD_DIR"

          # Install compose override
          cat > "$SOURCE/docker-compose.override.yml" << 'OVERRIDE'
        ${composeOverrideContent}
        OVERRIDE
        ''}
      '';
    };

    # ── Main Coolify service ─────────────────────────────────────────────
    systemd.services.coolify = {
      description = "Coolify v4.x";
      after       = [ "docker.service" "coolify-setup.service" "network-online.target" ];
      wants       = [ "docker.service" "network-online.target" ];
      requires    = [ "coolify-setup.service" ];
      wantedBy    = [ "multi-user.target" ];
      serviceConfig = {
        Type               = "oneshot";
        RemainAfterExit    = true;
        WorkingDirectory   = "/data/coolify/source";
        ExecStart = toString (
          [ "${pkgs.docker-compose}/bin/docker-compose"
            "--env-file" "/data/coolify/source/.env"
            "-f" "/data/coolify/source/docker-compose.yml"
            "-f" "/data/coolify/source/docker-compose.prod.yml"
          ]
          ++ lib.optionals cfg.nixosOverlay
            [ "-f" "/data/coolify/source/docker-compose.override.yml" ]
          ++ [ "up" "-d" "--remove-orphans" "--force-recreate" ]
          ++ lib.optionals (!cfg.nixosOverlay) [ "--pull" "always" ]
        );
        ExecStop = toString (
          [ "${pkgs.docker-compose}/bin/docker-compose"
            "--env-file" "/data/coolify/source/.env"
            "-f" "/data/coolify/source/docker-compose.yml"
            "-f" "/data/coolify/source/docker-compose.prod.yml"
          ]
          ++ lib.optionals cfg.nixosOverlay
            [ "-f" "/data/coolify/source/docker-compose.override.yml" ]
          ++ [ "down" ]
        );
        TimeoutStartSec = 300;
      };
      path = with pkgs; [ docker docker-compose ];
    };

    # ── Upgrade service ───────────────────────────────────────────────
    # To upgrade Coolify, bump `version` and `hash` above, update the
    # patched PHP files if needed, then `nixos-rebuild switch`.
    systemd.services.coolify-upgrade = {
      description = "Redeploy Coolify containers";
      serviceConfig = {
        Type             = "oneshot";
        WorkingDirectory = "/data/coolify/source";
      };
      path   = with pkgs; [ docker docker-compose ];
      script = ''
        set -euo pipefail
        cd /data/coolify/source

        ${lib.optionalString cfg.nixosOverlay ''
          # Rebuild overlay in case base image was updated
          BUILD_DIR=$(mktemp -d)
          cp ${coolify-patched}/patched-php/constants.php            "$BUILD_DIR/"
          cp ${coolify-patched}/patched-php/InstallPrerequisites.php "$BUILD_DIR/"
          cp ${coolify-patched}/patched-php/InstallDocker.php        "$BUILD_DIR/"
          cat > "$BUILD_DIR/Dockerfile" << 'DOCKERFILE'
        ${dockerfileContent}
        DOCKERFILE

          docker build --pull -t coolify-nixos:local "$BUILD_DIR"
          rm -rf "$BUILD_DIR"
        ''}

        docker compose --env-file .env \
          -f docker-compose.yml \
          -f docker-compose.prod.yml \
          ${lib.optionalString cfg.nixosOverlay "-f docker-compose.override.yml"} \
          up -d --remove-orphans --force-recreate \
          ${lib.optionalString (!cfg.nixosOverlay) "--pull always"}

        docker image prune -f
      '';
    };

    systemd.timers.coolify-upgrade = {
      description = "Weekly Coolify upgrade check";
      wantedBy    = [ "timers.target" ];
      timerConfig = {
        OnCalendar         = cfg.upgradeCalendar;
        Persistent         = true;
        RandomizedDelaySec = "1h";
      };
    };

    # ── Firewall (opt-in) ────────────────────────────────────────────────
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall
      [ 80 443 6001 6002 8000 ];
    networking.firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall
      [ 443 ];

  };
}
