{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

in {

  users.users = {
    jono = {
      isNormalUser = true;
      description = "jono";
      extraGroups = [ "networkmanager" "wheel" ];
      # shell = pkgs.fish;
    };
  };

  services = {
    syncthing = {

      enable = true;
      user = "jono";
      dataDir = "/home/jono/sync";
      configDir = "/home/jono/.config/syncthing";

      overrideDevices = true;
      overrideFolders = true;

      guiAddress = "0.0.0.0:8384";

      settings = {
        
        folders = {
          "configs" = {
            path = "/home/jono/sync/configs";
            devices = [ "choco" ];
          };
        };

        devices = {
          "choco" = {
            id =
              "ITAESBW-TIKWVEX-ITJPOWT-PM7LSDA-O23Q2FO-6L5VSY2-3UW5VM6-I6YQAAR";
          };
        };

      };

    };
  };

  # networking.hostId = "6c5d7bdd"; # only needed for zfs support

  networking.hostName = "nixhost";

  imports = [
    ./hardware-configuration.nix
    # ../../modules/common-nixos.nix
  ];

}
