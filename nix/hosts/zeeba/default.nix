{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

  jonoHome = "/home/jono";

  # syncthingGuiPass = "$2a$10$ucKVjnQbOk9E//OmsllITuuDkQKkPBaL0x39Zuuc1b8Kkn2tmkwHm";

  syncthingIgnores = builtins.readFile ../../files/syncthingIgnores.txt;

in {

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users = {
    # jono = {
    #   isNormalUser = true;
    #   description = "jono";
    #   extraGroups = [ "networkmanager" "wheel" "docker" ];
    #   shell = pkgs.fish;
    # };

    # jono.openssh.authorizedKeys.keys = [
    #   # dobro
    #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGI9g+ml4fmwK8eNYe7qb7lWHlqZ4baVc5U6nkMCbnG jono@foodnotblogs.com"
    #   # oracle
    #   "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDW4SMTIQQChTCFL/SJKkOp9mejFiCih0cNjT3mirFLcuuGPiH/jlp/h6312238Piea737cgbt0c70Jt1S7F/zmsKVU9rQPk/kluOoE5jMJLoOqZeUxxRmZVYs1ebxeSoI2MHQGv+9U0YjKMCvKfQfT5IDm9sjRtcfodo81RbUOayCvc3Kq4B6iUe1A4/UbNXlHEzsbIVpn3fcgzAYynuzCkQ/rzMfNwIz8JTs4oxs4WVo0hmCyqcrpQqsXUQ8OXrIim/EQaJgQp+1Y7c7r9eMjV3HzQBWfd4sKTROcAUXgff0uW6ieArIuugOnDjE/ipxI0n1b9PQGg1b0ZkqZo2Nj ssh-key-2025-02-18"
    # ];

    backup = {

      # NOTE: manually test backup send from dobro
      # dobro>  zfs send dpool/thunderbird_data@autosnap_2025-02-02_05:46:11_hourly | pv | ssh backup@zeeba zfs recv -F "dpool/dobro/test"

      description = "user to receive backups";
      shell = pkgs.bash;
      group = "backup";
      isSystemUser = true;

      # TODO: restrict executable actions
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGI9g+ml4fmwK8eNYe7qb7lWHlqZ4baVc5U6nkMCbnG jono@foodnotblogs.com"  # for backing up from dobro
      ];
    };

  };


  users.groups.backup = {};

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "dpool" ];
  boot.zfs.forceImportRoot = false; # mounts datasets instead of pools


  digitus.services = {

    syncthing = {
      enable = true;
      folderDevices = {
        common = {
          # path = "/home/jono/sync/common";  # TODO: remove
          devices = [ "choco" "dobro" "galaxyS23" "pop-mac" ];
          versioned = true;
        };
        more = {
          devices = [ "choco" "dobro" "pop-mac" ];
        };
        configs = {
          # path = "/home/jono/sync/configs";
          devices = [ "choco" "dobro" "pop-mac" ];
          versioned = true;
        };
        savr_data = {
          # path = "/home/jono/sync/savr_data";
          devices = [ "choco" "dobro" "galaxyS23" "pop-mac" ];
        };

      };
    };

  };

  services = {

    # open web ui is run with docker manually
    #   docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main

    ollama = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
    };

    sanoid = {
      enable = true;
    };

    # syncthing = {

    #   enable = true;
    #   user = "jono";
    #   dataDir = "${jonoHome}/sync";
    #   configDir = "${jonoHome}/.config/syncthing";

    #   overrideDevices = true;
    #   overrideFolders = true;

    #   guiAddress = "0.0.0.0:8384";

    #   settings = {

    #     gui = {
    #       user = "admin";
    #       password = syncthingGuiPass;
    #     };

    #     folders = {

    #       "common" = {
    #         path = "${jonoHome}/sync/common";
    #         devices = [ "choco" "dobro" "galaxyS23" "pop-mac" ];
    #       };

    #       "more" = {
    #         path = "${jonoHome}/sync/more";
    #         devices = [ "choco" "dobro" "pop-mac" ];
    #       };

    #       "configs" = {
    #         path = "${jonoHome}/sync/configs";
    #         devices = [ "choco" "dobro" "pop-mac" ];
    #       };

    #       "savr_data" = {
    #         path = "${jonoHome}/sync/savr_data";
    #         devices = [ "choco" "dobro" "galaxyS23" "pop-mac" ];
    #       };

    #     };

    #     devices = {
    #       "choco".id = "ITAESBW-TIKWVEX-ITJPOWT-PM7LSDA-O23Q2FO-6L5VSY2-3UW5VM6-I6YQAAR";
          
    #       "dobro".id = "IVBFEHN-WLC4YLP-QQ66IFS-PKTKVJD-OMFKMXM-R64H5A6-MRLY5CU-TUEYGQJ";

    #       "pop-mac".id = "N7XVA3T-WPY2XRB-P44F7KS-CEFRIDX-KK6DEYQ-UM2URKO-DVA2G2O-FLO6IAV";
        
    #       "galaxyS23".id = "GNT4UMD-JUYX45B-ODZXIZL-Q4JBCN5-DR5FEEI-LKLP667-VYEEJLP-GF4UCQO";

    #     };

    #   };

    # };

  };

  home-manager.users.jono = {config, ...}: {
    # The home.stateVersion option does not have a default and must be set, bummer
    home.stateVersion = "24.11";

    home.file = {
      "sync/common/.stignore".text = syncthingIgnores;
      "sync/configs/.stignore".text = syncthingIgnores;
      "sync/more/.stignore".text = syncthingIgnores;
      "sync/savr_data/.stignore".text = syncthingIgnores;
    };

    home.packages = with pkgs-unstable;
      [
        # atuin
        helix
        # devenv
      ] ++ (with pkgs; [

        lzop # for syncoid compression
        mbuffer
      ]);

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
          "nix --experimental-features 'nix-command flakes' build --out-link /tmp/result --dry-run /home/jono/sync/configs/nix#nixosConfigurations.$hostname.config.system.build.toplevel && nix --experimental-features 'nix-command flakes' build --out-link /tmp/result /home/jono/sync/configs/nix#nixosConfigurations.$hostname.config.system.build.toplevel && nvd diff /run/current-system /tmp/result";

        # switch brings in flake file changes. as well as the last 'build'
        os-switch = "sudo nixos-rebuild switch -v --flake /home/jono/sync/configs/nix";

      };

    };

  };


  networking.hostId = "796e3c6a"; # needed for zfs support

  networking.hostName = "zeeba";

  imports = [ 
    ./hardware-configuration.nix
    ../../modules/common-nixos.nix
    ../../modules/syncthing.nix
  ];

}
