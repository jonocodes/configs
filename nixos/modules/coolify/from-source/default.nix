# NixOS module for self-hosting Coolify v4.x (pinned source + patches)
#
# Follows the official manual installation layout at /data/coolify/.
# Source is pinned via fetchFromGitHub — compose files come from the pinned
# checkout, not the CDN.
#
# NixOS patches add OS detection support (PR #7170). They are applied via
# `pkgs.applyPatches` at build time. To upgrade Coolify, bump `version` in
# your config, update the `hash` (Nix will tell you the correct value), and
# verify the patches still apply.
#
# Minimal usage:
#   imports = [ ../../modules/coolify/from-source ];
#   services.coolify = {
#     enable = true;
#     # version = "4.0.0-beta.468";  # optional, defaults to the module's default
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.coolify;

  # ── Coolify source (pinned) ─────────────────────────────────────────
  gitTag = "v${cfg.version}";

  coolify-src = pkgs.fetchFromGitHub {
    owner = "coollabsio";
    repo = "coolify";
    rev = gitTag;
    hash = cfg.hash;
  };

  # ── Patched PHP files with NixOS support ─────────────────────────────
  # Full file copies used instead of patches because PHP's $variable syntax
  # makes inline patch strings error-prone. To upgrade: diff new upstream
  # files against ./patched/ to see our changes.
  patched-constants = pkgs.writeText "constants.php" (builtins.readFile ./patched/constants.php);
  patched-install-prereqs = pkgs.writeText "InstallPrerequisites.php" (
    builtins.readFile ./patched/InstallPrerequisites.php
  );
  patched-install-docker = pkgs.writeText "InstallDocker.php" (
    builtins.readFile ./patched/InstallDocker.php
  );

  # ── Dockerfile for overlay image ──────────────────────────────────────
  dockerfile = pkgs.writeText "Dockerfile" ''
    FROM ghcr.io/coollabsio/coolify:${lib.removePrefix "v" cfg.version}

    COPY --chown=9999:9999 bootstrap/helpers/constants.php \
      /var/www/html/bootstrap/helpers/constants.php

    COPY --chown=9999:9999 app/Actions/Server/InstallPrerequisites.php \
      /var/www/html/app/Actions/Server/InstallPrerequisites.php

    COPY --chown=9999:9999 app/Actions/Server/InstallDocker.php \
      /var/www/html/app/Actions/Server/InstallDocker.php
  '';

  # ── Build derivation: compose files + Dockerfile ───────────────────────
  coolify-with-dockerfile =
    pkgs.runCommand "coolify-with-dockerfile-${gitTag}"
      {
        preferLocalBuild = true;
      }
      ''
        mkdir -p $out
        cp -r --no-preserve=ownership ${coolify-src}/* $out/
        chmod -R u+w $out
        cp ${patched-constants} $out/bootstrap/helpers/constants.php
        cp ${patched-install-prereqs} $out/app/Actions/Server/InstallPrerequisites.php
        cp ${patched-install-docker} $out/app/Actions/Server/InstallDocker.php
        cp ${dockerfile} $out/Dockerfile
      '';

in
{

  options.services.coolify = {

    enable = lib.mkEnableOption "Coolify PaaS (v4.x)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "4.0.0-beta.468";
      example = "4.0.0-beta.500";
      description = "Coolify version to deploy (without 'v' prefix)";
    };

    hash = lib.mkOption {
      type = lib.types.str;
      default = "sha256-xRwNEKBLJ/YtNaboWX/5JVp5pWr1JYCxxxHYjAT1Yio=";
      example = "sha256-abc123...";
      description = " Nix store hash of the fetched source (nix will tell you the correct value)";
    };

    nixosOverlay = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Build and use a patched Coolify image that adds NixOS OS-detection
        support. Required until Coolify ships this natively.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open the firewall ports Coolify needs:
        TCP 80, 443, 6001, 6002, 8000 and UDP 443.
      '';
    };

    upgradeCalendar = lib.mkOption {
      type = lib.types.str;
      default = "Sun 03:00";
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
      after = [
        "docker.service"
        "network-online.target"
      ];
      wants = [
        "docker.service"
        "network-online.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = with pkgs; [
        openssl
        docker
        coreutils
        gnused
        gnugrep
        bash
        openssh
      ];
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
        cp ${coolify-with-dockerfile}/docker-compose.yml     "$SOURCE/docker-compose.yml"
        cp ${coolify-with-dockerfile}/docker-compose.prod.yml "$SOURCE/docker-compose.prod.yml"

        # .env template — only copy if no .env exists yet (preserves secrets)
        if [ ! -f "$ENV_FILE" ]; then
          cp ${coolify-with-dockerfile}/.env.production "$ENV_FILE"
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
            # Build patched image from Nix-prepared source
            echo "Building coolify-nixos:local overlay image (${gitTag})..."
            docker build -t coolify-nixos:local \
              -f ${coolify-with-dockerfile}/Dockerfile \
              ${coolify-with-dockerfile}

            # Install compose override
            cat > "$SOURCE/docker-compose.override.yml" << 'OVERRIDE'
          services:
            coolify:
              image: coolify-nixos:local
          OVERRIDE
        ''}
      '';
    };

    # ── Main Coolify service ─────────────────────────────────────────────
    systemd.services.coolify = {
      description = "Coolify v4.x";
      after = [
        "docker.service"
        "coolify-setup.service"
        "network-online.target"
      ];
      wants = [
        "docker.service"
        "network-online.target"
      ];
      requires = [ "coolify-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/data/coolify/source";
        ExecStart = toString (
          [
            "${pkgs.docker-compose}/bin/docker-compose"
            "--env-file"
            "/data/coolify/source/.env"
            "-f"
            "/data/coolify/source/docker-compose.yml"
            "-f"
            "/data/coolify/source/docker-compose.prod.yml"
          ]
          ++ lib.optionals cfg.nixosOverlay [
            "-f"
            "/data/coolify/source/docker-compose.override.yml"
          ]
          ++ [
            "up"
            "-d"
            "--remove-orphans"
            "--force-recreate"
          ]
          ++ lib.optionals (!cfg.nixosOverlay) [
            "--pull"
            "always"
          ]
        );
        ExecStop = toString (
          [
            "${pkgs.docker-compose}/bin/docker-compose"
            "--env-file"
            "/data/coolify/source/.env"
            "-f"
            "/data/coolify/source/docker-compose.yml"
            "-f"
            "/data/coolify/source/docker-compose.prod.yml"
          ]
          ++ lib.optionals cfg.nixosOverlay [
            "-f"
            "/data/coolify/source/docker-compose.override.yml"
          ]
          ++ [ "down" ]
        );
        TimeoutStartSec = 300;
      };
      path = with pkgs; [
        docker
        docker-compose
      ];
    };

    # ── Upgrade service ───────────────────────────────────────────────
    # To upgrade Coolify, bump `services.coolify.version` in your config,
    # update `services.coolify.hash` (nix will tell you the correct value),
    # then `nixos-rebuild switch`.
    systemd.services.coolify-upgrade = {
      description = "Redeploy Coolify containers";
      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = "/data/coolify/source";
      };
      path = with pkgs; [
        docker
        docker-compose
      ];
      script = ''
        set -euo pipefail
        cd /data/coolify/source

        ${lib.optionalString cfg.nixosOverlay ''
          # Rebuild overlay in case base image was updated
          docker build --pull -t coolify-nixos:local \
            -f ${coolify-with-dockerfile}/Dockerfile \
            ${coolify-with-dockerfile}
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
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.upgradeCalendar;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # ── Firewall (opt-in) ────────────────────────────────────────────────
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      80
      443
      6001
      6002
      8000
    ];
    networking.firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall [ 443 ];

  };
}
