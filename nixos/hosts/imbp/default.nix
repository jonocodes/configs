{ pkgs, pkgs-unstable, inputs, modulesPath, nixos-hardware, ... }:
let

  syncthingIgnores = builtins.readFile ../../files/syncthingIgnores.txt;

in {

  networking.hostName = "imbp";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;


  # TODO: switch command and control? probably with .xmodmap
  # https://github.com/NixOS/nixos-hardware/tree/master/apple#switching-cmd-and-altaltgr
  boot.kernelParams = [
    "hid_apple.swap_opt_cmd=1"
  ];

  hardware.enableAllFirmware = true;

  environment.systemPackages = with pkgs; [
    broadcom-bt-firmware
  ];


  digitus.services = {

    syncthing = {
      enable = true;
      folderDevices = {
        common = {
          devices = [ "choco" "dobro" ];
          versioned = true;
        };
        more = {
          devices = [ "choco" "dobro" ];
        };
        configs = {
          devices = [ "choco" "dobro" ];
          versioned = true;
        };
        savr_data = {
          devices = [ "choco" "dobro" ];
        };

      };
    };

  };

  imports = [

    (let inherit (inputs) nixos-hardware; in nixos-hardware.nixosModules.apple-t2)

    inputs.nix-flatpak.nixosModules.nix-flatpak

    ./hardware-configuration.nix
    ../../modules/common-nixos.nix
    ../../modules/syncthing.nix

     ../../modules/linux-desktop.nix
    ../../modules/kde.nix

  ];

}
