{ pkgs, pkgs-unstable, inputs, modulesPath, sharedModulesPath ? ../../modules, ... }:
let
  inherit (inputs) self;

in {

  boot.loader.grub = {
    enable = true;
    # device = "/dev/sda"; # TODO: change to uuid ?
    device = "/dev/disk/by-id/ata-SAMSUNG_SSD_PM830_2.5__7mm_128GB_S0TYNSAD111479";
    useOSProber = true; 
  };

  boot.supportedFilesystems = [ "zfs" ];
  # boot.zfs.extraPools = [ "mypool" ];
  boot.zfs.forceImportRoot = false;

  digitus.services = {
    syncthing = {

      enable = true;

      folderDevices = {

        common = { devices = [ "choco" ]; };
        
        more = { devices = [ "choco" ]; };

        configs = { devices = [ "choco" ]; };
        
      };
    };
  };

  # boot.initrd.availableKernelModules =
  #   [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  # boot.kernelParams = [ ];

  networking.hostId = "6c5d7bdd"; # needed for zfs support

  networking.hostName = "plex";

  imports = [ 
    ./hardware-configuration.nix
    ./router.nix
    (sharedModulesPath + "/common-nixos.nix")
    (sharedModulesPath + "/syncthing.nix")
  ];

}
