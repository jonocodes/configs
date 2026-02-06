{ config, pkgs, lib, ... }:

# mostly sourced from perplexity, trying to modernize the nix config I found

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


  virtualisation.oci-containers.containers.coolify = {
    image = "coollabsio/coolify:latest";
    autoStart = true;
    environment = {
      COOLIFY_APP_ENV = "production";
      COOLIFY_DB = "coolify";
      COOLIFY_DB_USERNAME = "coolify";
      COOLIFY_DB_PASSWORD = "coolify";  # Change this!
      COOLIFY_DB_HOST = "coolify-db";
      COOLIFY_DB_PORT = "5432";
      COOLIFY_REDIS_HOST = "coolify-redis";
      COOLIFY_REDIS_PORT = "6379";
      COOLIFY_HOSTADDR = "0.0.0.0";
    };
    ports = [
      "8000:8000"    # Main dashboard (matches docs)
    ];
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock"
      "/var/lib/coolify:/app/data"
      "/var/lib/coolify/ssh:/root/.ssh"
    ];
    dependsOn = [ "coolify-db" "coolify-redis" ];
    cmd = [ "start.sh" ];
  };

  # Database container (matches postgres service)
  virtualisation.oci-containers.containers."coolify-db" = {
    image = "tensorchord/pgvecto-rs:pg14-v0.2.0";
    autoStart = true;
    environment = {
      POSTGRES_USER = "coolify";
      POSTGRES_PASSWORD = "coolify";
      POSTGRES_DB = "coolify";
      POSTGRES_HOST_AUTH_METHOD = "trust";
    };
    ports = [ ];
    volumes = [ "/var/lib/coolify/db:/var/lib/postgresql/data" ];
  };

  # Redis container (matches redis service)  
  virtualisation.oci-containers.containers."coolify-redis" = {
    image = "docker.io/redis:7-alpine";
    autoStart = true;
    environment = { };
    ports = [ ];
    volumes = [ "/var/lib/coolify/redis:/data" ];
    cmd = [ "redis-server" "--port" "6379" "--loglevel" "warning" ];
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
