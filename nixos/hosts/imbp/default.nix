{ pkgs, pkgs-unstable, inputs, modulesPath, nixos-hardware, ... }:
let

  # syncthingIgnores = builtins.readFile ../../files/syncthingIgnores.txt;

in {

  networking.hostName = "imbp";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;


  # TODO: switch command and control? probably with .xmodmap
  # https://github.com/NixOS/nixos-hardware/tree/master/apple#switching-cmd-and-altaltgr
  # boot.kernelParams = [
  #   "hid_apple.swap_opt_cmd=1"
  # ];

  hardware.enableAllFirmware = true;

  # hardware.bluetooth.enable = true; # enables support for Bluetooth
  # hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

  # trying to swap command/control to be more mac like. not working though
  # this actually switched option/control. not quite right
  # services.xserver.xkbOptions = "ctrl:swap_lwin_lctl,ctrl:swap_rwin_rctl";


  services.xserver.xkbOptions = "ctrl:swap_lalt_lctl"; #,altwin:ctrl_win";  # ctrl:ralt, alt:rwin, rwin:ralt, altwin:ralt


  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ]; # Applies to all keyboards
        settings = {
          main = {
            "rightmeta" = "rightctrl"; # Remap the right Command key (rightmeta) to Control_R
          };
        };
      };
    };
  };



  # services.xserver = {
  #   enable = true;
  #   xkb.options = "ctrl:swap_lctl_lwin"; # Swaps Left Control and Left Command
  # };

  # services.xserver.xkb.options = "ctrl:swap_lctl_lwin,ctrl:swap_rctl_rwin";




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
