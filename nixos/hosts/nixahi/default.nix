{ pkgs, pkgs-unstable, inputs, modulesPath, nixos-hardware, ... }:
let


in {

  networking.hostName = "nixahi";

  # system.stateVersion = "25.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  hardware.asahi = {
    useExperimentalGPUDriver = true;
  };

  networking.wireless.iwd = {
	  enable = true;
  	settings.General.EnableNetworkConfiguration = true;
  };

  networking.hosts = {
    "198.54.114.213" = ["rokeachphoto.com"];
  };

  # TODO: switch command and control? probably with .xmodmap
  # https://github.com/NixOS/nixos-hardware/tree/master/apple#switching-cmd-and-altaltgr
  # boot.kernelParams = [
  #   "hid_apple.swap_opt_cmd=1"
  # ];

  # NOTE: used pkgs.asahi-nvram to silence the apple boot

  environment.systemPackages = with pkgs-unstable; [

    # postgresql
    libpq

  ] ++ (with pkgs; [
    asahi-nvram

    vim

  ]);


  digitus.services = {

    syncthing = {
      enable = true;
      folderDevices = {
        common = {
          devices = [ "choco" ];
          versioned = true;
        };
        more = {
          devices = [ "choco" ];
        };
        configs = {
          devices = [ "choco" ];
          versioned = true;
        };
        # savr_data = {
        #   devices = [ "choco" ];
        # };

      };
    };

  };

  imports = [

    inputs.nix-flatpak.nixosModules.nix-flatpak

    ./apple-silicon-support-2025-05-30
    ./hardware-configuration.nix
    
    ../../modules/common-nixos.nix
    ../../modules/syncthing.nix

    ../../modules/linux-desktop.nix
    ../../modules/kde.nix

  ];

}
