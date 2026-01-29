{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

in {

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  digitus.services = {
    syncthing = {

      enable = true;

      folderDevices = {

        # common = { devices = [ "choco" ]; };
        
        # more = { devices = [ "choco" ]; };

        configs = { devices = [ "choco" ]; };
        
      };
    };
  };

  networking.hostName = "ocarina";

  imports = [ 
    ./hardware-configuration.nix
    ./router.nix
    ../../modules/common-nixos.nix
    ../../modules/syncthing.nix
  ];

}
