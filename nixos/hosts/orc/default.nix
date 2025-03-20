{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

  # jonoHome = "/home/jono";

  # syncthingGuiPass = "$2a$10$ucKVjnQbOk9E//OmsllITuuDkQKkPBaL0x39Zuuc1b8Kkn2tmkwHm";

  # syncthingIgnores = builtins.readFile ../../files/syncthingIgnores.txt;

in {

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    initrd.systemd.enable = true;
  };


  documentation.enable = false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # environment.etc."nextcloud-admin-pass".text = "b8d3ad290bfa6fe407280587181a5167d71a2617";

  # services.nextcloud = {
  #   enable = true;
  #   package = pkgs.nextcloud30;
  #   hostName = "localhost";
  #   # database.createLocally = true;
  #   config.adminpassFile = "/etc/nextcloud-admin-pass";
  #   config.dbtype = "sqlite";
  # };

  # services.headscale = {
  #   enable = true;
  #   address = "0.0.0.0";
  #   port = 8080;
    
  #     settings = {
  #       dns = {
  #         magic_dns = false;
  #          base_domain = "dgt.is";
  #          };
  #       # server_url = "https://hs.dgt.is";
  #       # logtail.enabled = false;
  #     };
  # };

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


  # networking.hostId = "796e3c6a"; # needed for zfs support

  networking.hostName = "orc";

  imports = [ 
    ./hardware-configuration.nix
    # "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/v1.11.0.tar.gz"}/module.nix"
    ./disk-config.nix

    ../../modules/common-nixos.nix
    ../../modules/syncthing.nix
  ];

}
