{ lib, pkgs, pkgs-unstable, inputs, modulesPath, nixos-hardware, ... }:
let
  # Build asahi packages against 25.05 nixpkgs to avoid LLVM/Rust incompatibilities
  pkgs-asahi = import inputs.nixpkgs-asahi {
    system = "aarch64-linux";
    config.allowUnfree = true;
    overlays = [ (import ./apple-silicon-support-2025-05-30/packages/overlay.nix) ];
  };
in {

  networking.hostName = "nixahi";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  hardware.asahi = {
    useExperimentalGPUDriver = true;
    pkgs = lib.mkForce pkgs-asahi;
  };

  # pin syncthing to unstable to avoid config version downgrade issues
  services.syncthing.package = pkgs-unstable.syncthing;

  # fix service flags for syncthing 2.x (25.05 module generates 1.x-style flags)
  systemd.services.syncthing.serviceConfig.ExecStart = lib.mkForce (
    "${pkgs-unstable.syncthing}/bin/syncthing serve --no-browser --no-restart --gui-address=0.0.0.0:8388 --config=/home/jono/sync/.config/syncthing --data=/home/jono/sync/.config/syncthing"
  );

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
    pkgs-asahi.asahi-nvram

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
