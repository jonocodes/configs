
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

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      ../../modules/common-nixos.nix
      ../../modules/syncthing.nix
    ];


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
