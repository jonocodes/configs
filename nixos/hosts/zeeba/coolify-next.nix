# NixOS module for Coolify v4.x with NixOS support (PR #7170)
#
# Identical to coolify-opus46.nix except:
#   - Builds an overlay Docker image that patches in NixOS OS detection
#   - Adds docker-compose.override.yml to every compose invocation
#   - Drops --pull always (local image isn't in a registry)
#
# Supporting files live in ./coolify/:
#   Dockerfile.overlay, docker-compose.override.yml, README.md
#
# Switch back to coolify-opus46.nix once PR #7170 ships in a release.

{ config, lib, pkgs, ... }:

let
  dockerfileOverlay = ./coolify/Dockerfile.overlay;
  composeOverride = ./coolify/docker-compose.override.yml;
  patchPrerequisites = ./coolify/patch-prerequisites.php;
in
{
  # ── Directory structure (same as official manual install) ───────────
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

  # ── One-shot setup ─────────────────────────────────────────────────
  systemd.services.coolify-setup = {
    description = "Coolify first-time setup + NixOS overlay build (PR #7170)";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "docker.service" "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [ openssl docker coreutils gnused gnugrep bash openssh curl ];
    script = ''
      set -euo pipefail

      SOURCE="/data/coolify/source"
      ENV_FILE="$SOURCE/.env"
      SSH_KEY="/data/coolify/ssh/keys/id.root@host.docker.internal"

      # ── SSH key ────────────────────────────────────────────────────
      if [ ! -f "$SSH_KEY" ]; then
        echo "Generating Coolify SSH key..."
        ssh-keygen -f "$SSH_KEY" -t ed25519 -N "" -C "root@coolify"
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        cat "$SSH_KEY.pub" >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
      fi

      # ── Download compose files from CDN ────────────────────────────
      if [ ! -f "$SOURCE/docker-compose.yml" ]; then
        echo "Downloading docker-compose.yml from CDN..."
        curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.yml \
          -o "$SOURCE/docker-compose.yml"
      fi

      if [ ! -f "$SOURCE/docker-compose.prod.yml" ]; then
        echo "Downloading docker-compose.prod.yml from CDN..."
        curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.prod.yml \
          -o "$SOURCE/docker-compose.prod.yml"
      fi

      if [ ! -f "$ENV_FILE" ]; then
        echo "Downloading .env.production from CDN..."
        curl -fsSL https://cdn.coollabs.io/coolify/.env.production \
          -o "$ENV_FILE"
      fi

      if [ ! -f "$SOURCE/upgrade.sh" ]; then
        echo "Downloading upgrade.sh from CDN..."
        curl -fsSL https://cdn.coollabs.io/coolify/upgrade.sh \
          -o "$SOURCE/upgrade.sh"
      fi

      # ── Permissions ────────────────────────────────────────────────
      chown -R 9999:root /data/coolify
      chmod -R 700 /data/coolify

      # ── Generate secrets (only for empty values) ───────────────────
      generate_if_empty() {
        local key="$1" value="$2"
        if grep -q "^$key=$" "$ENV_FILE" || grep -q "^$key= *$" "$ENV_FILE"; then
          sed -i "s|^$key=.*|$key=$value|g" "$ENV_FILE"
          echo "  Generated $key"
        fi
      }

      echo "Checking secrets..."
      generate_if_empty "APP_ID"            "$(openssl rand -hex 16)"
      generate_if_empty "APP_KEY"           "base64:$(openssl rand -base64 32)"
      generate_if_empty "DB_PASSWORD"       "$(openssl rand -base64 32)"
      generate_if_empty "REDIS_PASSWORD"    "$(openssl rand -base64 32)"
      generate_if_empty "PUSHER_APP_ID"     "$(openssl rand -hex 32)"
      generate_if_empty "PUSHER_APP_KEY"    "$(openssl rand -hex 32)"
      generate_if_empty "PUSHER_APP_SECRET" "$(openssl rand -hex 32)"

      # ── Docker network ─────────────────────────────────────────────
      docker network inspect coolify >/dev/null 2>&1 || \
        docker network create --attachable coolify

      # ── Build NixOS overlay image (PR #7170) ───────────────────────
      echo "Installing NixOS overlay files..."
      cp ${dockerfileOverlay} "$SOURCE/Dockerfile.overlay"
      cp ${patchPrerequisites} "$SOURCE/patch-prerequisites.php"
      cp ${composeOverride} "$SOURCE/docker-compose.override.yml"

      echo "Building coolify-nixos:local overlay image..."
      docker build -t coolify-nixos:local -f "$SOURCE/Dockerfile.overlay" "$SOURCE"

      echo ""
      echo "Setup complete.  Files at /data/coolify/source/"
      echo "NixOS overlay image: coolify-nixos:local"
    '';
  };

  # ── Main Coolify service ───────────────────────────────────────────
  # Same as coolify-opus46 but adds -f docker-compose.override.yml
  # and drops --pull always (local image is not in a registry).
  systemd.services.coolify = {
    description = "Coolify v4.x (NixOS patched)";
    after = [ "docker.service" "coolify-setup.service" "network-online.target" ];
    wants = [ "docker.service" "network-online.target" ];
    requires = [ "coolify-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/data/coolify/source";
      ExecStart = toString [
        "${pkgs.docker-compose}/bin/docker-compose"
        "--env-file" "/data/coolify/source/.env"
        "-f" "/data/coolify/source/docker-compose.yml"
        "-f" "/data/coolify/source/docker-compose.prod.yml"
        "-f" "/data/coolify/source/docker-compose.override.yml"
        "up" "-d" "--remove-orphans" "--force-recreate"
      ];
      ExecStop = toString [
        "${pkgs.docker-compose}/bin/docker-compose"
        "--env-file" "/data/coolify/source/.env"
        "-f" "/data/coolify/source/docker-compose.yml"
        "-f" "/data/coolify/source/docker-compose.prod.yml"
        "-f" "/data/coolify/source/docker-compose.override.yml"
        "down"
      ];
      TimeoutStartSec = 300;
    };
    path = with pkgs; [ docker docker-compose ];
  };

  # ── Upgrade timer ──────────────────────────────────────────────────
  # Re-downloads compose files, rebuilds the overlay on top of the
  # latest official image, and recreates all containers.
  systemd.services.coolify-upgrade = {
    description = "Rebuild NixOS overlay and restart Coolify";
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/data/coolify/source";
    };
    path = with pkgs; [ docker docker-compose curl ];
    script = ''
      set -euo pipefail
      cd /data/coolify/source

      # Re-download compose files (picks up structural changes)
      curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.yml    -o docker-compose.yml
      curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.prod.yml -o docker-compose.prod.yml

      # Rebuild overlay (--pull grabs latest base image)
      docker build --pull -t coolify-nixos:local -f Dockerfile.overlay .

      docker compose --env-file .env \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        -f docker-compose.override.yml \
        up -d --remove-orphans --force-recreate

      docker image prune -f
    '';
  };

  systemd.timers.coolify-upgrade = {
    description = "Weekly Coolify upgrade check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 03:00";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
