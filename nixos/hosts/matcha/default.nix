
{ pkgs, pkgs-unstable, inputs, ... }:
let
  inherit (inputs) self;

in

{

  networking.hostName = "matcha";

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    initrd.systemd.enable = true;
    # kernel.sysctl."net.ipv4.ip_forward" = 1;
    # kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
  };


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    home-manager
  ];

  services.tailscale = {
    extraSetFlags = [
      "--advertise-routes=192.168.1.0/24"
      "--advertise-exit-node"
    ];
    useRoutingFeatures = "server";
  };

  digitus.services.syncthing = {
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

  # # Happy Coder daemon configuration
  # services.happy-coder = {
  #   enable = true;
  #   user = "jono";
  #   group = "users";
  #   homeDir = "/home/jono/.happy-coder";
  #   happyCommand = "/home/jono/.nix-profile/bin/happy";

  #   # Optional: Add any extra arguments
  #   # extraArgs = [ "--yolo" ];

  #   # Optional: Environment variables
  #   # environment = {
  #   #   HAPPY_LOG_LEVEL = "debug";
  #   # };
  # };

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      ../../modules/common-nixos.nix
      ../../modules/syncthing.nix
    ];

}
