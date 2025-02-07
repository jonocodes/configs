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

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  boot.initrd.luks.devices."luks-3182ebfb-c9f0-43c9-ab02-ad238222f389".device = "/dev/disk/by-uuid/3182ebfb-c9f0-43c9-ab02-ad238222f389";
  # Setup keyfile
  boot.initrd.secrets = {
    "/boot/crypto_keyfile.bin" = null;
  };

  boot.loader.grub.enableCryptodisk = true;

  boot.initrd.luks.devices."luks-be4c2dd3-f01c-497f-a9c4-61622840e246".keyFile = "/boot/crypto_keyfile.bin";
  boot.initrd.luks.devices."luks-3182ebfb-c9f0-43c9-ab02-ad238222f389".keyFile = "/boot/crypto_keyfile.bin";

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
          password = "$2a$10$ucKVjnQbOk9E//OmsllITuuDkQKkPBaL0x39Zuuc1b8Kkn2tmkwHm";
        };

        folders = {
          "configs" = {
            path = "/home/jono/sync/configs";
            devices = [ "choco" ];
          };
          "common" = {
            path = "/home/jono/sync/common";
            devices = [ "choco" ];
          };
          "more" = {
            path = "/home/jono/sync/more";
            devices = [ "choco"  ];
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

    # apps specific to this host
    home.packages = with pkgs-unstable;
    [
      nodejs_22
    ] ++ (with pkgs; [
      # android-studio-full
    ]);


    programs.fish = {
      enable = true;

      interactiveShellInit = ''
        set fish_greeting # Disable greeting
      '';

      shellInit = ''
        # eval /home/jono/.conda/bin/conda "shell.fish" "hook" $argv | source

        set -x POPULUS_ENVIRONMENT dev
        set -x POPULUS_DATACENTER us

        # set -x NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE 1
      '';

      shellAbbrs = {
        cat = "bat";
        p = "ping google.com"; # "ping nixos.org";

        "..." = "cd ../..";

        u = "sudo date && os-update && time os-build && os-switch";

        pop-devenv = "nix develop --impure path:$HOME/sync/configs/devenv/nix-populus-conda";

        # conda-sh = "conda-shell -c fish";
        conda-populus =
          "conda activate populus-env && alias python=/home/jono/.conda/envs/populus-env/bin/python";

      };

      shellAliases = {

        # update the checksum of the repos
        os-update = "cd /home/jono/sync/configs/nix && nix flake update && cd -";

        # list incoming changes, compile, but dont install/switch to them
        os-build =
          "nix build --out-link /tmp/result --dry-run /home/jono/sync/configs/nix#nixosConfigurations.t430.config.system.build.toplevel && nix build --out-link /tmp/result /home/jono/sync/configs/nix#nixosConfigurations.t430.config.system.build.toplevel && nvd diff /run/current-system /tmp/result";

        # switch brings in flake file changes. as well as the last 'build'
        os-switch = "sudo nixos-rebuild switch -v --flake /home/jono/sync/configs/nix";

      };

    };


    programs.git = {
      enable = true;
      userName = "Jono";
      userEmail = "jono@foodnotblogs.com";
      lfs.enable = true;
    };


  };

  # boot.initrd.availableKernelModules =
  #   [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  # boot.kernelParams = [ ];

  networking.hostName = "t430";

  imports = [ 
    ./hardware-configuration.nix
    ../../modules/common-nixos.nix
    ../../modules/gnome.nix
     ../../modules/linux-desktop.nix
  ];

}
