
{ pkgs, pkgs-unstable, inputs, modulesPath, config, ... }:
let
  inherit (inputs) self;

in {

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.backup = {

    # NOTE: manually test backup send from dobro
    # dobro>  zfs send dpool/thunderbird_data@autosnap_2025-02-02_05:46:11_hourly | pv | ssh backup@zeeba zfs recv -F "dpool/dobro/test"

    description = "user to receive backups";
    shell = pkgs.bash;
    group = "backup";
    isSystemUser = true;

    # TODO: restrict executable actions
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGI9g+ml4fmwK8eNYe7qb7lWHlqZ4baVc5U6nkMCbnG jono@foodnotblogs.com"  # for backing up from dobro
    ];
  };

  users.groups.backup = {};

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "dpool" ];
  boot.zfs.forceImportRoot = false; # mounts datasets instead of pools

  digitus.services = {

    syncthing = {
      enable = true;
      folderDevices = {
        common = {
          devices = [ "choco" "dobro" "galaxyS23" "jonodot" ];
          versioned = true;
        };
        more = {
          devices = [ "choco" "dobro" "jonodot" ];
        };
        configs = {
          devices = [ "choco" "dobro" "jonodot" ];
          versioned = true;
        };
        # savr_data = {
        #   devices = [ "choco" "dobro" "galaxyS23" "jonodot" ];
        # };

      };
    };

  };

  services.tailscale = {

    # this gives access from berk to alb nas
    extraSetFlags = [
      # "--advertise-routes=192.168.100.0/24"
      # "--advertise-routes=192.168.200.0/24" # this broke my local network. not sure why
      "--advertise-exit-node"
    ];
    useRoutingFeatures = "server";
  };

  environment.etc."nextcloud-admin-pass".text = "2YTVS1GwORVcKtAYUJLY";

  services = {

    # open web ui is run with docker manually
    #   docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main

    # ollama = {
    #   enable = true;
    #   host = "0.0.0.0";
    #   openFirewall = true;
    # };

    sanoid = {
      enable = true;
    };


    # needed for nextcloud video chat
    # TODO: figure out how to connect this to nextcloud
    coturn = {
      enable = true;
      # turn.turnServer.tlsCert = "/etc/coturn/cert.pem";
      # turn.turnServer.tlsKey = "/etc/coturn/key.pem";
      # turn.turnServer.tlsCert = "/etc/coturn/cert.pem";
      # turn.turnServer.tlsKey = "/etc/coturn/key.pem";
      # turn.turnServer.listeningPort = 3478;
      # turn.turnServer.externalIp = "127.0.0.1";
      # turn.turnServer.externalPort = 3478;
      # turn.turnServer.realm = "wolf-typhon.ts.net";
      # turn.turnServer.fingerprint = "b2:f0:a9:b4:c0:d0:e5:d1:a0:f4:b0:e3:c1:a5:b5:d4:c3:e0:f5";
      # turn.turnServer.user = "jono";
      # turn.turnServer.password = "jono";
    };

    nextcloud = {
      enable = false;
      configureRedis = true;
      hostName = "localhost";
      home = "/dpool/nextcloud/data";

      https = true;

      database.createLocally = true;

      autoUpdateApps.enable = true;

      package = pkgs.nextcloud30;

      config = {
        overwriteProtocol = "https";
        dbtype = "mysql";
        adminpassFile = "/etc/nextcloud-admin-pass";
      };

      settings.trusted_domains = [ "zeeba" "zeeba.wolf-typhon.ts.net"];
      enableImagemagick = true;

      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps) contacts calendar tasks mail notes spreed memories;
      };
      extraAppsEnable = true;
    };

  };

  networking.hostId = "796e3c6a"; # needed for zfs support

  networking.hostName = "zeeba";

  imports = [ 
    ./hardware-configuration.nix
    ./web.nix
    ../../modules/common-nixos.nix
    ../../modules/home-lan.nix
    ../../modules/syncthing.nix
  ];

}
