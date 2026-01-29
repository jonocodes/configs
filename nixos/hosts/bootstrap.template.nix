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

  networking.firewall.enable = false;

  environment.systemPackages = with pkgs; [
    librewolf # a browser is only needed for first time syncthing config
    vim
    nh
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  services = {

    tailscale.enable = true;

    syncthing = {

      enable = true; 

      guiAddress = "0.0.0.0:8388";

      user = "jono";
      dataDir = "/home/jono/sync";
      configDir = "/home/jono/sync/.config/syncthing";

      settings = {

        gui = {
          tls = false;
          theme = "default";
        };
        options = {
          listenAddresses = [ "tcp://0.0.0.0:22001" "quic://0.0.0.0:22001" ];
        };

        devices = {  # NOT WORKING. this should break
          "choco" = {
            id = "ITAESBW-TIKWVEX-ITJPOWT-PM7LSDA-O23Q2FO-6L5VSY2-3UW5VM6-I6YQAAR";
          };

          # zeeba.id = "FHJMBVS-QFCCTVG-XQCQTCB-RTX6I37-B76EXZ7-Y7VSFBZ-YT5QWFK-4XQVGAH";
        };

        folders = {
          "configs" = {
            path = "/home/jono/sync/configs";
            devices = [ "choco" ];
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
