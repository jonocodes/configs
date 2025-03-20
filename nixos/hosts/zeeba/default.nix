{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
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
          devices = [ "choco" "dobro" "galaxyS23" "pop-mac" ];
          versioned = true;
        };
        more = {
          devices = [ "choco" "dobro" "pop-mac" ];
        };
        configs = {
          devices = [ "choco" "dobro" "pop-mac" ];
          versioned = true;
        };
        savr_data = {
          devices = [ "choco" "dobro" "galaxyS23" "pop-mac" ];
        };

      };
    };

  };

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

  };

  networking.hostId = "796e3c6a"; # needed for zfs support

  networking.hostName = "zeeba";

  imports = [ 
    ./hardware-configuration.nix
    ../../modules/common-nixos.nix
    ../../modules/syncthing.nix
  ];

}
