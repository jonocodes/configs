{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

  jonoHome = "/home/jono";

  # syncthingGuiPass = "$2a$10$ucKVjnQbOk9E//OmsllITuuDkQKkPBaL0x39Zuuc1b8Kkn2tmkwHm";

  syncthingIgnores = builtins.readFile ../../files/syncthingIgnores.txt;

in {

  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;

  documentation.enable = false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };


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

  # users.users = {
  #   # jono = {
  #   #   isNormalUser = true;
  #   #   description = "jono";
  #   #   extraGroups = [ "networkmanager" "wheel" "docker" ];
  #   #   shell = pkgs.fish;
  #   # };

  #   jono.openssh.authorizedKeys.keys = [
  #     # dobro
  #     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGI9g+ml4fmwK8eNYe7qb7lWHlqZ4baVc5U6nkMCbnG jono@foodnotblogs.com"
  #     # oracle
  #     "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDW4SMTIQQChTCFL/SJKkOp9mejFiCih0cNjT3mirFLcuuGPiH/jlp/h6312238Piea737cgbt0c70Jt1S7F/zmsKVU9rQPk/kluOoE5jMJLoOqZeUxxRmZVYs1ebxeSoI2MHQGv+9U0YjKMCvKfQfT5IDm9sjRtcfodo81RbUOayCvc3Kq4B6iUe1A4/UbNXlHEzsbIVpn3fcgzAYynuzCkQ/rzMfNwIz8JTs4oxs4WVo0hmCyqcrpQqsXUQ8OXrIim/EQaJgQp+1Y7c7r9eMjV3HzQBWfd4sKTROcAUXgff0uW6ieArIuugOnDjE/ipxI0n1b9PQGg1b0ZkqZo2Nj ssh-key-2025-02-18"
  #   ];

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

  services = {

    # open web ui is run with docker manually
    #   docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main

    ollama = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
    };

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
