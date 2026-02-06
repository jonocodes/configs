{ config, pkgs, lib, ... }:

# mostly sourced from https://github.com/PVUL/nixos-coolify/blob/main/configuration/configuration.nix

{

  # Networking
  # networking = {
  #   hostName = "coolify-server";
  #   firewall = {
  #     enable = true;
  #     allowedTCPPorts = [
  #       22 80 443    # Basic ports
  #       3000         # Coolify dashboard
  #     ] ++ (lib.range 8000 9000);    # Range for deployed applications
  #   };
  # };

  # System tweaks for running containers
  boot.kernel.sysctl = {
    # "vm.max_map_count" = 262144;  # Required for Elasticsearch
    "net.ipv4.ip_forward" = 1;     # Required for container networking
  };

  # Docker configuration
  # virtualisation.docker = {
  #   enable = true;
  #   autoPrune = {
  #     enable = true;
  #     dates = "weekly";
  #   };
  # };

  # Create Docker network
  systemd.services.docker-network-coolify = {
    description = "Create Docker network for Coolify";
    after = [ "network.target" "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker network create coolify || true'";
    };
  };

  # Setup SSH keys for Coolify
  systemd.services.coolify-ssh-setup = {
    description = "Setup SSH keys for Coolify";
    wantedBy = [ "multi-user.target" ];
    before = [ "coolify.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "setup-coolify-ssh" ''
        mkdir -p /data/coolify/ssh/keys
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -a 100 \
          -f /data/coolify/ssh/keys/id.root@host.docker.internal \
          -q -N "" -C root@coolify
        
        # Set correct permissions
        chmod 600 /data/coolify/ssh/keys/id.root@host.docker.internal
        chmod 644 /data/coolify/ssh/keys/id.root@host.docker.internal.pub
        
        # Set ownership
        chown 9999 /data/coolify/ssh/keys/id.root@host.docker.internal
        
        # Setup authorized_keys
        mkdir -p ~/.ssh
        cp /data/coolify/ssh/keys/id.root@host.docker.internal.pub ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        chmod 700 ~/.ssh
      '';
    };
  };

  # PostgreSQL service for Coolify
  systemd.services.coolify-db = {
    description = "PostgreSQL for Coolify";
    after = [ "network.target" "docker.service" "docker-network-coolify.service" ];
    requires = [ "docker.service" "docker-network-coolify.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStartPre = "${pkgs.docker}/bin/docker rm -f postgres || true";
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name postgres --network coolify -e POSTGRES_DB=coolify -e POSTGRES_USER=coolify -e POSTGRES_PASSWORD=coolify -v coolify-db-data:/var/lib/postgresql/data postgres:14-alpine";
      ExecStop = "${pkgs.docker}/bin/docker stop postgres";
      Restart = "on-failure";
    };
  };

  # Redis service for Coolify
  systemd.services.coolify-redis = {
    description = "Redis for Coolify";
    after = [ "network.target" "docker.service" "docker-network-coolify.service" ];
    requires = [ "docker.service" "docker-network-coolify.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStartPre = "${pkgs.docker}/bin/docker rm -f coolify-redis || true";
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name coolify-redis --network coolify redis:alpine";
      ExecStop = "${pkgs.docker}/bin/docker stop coolify-redis";
      Restart = "on-failure";
    };
  };

  # Coolify service
  systemd.services.coolify = {
    description = "Coolify container";
    after = [ "network.target" "docker.service" "docker-network-coolify.service" "coolify-redis.service" "coolify-db.service" "coolify-ssh-setup.service" ];
    requires = [ "docker.service" "docker-network-coolify.service" "coolify-redis.service" "coolify-db.service" "coolify-ssh-setup.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStartPre = [
        "-${pkgs.docker}/bin/docker rm -f coolify"
        "${pkgs.bash}/bin/bash -c 'until ${pkgs.docker}/bin/docker exec postgres pg_isready; do sleep 1; done'"
        "${pkgs.coreutils}/bin/mkdir -p /data/coolify/storage/logs"
        "${pkgs.coreutils}/bin/mkdir -p /data/coolify/.ssh"
        "${pkgs.coreutils}/bin/mkdir -p /data/coolify/ssh/keys"
        "${pkgs.coreutils}/bin/chmod -R 777 /data/coolify"
        "${pkgs.coreutils}/bin/cp /data/coolify/ssh/keys/id.root@host.docker.internal.pub /data/coolify/.ssh/authorized_keys"
        "${pkgs.coreutils}/bin/chmod 600 /data/coolify/.ssh/authorized_keys"
        "${pkgs.coreutils}/bin/chown -R 9999:9999 /data/coolify/.ssh"
        "${pkgs.coreutils}/bin/chmod 700 /data/coolify/ssh/keys"
        "${pkgs.coreutils}/bin/chmod 700 /data/coolify/.ssh"
        "${pkgs.coreutils}/bin/chown -R 9999:9999 /data/coolify/ssh"
      ];

      ExecStart = ''
        ${pkgs.docker}/bin/docker run --rm \
          --name coolify \
          --network coolify \
          --add-host=host.docker.internal:host-gateway \
          -p 3000:3000 \
          -p 8080:8000 \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v /data/coolify/storage/logs:/var/www/html/storage/logs \
          -v /data/coolify:/data/coolify \
          -e POSTGRES_HOST=postgres \
          -e POSTGRES_PORT=5432 \
          -e POSTGRES_USER=coolify \
          -e POSTGRES_PASSWORD=coolify \
          -e POSTGRES_DB=coolify \
          -e DATABASE_URL="postgresql://coolify:coolify@postgres:5432/coolify" \
          -e REDIS_HOST=coolify-redis \
          -e REDIS_PORT=6379 \
          -e SSL_MODE=off \
          -e APP_KEY=base64:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
          coollabsio/coolify:latest
      '';

      ExecStop = "${pkgs.docker}/bin/docker stop coolify";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  # Ensure the data directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /data/coolify 0755 root root -"
  ];

  # users.users.nixos = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" "docker" ];
  #   openssh.authorizedKeys.keys = [
  #     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA2OjoL61AJ+k/AzHvD9n9PEPM1h7RMH+Ls5WWKZ2HnL"
  #   ];
  #   shell = pkgs.zsh;
  # };


}
