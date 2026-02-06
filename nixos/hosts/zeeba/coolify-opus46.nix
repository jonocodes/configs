# NixOS module for self-hosting Coolify v4.x
#
# This follows the official manual installation guide exactly:
#   https://coolify.io/docs/get-started/installation#manual-installation
#
# The compose files and .env are downloaded from Coolify's CDN (just like
# the official install.sh does), so they live on disk at /data/coolify/source/
# and can be managed with plain `docker compose` outside of NixOS.
#
# Usage:
#   1. Import this file in your configuration.nix:  imports = [ ./coolify.nix ];
#   2. sudo nixos-rebuild switch
#   3. sudo systemctl start coolify-setup   (first time only — generates keys & secrets)
#   4. Access Coolify at http://<your-ip>:8000
#
# After setup you can also manage everything manually:
#   cd /data/coolify/source
#   docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d
#
# References:
#   - https://github.com/coollabsio/coolify  (v4.x branch)
#   - https://coolify.io/docs/get-started/installation

{ config, lib, pkgs, ... }:

{
  # ── Docker ───────────────────────────────────────────────────────────
  # virtualisation.docker = {
  #   enable = true;
  #   autoPrune = {
  #     enable = true;
  #     dates = "weekly";
  #   };
  #   # Match the daemon config the official install.sh sets
  #   daemon.settings = {
  #     log-driver = "json-file";
  #     log-opts = {
  #       max-size = "10m";
  #       max-file = "3";
  #     };
  #   };
  # };

  # # ── System packages ──────────────────────────────────────────────────
  # environment.systemPackages = with pkgs; [
  #   docker-compose   # `docker compose` v2 plugin
  #   openssl
  #   curl
  #   wget
  #   git
  #   jq
  # ];

  # ── Firewall ─────────────────────────────────────────────────────────
  # networking.firewall.allowedTCPPorts = [
  #   22     # SSH — Coolify needs this to manage servers
  #   80     # Traefik HTTP  (Coolify deploys this itself)
  #   443    # Traefik HTTPS
  #   6001   # Soketi / WebSocket
  #   6002   # Soketi metrics
  #   8000   # Coolify web UI
  # ];

  # # ── SSH — Coolify requires root SSH to manage the host ──────────────
  # services.openssh = {
  #   enable = true;
  #   settings = {
  #     PermitRootLogin = "prohibit-password";
  #   };
  # };

  # ── Directory structure ──────────────────────────────────────────────
  # Exact layout from the official manual install:
  #   mkdir -p /data/coolify/{source,ssh,applications,databases,backups,services,proxy,webhooks-during-maintenance}
  #   mkdir -p /data/coolify/ssh/{keys,mux}
  #   mkdir -p /data/coolify/proxy/dynamic
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

  # ── One-shot setup service ──────────────────────────────────────────
  # Mirrors the official manual install steps 2–6:
  #   - Generate SSH key
  #   - Download compose files + .env from CDN
  #   - Set permissions
  #   - Generate secrets
  #   - Create docker network
  #
  # Idempotent: skips steps that are already done.
  # After this runs, /data/coolify/source/ contains real files you
  # can use directly with `docker compose`.
  systemd.services.coolify-setup = {
    description = "Coolify first-time setup (SSH keys, compose files, secrets)";
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

      # ── Step 2: Generate SSH key ─────────────────────────────────────
      if [ ! -f "$SSH_KEY" ]; then
        echo "Generating Coolify SSH key..."
        ssh-keygen -f "$SSH_KEY" -t ed25519 -N "" -C "root@coolify"
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        cat "$SSH_KEY.pub" >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
      fi

      # ── Step 3: Download compose files from CDN ──────────────────────
      # These are the exact same files the official install.sh downloads.
      # They live on disk so you can `cd /data/coolify/source && docker compose ...`

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

      # ── Step 4: Set permissions ──────────────────────────────────────
      chown -R 9999:root /data/coolify
      chmod -R 700 /data/coolify

      # ── Step 5: Generate secrets (only for empty values) ─────────────
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

      # ── Step 6: Create docker network ────────────────────────────────
      docker network inspect coolify >/dev/null 2>&1 || \
        docker network create --attachable coolify

      echo ""
      echo "Setup complete. Files are at /data/coolify/source/"
      echo "You can also run Coolify manually:"
      echo "  cd /data/coolify/source"
      echo "  docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d --pull always --remove-orphans --force-recreate"
    '';
  };

  # ── Main Coolify service ─────────────────────────────────────────────
  # Runs the exact same docker compose command as the official docs.
  systemd.services.coolify = {
    description = "Coolify v4.x";
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
        "up" "-d" "--pull" "always" "--remove-orphans" "--force-recreate"
      ];
      ExecStop = toString [
        "${pkgs.docker-compose}/bin/docker-compose"
        "--env-file" "/data/coolify/source/.env"
        "-f" "/data/coolify/source/docker-compose.yml"
        "-f" "/data/coolify/source/docker-compose.prod.yml"
        "down"
      ];
      TimeoutStartSec = 300;
    };
    path = with pkgs; [ docker docker-compose ];
  };

  # ── Upgrade timer (optional) ─────────────────────────────────────────
  # Re-pulls images and recreates containers weekly, same as what
  # /data/coolify/source/upgrade.sh does.
  systemd.services.coolify-upgrade = {
    description = "Pull latest Coolify images and restart";
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/data/coolify/source";
    };
    path = with pkgs; [ docker docker-compose curl ];
    script = ''
      set -euo pipefail
      cd /data/coolify/source

      # Re-download compose files (picks up any structural changes)
      curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.yml    -o docker-compose.yml
      curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.prod.yml -o docker-compose.prod.yml

      docker compose --env-file .env \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        up -d --pull always --remove-orphans --force-recreate

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