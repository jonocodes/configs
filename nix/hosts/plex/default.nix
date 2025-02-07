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

  domain = "plex.dgt.is";
in {

  boot.loader.grub = {
    enable = true;
    # device = "/dev/sda"; # TODO: change to uuid ?
    device = "/dev/disk/by-id/ata-SAMSUNG_SSD_PM830_2.5__7mm_128GB_S0TYNSAD111479";
    useOSProber = true; 
  };

  users.users = {
    jono = {
      isNormalUser = true;
      description = "jono";
      extraGroups = [ "networkmanager" "wheel" "docker" ];
      shell = pkgs.fish;
    };
  };

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "mypool" ];
  boot.zfs.forceImportRoot = false;

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
    home.stateVersion = "23.11";

    home.file = {
      "sync/configs/.stignore".text = syncthingIgnores;
    };

    programs.ssh.enable = true;

    programs.ssh.matchBlocks = {
      "john.example.com" = {
        hostname = "example.com";
        user = "john";
      };
    };

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
          "nix build --out-link /tmp/result --dry-run /home/jono/sync/configs/nix#nixosConfigurations.plex.config.system.build.toplevel && nix build --out-link /tmp/result /home/jono/sync/configs/nix#nixosConfigurations.plex.config.system.build.toplevel && nvd diff /run/current-system /tmp/result";

        # switch brings in flake file changes. as well as the last 'build'
        os-switch = "sudo nixos-rebuild switch -v --flake /home/jono/sync/configs/nix";

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
    ../../modules/common-nixos.nix
  ];



  # TODO: https://nixos.wiki/wiki/Impermanence



  ##  MAILSERVER

  # https://github.com/NixOS/nixpkgs/blob/6fe145f2d0c2623f545fe04951355268a8e7fea0/nixos/tests/stalwart-mail.nix#L2
  services.stalwart-mail = {
    enable = false;
    package = pkgs-unstable.stalwart-mail;


    # TODO: tls, acme. management service for cli
    #   ie - stalwart-cli --url http://localhost:9990 queue list

    settings = {
      # certificate."snakeoil" = {
      #   cert = "file://${certs.${domain}.cert}";
      #   private-key = "file://${certs.${domain}.key}";
      # };
      server = {
        hostname = domain;
        # tls = {
        #   certificate = "snakeoil";
        #   enable = true;
        #   implicit = false;
        # };
        listener = {
          "smtp-submission" = {
            bind = [ "[::]:587" ];  # formerly postfix?
            protocol = "smtp";
          };
          "imap" = {
            bind = [ "[::]:143" ];  # formerly dovecot?
            protocol = "imap";
          };
          "jmap" = {
            url = "0.0.0.0:8080";
            bind = [ "[::]:8080" ]; # for cli management I think
            protocol = "jmap";
          };
        };
      };
      session = {
        rcpt.directory = "in-memory";
        auth = {
          mechanisms = [ "PLAIN" ];
          directory = "in-memory";
        };
      };
      jmap.directory = "in-memory";
      queue.outbound.next-hop = [ "local" ];
      directory."in-memory" = {
        type = "memory";
        users = [
          {
            name = "jono";
            secret = "foobar";
            email = [ "jono@${domain}" ];
          }
        ];
      };

      # storage.data = "rocksdb";

      store."data" = {
        type = "rocksdb";
        # path = "/home/jono/stalwart/data";
        path = "/var/lib/stalwart-mail/data";
        disable = false;
      };


# ectory /home/jono/stalwart/data: Os { code: 13, kind: PermissionDenied, message: "Permission denied" }
# Apr 11 06:02:01 plex stalwart-mail[235389]: Invalid configuration: Failed to create index directory /home/jono/stalwart/data: Os { code: 13, kind: PermissionDenied, message: "Permission denied" }


      # store."filesystem" = {
      #   type = "fs";
      #   path = "/jono/jono/stalwart/blobs";
      #   depth = 2;
      # };

    };
  };

}
