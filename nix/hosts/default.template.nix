{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

  syncthingIgnores = ''
    .direnv
    .devenv
    .git
    .venv
    .DS_Store
    node_modules
    result
  '';

in {

  # boot.loader.grub = {
  #   enable = true;
  #   # device = "/dev/sda"; # TODO: change to uuid ?
  #   device = "/dev/disk/by-id/ata-SAMSUNG_SSD_PM830_2.5__7mm_128GB_S0TYNSAD111479";
  #   useOSProber = true; 
  # };

  users.users = {
    jono = {
      isNormalUser = true;
      description = "jono";
      extraGroups = [ "networkmanager" "wheel" "docker" ];
      shell = pkgs.fish;
    };
  };

  # boot.supportedFilesystems = [ "zfs" ];
  # boot.zfs.extraPools = [ "mypool" ];
  # boot.zfs.forceImportRoot = false;

  services = {
    syncthing = {

      enable = true;
      user = "jono";
      dataDir = "/home/jono/sync";
      configDir = "/home/jono/.config/syncthing";

      overrideDevices = true;
      overrideFolders = true;

      guiAddress = "0.0.0.0:8384";

      settings = {

        gui = {
          user = "admin";
          password = "bzS1tNPfeeXo5KnKEBwt";
        };

        folders = {
          "configs" = {
            path = "/home/jono/sync/configs";
            devices = [ "choco" ];
          };
        };

        devices = {
          "choco" = {
            id =
              "ITAESBW-TIKWVEX-ITJPOWT-PM7LSDA-O23Q2FO-6L5VSY2-3UW5VM6-I6YQAAR";
          };
        };

      };

    };
  };

  home-manager.users.jono = {config, ...}: {
    # The home.stateVersion option does not have a default and must be set
    home.stateVersion = "24.05";

    home.file = {
      "sync/configs/.stignore".text = syncthingIgnores;
    };

    programs.ssh.enable = true;


    programs.fish = {
      enable = true;

      interactiveShellInit = ''
        set fish_greeting # Disable greeting
      '';

      shellAbbrs = {
        cat = "bat";
        p = "ping google.com"; # "ping nixos.org";

        "..." = "cd ../..";

        u = "sudo date && os-update && time os-build && os-switch";
      };

      shellAliases = {

        # update the checksum of the repos
        os-update = "cd /home/jono/sync/configs/nix && nix flake update && cd -";

        # list incoming changes, compile, but dont install/switch to them
        os-build =
          "nix build --out-link /tmp/result --dry-run /home/jono/sync/configs/nix#nixosConfigurations.nixhost.config.system.build.toplevel && nix build --out-link /tmp/result /home/jono/sync/configs/nix#nixosConfigurations.nixhost.config.system.build.toplevel && nvd diff /run/current-system /tmp/result";

        # switch brings in flake file changes. as well as the last 'build'
        os-switch = "sudo nixos-rebuild switch -v --flake /home/jono/sync/configs/nix";

      };

    };

  };

  # boot.initrd.availableKernelModules =
  #   [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  # boot.kernelParams = [ ];

  networking.hostId = "6c5d7bdd"; # needed for zfs support

  networking.hostName = "nixhost";

  imports = [ 
    ./hardware-configuration.nix
    ../../modules/common-nixos.nix
  ];



  # TODO: https://nixos.wiki/wiki/Impermanence


}
