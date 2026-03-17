# NixOS module for self-hosting Coolify v4.x
#
# Follows the official manual installation layout at /data/coolify/.
# Compose files are downloaded from Coolify's CDN at first boot, so they
# live on disk and can be managed with plain `docker compose` as well.
#
# The nixosOverlay option (default: true) applies the NixOS OS-detection
# patch from upstream PR #7170 on top of the official image. Set it to
# false once Coolify ships native NixOS support.
#
# Minimal usage:
#   imports = [ ../../modules/coolify ];
#   services.coolify.enable = true;

{ config, lib, pkgs, ... }:

let
  cfg = config.services.coolify;
  dockerfileOverlay = ./Dockerfile.overlay;
  composeOverride   = ./docker-compose.override.yml;
  patchPrereqs      = ./patch-prerequisites.php;
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
    # Idempotent: skips any step that is already done.
    systemd.services.coolify-setup = {
      description = "Coolify first-time setup";
      after       = [ "docker.service" "network-online.target" ];
      wants       = [ "docker.service" "network-online.target" ];
      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
      };
      path   = with pkgs; [ openssl docker coreutils gnused gnugrep bash openssh curl ];
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

        # Compose files from CDN
        if [ ! -f "$SOURCE/docker-compose.yml" ]; then
          curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.yml \
            -o "$SOURCE/docker-compose.yml"
        fi

        if [ ! -f "$SOURCE/docker-compose.prod.yml" ]; then
          curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.prod.yml \
            -o "$SOURCE/docker-compose.prod.yml"
        fi

        if [ ! -f "$ENV_FILE" ]; then
          curl -fsSL https://cdn.coollabs.io/coolify/.env.production \
            -o "$ENV_FILE"
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
          # NixOS overlay: patch the official image with NixOS OS-detection
          # support (upstream PR #7170 + InstallPrerequisites fix).
          # Remove this block once Coolify ships native NixOS support.
          echo "Installing NixOS overlay files..."
          cp ${dockerfileOverlay} "$SOURCE/Dockerfile.overlay"
          cp ${patchPrereqs}      "$SOURCE/patch-prerequisites.php"
          cp ${composeOverride}   "$SOURCE/docker-compose.override.yml"

          echo "Building coolify-nixos:local overlay image..."
          docker build -t coolify-nixos:local \
            -f "$SOURCE/Dockerfile.overlay" "$SOURCE"
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

    # ── Weekly upgrade timer ─────────────────────────────────────────────
    # Re-downloads compose files from CDN, rebuilds the overlay if enabled,
    # and recreates containers.
    systemd.services.coolify-upgrade = {
      description = "Upgrade Coolify to latest release";
      serviceConfig = {
        Type             = "oneshot";
        WorkingDirectory = "/data/coolify/source";
      };
      path   = with pkgs; [ docker docker-compose curl ];
      script = ''
        set -euo pipefail
        cd /data/coolify/source

        curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.yml \
          -o docker-compose.yml
        curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.prod.yml \
          -o docker-compose.prod.yml

        ${lib.optionalString cfg.nixosOverlay ''
          docker build --pull -t coolify-nixos:local \
            -f Dockerfile.overlay .
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
