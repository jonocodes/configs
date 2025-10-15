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
  ];


  digitus.services = {

    syncthing = {
      enable = true;
      folderDevices = {
        common = {
          devices = [ "choco" ];
          versioned = true;
        };
      };
    };
  };

  services = {
    tailscale.enable = true;
  };

  # networking.hostId = "6c5d7bdd"; # only needed for zfs support

  networking.hostName = "nixhost";

  imports = [
    ./hardware-configuration.nix
    # ../../modules/common-nixos.nix
  ];

}
