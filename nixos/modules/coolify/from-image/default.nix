# NixOS module for self-hosting Coolify v4.x (image patching approach)
#
# Runs PostgreSQL and Redis as native NixOS services. The Coolify app
# and realtime server run as Docker containers via oci-containers.
# A thin Docker image layer patches NixOS support onto the upstream image.
#
# Minimal usage:
#   imports = [ ../../modules/coolify/from-image ];
#   services.coolify = {
#     enable = true;
#     appKeyFile = "/run/secrets/coolify-app-key";
#     database.passwordFile = "/run/secrets/coolify-db-password";
#     redis.passwordFile = "/run/secrets/coolify-redis-password";
#     pusher.appKeyFile = "/run/secrets/coolify-pusher-key";
#     pusher.appSecretFile = "/run/secrets/coolify-pusher-secret";
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.coolify;

  # Docker image reference: use digest if pinned, otherwise "latest"
  imageRef =
    if cfg.imageDigest != null then
      "ghcr.io/coollabsio/coolify@${cfg.imageDigest}"
    else
      "ghcr.io/coollabsio/coolify:latest";

  # Build context for the patched Docker image
  patchContext = pkgs.runCommand "coolify-patch-context" { } ''
    mkdir -p $out
    cp ${./Dockerfile.overlay} $out/Dockerfile
    cp ${./patch-prerequisites.php} $out/patch-prerequisites.php
  '';

in
{

  options.services.coolify = {

    enable = lib.mkEnableOption "Coolify PaaS (v4.x)";

    imageDigest = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "sha256:5ac58c4f2aed0fa6e9c093947303d266babfcaf18cac1b6c6d671d1093b38c33";
      description = ''
        Pin the Coolify Docker image by digest for reproducibility.
        When null (default), uses the "latest" tag.
        Find digests at https://github.com/coollabsio/coolify/pkgs/container/coolify
      '';
    };

    nixosOverlay = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Build and use a patched Coolify image that adds NixOS OS-detection
        support (upstream PR #7170). Set to false once Coolify ships native
        NixOS support.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Host port for the Coolify web UI.";
    };

    soketiPort = lib.mkOption {
      type = lib.types.port;
      default = 6001;
      description = "Host port for the Soketi WebSocket server.";
    };

    terminalPort = lib.mkOption {
      type = lib.types.port;
      default = 6002;
      description = "Host port for the terminal WebSocket server.";
    };

    realtimeVersion = lib.mkOption {
      type = lib.types.str;
      default = "1.0.11";
      description = "Version tag for the coolify-realtime Docker image.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/data/coolify";
      description = "Base directory for Coolify persistent data.";
    };

    # ── Secrets ──────────────────────────────────────────────────────────

    appKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the Laravel APP_KEY (e.g. "base64:...").
        If null, a key will be auto-generated on first setup.
      '';
    };

    pusher = {
      appId = lib.mkOption {
        type = lib.types.str;
        default = "coolify";
        description = "Pusher/Soketi app ID.";
      };
      appKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the Pusher app key. Auto-generated if null.";
      };
      appSecretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the Pusher app secret. Auto-generated if null.";
      };
    };

    # ── Database ─────────────────────────────────────────────────────────

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to provision a local PostgreSQL database.";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "host.docker.internal";
        description = "PostgreSQL host. Only used when createLocally is false.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "PostgreSQL port.";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "coolify";
        description = "Database name.";
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "coolify";
        description = "Database username.";
      };
      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the database password. Auto-generated if null.";
      };
    };

    # ── Redis ────────────────────────────────────────────────────────────

    redis = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to provision a local Redis instance.";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "host.docker.internal";
        description = "Redis host. Only used when createLocally is false.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 6379;
        description = "Redis port.";
      };
      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the Redis password. Auto-generated if null.";
      };
    };

    # ── PHP tuning ───────────────────────────────────────────────────────

    phpMemoryLimit = lib.mkOption {
      type = lib.types.str;
      default = "256M";
      description = "PHP memory limit.";
    };

    # ── Firewall ─────────────────────────────────────────────────────────

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall ports for Coolify (app, soketi, terminal).";
    };

  };

  config = lib.mkIf cfg.enable {

    # ── Directory structure ─────────────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 root root -"
      "d ${cfg.dataDir}/source 0700 root root -"
      "d ${cfg.dataDir}/ssh 0700 root root -"
      "d ${cfg.dataDir}/ssh/keys 0700 root root -"
      "d ${cfg.dataDir}/ssh/mux 0700 root root -"
      "d ${cfg.dataDir}/applications 0700 root root -"
      "d ${cfg.dataDir}/databases 0700 root root -"
      "d ${cfg.dataDir}/backups 0700 root root -"
      "d ${cfg.dataDir}/services 0700 root root -"
      "d ${cfg.dataDir}/proxy 0700 root root -"
      "d ${cfg.dataDir}/proxy/dynamic 0700 root root -"
      "d ${cfg.dataDir}/webhooks-during-maintenance 0700 root root -"
      "d /run/coolify 0700 root root -"
    ];

    # ── PostgreSQL (local) ─────────────────────────────────────────────
    services.postgresql = lib.mkIf cfg.database.createLocally {
      enable = true;
      package = pkgs.postgresql_15;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.username;
          ensureDBOwnership = true;
        }
      ];
      settings = {
        listen_addresses = lib.mkDefault "127.0.0.1,172.17.0.1";
      };
      authentication = lib.mkAfter ''
        # Allow Coolify Docker containers to connect
        host ${cfg.database.name} ${cfg.database.username} 172.17.0.0/16 md5
      '';
    };

    # ── Redis (local) ──────────────────────────────────────────────────
    services.redis.servers.coolify = lib.mkIf cfg.redis.createLocally {
      enable = true;
      port = cfg.redis.port;
      bind = "127.0.0.1 172.17.0.1";
      settings = {
        save = lib.mkForce "20 1";
        loglevel = lib.mkDefault "warning";
      };
    };

    # ── First-time setup + secrets generation ──────────────────────────
    systemd.services.coolify-setup = {
      description = "Coolify first-time setup";
      after = [
        "docker.service"
        "network-online.target"
      ]
      ++ lib.optional cfg.database.createLocally "postgresql.service"
      ++ lib.optional cfg.redis.createLocally "redis-coolify.service";
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

        SECRETS_DIR="/run/coolify"
        SSH_KEY="${cfg.dataDir}/ssh/keys/id.root@host.docker.internal"

        # SSH key for Coolify to manage this host
        if [ ! -f "$SSH_KEY" ]; then
          echo "Generating Coolify SSH key..."
          ssh-keygen -f "$SSH_KEY" -t ed25519 -N "" -C "root@coolify"
          mkdir -p /root/.ssh
          chmod 700 /root/.ssh
          cat "$SSH_KEY.pub" >> /root/.ssh/authorized_keys
          chmod 600 /root/.ssh/authorized_keys
        fi

        # Generate secrets that weren't provided via options
        generate_secret() {
          local name="$1" file="$2" generator="$3"
          if [ ! -f "$file" ]; then
            echo "  Generating $name..."
            $generator > "$file"
            chmod 600 "$file"
          fi
        }

        ${lib.optionalString (cfg.appKeyFile == null) ''
          generate_secret "APP_KEY" "$SECRETS_DIR/app-key" \
            'echo -n "base64:$(openssl rand -base64 32)"'
        ''}
        ${lib.optionalString (cfg.database.passwordFile == null) ''
          generate_secret "DB_PASSWORD" "$SECRETS_DIR/db-password" \
            'openssl rand -base64 32 | tr -d "\n"'
        ''}
        ${lib.optionalString (cfg.redis.passwordFile == null) ''
          generate_secret "REDIS_PASSWORD" "$SECRETS_DIR/redis-password" \
            'openssl rand -base64 32 | tr -d "\n"'
        ''}
        ${lib.optionalString (cfg.pusher.appKeyFile == null) ''
          generate_secret "PUSHER_APP_KEY" "$SECRETS_DIR/pusher-key" \
            'openssl rand -hex 32 | tr -d "\n"'
        ''}
        ${lib.optionalString (cfg.pusher.appSecretFile == null) ''
          generate_secret "PUSHER_APP_SECRET" "$SECRETS_DIR/pusher-secret" \
            'openssl rand -hex 32 | tr -d "\n"'
        ''}

        # Set DB password for local PostgreSQL user if we manage it
        ${lib.optionalString cfg.database.createLocally ''
          DB_PASS=$(cat ${
            if cfg.database.passwordFile != null then
              toString cfg.database.passwordFile
            else
              "/run/coolify/db-password"
          })
          ${pkgs.sudo}/bin/sudo -u postgres ${config.services.postgresql.package}/bin/psql \
            -c "ALTER USER ${cfg.database.username} WITH PASSWORD '$DB_PASS';" || true
        ''}

        # Set Redis password if we manage it
        ${lib.optionalString cfg.redis.createLocally ''
          REDIS_PASS=$(cat ${
            if cfg.redis.passwordFile != null then
              toString cfg.redis.passwordFile
            else
              "/run/coolify/redis-password"
          })
          ${pkgs.redis}/bin/redis-cli -p ${toString cfg.redis.port} \
            CONFIG SET requirepass "$REDIS_PASS" || true
          ${pkgs.redis}/bin/redis-cli -p ${toString cfg.redis.port} \
            -a "$REDIS_PASS" CONFIG REWRITE || true
        ''}

        # Docker network
        docker network inspect coolify >/dev/null 2>&1 || \
          docker network create --attachable coolify

        # Build .env file for the container
        APP_KEY=$(cat ${if cfg.appKeyFile != null then toString cfg.appKeyFile else "/run/coolify/app-key"})
        DB_PASS=$(cat ${
          if cfg.database.passwordFile != null then
            toString cfg.database.passwordFile
          else
            "/run/coolify/db-password"
        })
        REDIS_PASS=$(cat ${
          if cfg.redis.passwordFile != null then
            toString cfg.redis.passwordFile
          else
            "/run/coolify/redis-password"
        })
        PUSHER_KEY=$(cat ${
          if cfg.pusher.appKeyFile != null then toString cfg.pusher.appKeyFile else "/run/coolify/pusher-key"
        })
        PUSHER_SECRET=$(cat ${
          if cfg.pusher.appSecretFile != null then
            toString cfg.pusher.appSecretFile
          else
            "/run/coolify/pusher-secret"
        })

        cat > "${cfg.dataDir}/source/.env" << EOF
        APP_NAME=Coolify
        APP_ID=$(openssl rand -hex 16)
        APP_ENV=production
        APP_KEY=$APP_KEY
        APP_URL=http://localhost:${toString cfg.port}
        DB_CONNECTION=pgsql
        DB_HOST=${if cfg.database.createLocally then "host.docker.internal" else cfg.database.host}
        DB_PORT=${toString cfg.database.port}
        DB_DATABASE=${cfg.database.name}
        DB_USERNAME=${cfg.database.username}
        DB_PASSWORD=$DB_PASS
        REDIS_HOST=${if cfg.redis.createLocally then "host.docker.internal" else cfg.redis.host}
        REDIS_PASSWORD=$REDIS_PASS
        QUEUE_CONNECTION=redis
        PUSHER_HOST=host.docker.internal
        PUSHER_BACKEND_HOST=host.docker.internal
        PUSHER_PORT=${toString cfg.soketiPort}
        PUSHER_BACKEND_PORT=${toString cfg.soketiPort}
        PUSHER_SCHEME=http
        PUSHER_APP_ID=${cfg.pusher.appId}
        PUSHER_APP_KEY=$PUSHER_KEY
        PUSHER_APP_SECRET=$PUSHER_SECRET
        AUTOUPDATE=false
        SSL_MODE=off
        PHP_MEMORY_LIMIT=${cfg.phpMemoryLimit}
        PHP_PM_CONTROL=dynamic
        PHP_PM_START_SERVERS=1
        PHP_PM_MIN_SPARE_SERVERS=1
        PHP_PM_MAX_SPARE_SERVERS=10
        HORIZON_BALANCE=100
        HORIZON_MAX_PROCESSES=10
        HORIZON_BALANCE_MAX_SHIFT=10
        HORIZON_BALANCE_COOLDOWN=10
        EOF
        chmod 600 "${cfg.dataDir}/source/.env"

        chown -R 9999:root ${cfg.dataDir}
        chmod -R 700 ${cfg.dataDir}
      '';
    };

    # ── Build patched image ────────────────────────────────────────────
    systemd.services.coolify-build = lib.mkIf cfg.nixosOverlay {
      description = "Build patched Coolify Docker image";
      after = [
        "docker.service"
        "coolify-setup.service"
      ];
      requires = [
        "docker.service"
        "coolify-setup.service"
      ];
      before = [ "docker-coolify.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.docker ];
      script = ''
        echo "Building coolify-nixos:local from ${imageRef}..."
        docker build -t coolify-nixos:local \
          --build-arg "COOLIFY_IMAGE=${imageRef}" \
          ${patchContext}
      '';
    };

    # ── Docker network ─────────────────────────────────────────────────
    systemd.services.coolify-network = {
      description = "Create Coolify Docker network";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      before = [
        "docker-coolify.service"
        "docker-coolify-realtime.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.docker ];
      script = ''
        docker network inspect coolify >/dev/null 2>&1 || \
          docker network create --attachable coolify
      '';
    };

    # ── Coolify app container ──────────────────────────────────────────
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers.coolify = {
      image = if cfg.nixosOverlay then "coolify-nixos:local" else imageRef;
      extraOptions = [
        "--add-host=host.docker.internal:host-gateway"
        "--network=coolify"
      ];
      ports = [ "${toString cfg.port}:8080" ];
      volumes = [
        "${cfg.dataDir}/source/.env:/var/www/html/.env:ro"
        "${cfg.dataDir}/ssh:/var/www/html/storage/app/ssh"
        "${cfg.dataDir}/applications:/var/www/html/storage/app/applications"
        "${cfg.dataDir}/databases:/var/www/html/storage/app/databases"
        "${cfg.dataDir}/services:/var/www/html/storage/app/services"
        "${cfg.dataDir}/backups:/var/www/html/storage/app/backups"
        "${cfg.dataDir}/webhooks-during-maintenance:/var/www/html/storage/app/webhooks-during-maintenance"
        "/var/run/docker.sock:/var/run/docker.sock"
      ];
      environment = {
        APP_ENV = "production";
        SSL_MODE = "off";
      };
    };

    # Wire up service dependencies
    systemd.services.docker-coolify = {
      after = [
        "coolify-setup.service"
        "coolify-network.service"
      ]
      ++ lib.optional cfg.nixosOverlay "coolify-build.service"
      ++ lib.optional cfg.database.createLocally "postgresql.service"
      ++ lib.optional cfg.redis.createLocally "redis-coolify.service";
      requires = [
        "coolify-setup.service"
        "coolify-network.service"
      ]
      ++ lib.optional cfg.nixosOverlay "coolify-build.service";
    };

    # ── Coolify realtime container ─────────────────────────────────────
    virtualisation.oci-containers.containers.coolify-realtime = {
      image = "ghcr.io/coollabsio/coolify-realtime:${cfg.realtimeVersion}";
      extraOptions = [
        "--add-host=host.docker.internal:host-gateway"
        "--network=coolify"
      ];
      ports = [
        "${toString cfg.soketiPort}:6001"
        "${toString cfg.terminalPort}:6002"
      ];
      volumes = [
        "${cfg.dataDir}/ssh:/var/www/html/storage/app/ssh"
      ];
      environmentFiles = [
        "${cfg.dataDir}/source/.env"
      ];
    };

    systemd.services.docker-coolify-realtime = {
      after = [
        "coolify-setup.service"
        "coolify-network.service"
      ];
      requires = [
        "coolify-setup.service"
        "coolify-network.service"
      ];
    };

    # ── Firewall (opt-in) ──────────────────────────────────────────────
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      cfg.port
      cfg.soketiPort
      cfg.terminalPort
      80
      443
    ];
    networking.firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall [ 443 ];

  };
}
