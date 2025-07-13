# https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS.html
# https://github.com/ne9z/dotfiles-flake/tree/2e39ad6ee4edebf7f00e4bf76d35c56d98f78fd7

{ pkgs, pkgs-unstable, inputs, ... }:
let
  inherit (inputs) self;

  vars = import ../vars.nix;
  jonoHome = vars.jonoHome;

in {

  # not sure why, but I needed to do this to use caches in devenv with php ?
  nix.settings.trusted-users = [ "root" "jono" ];

  # root/system garbage collector
  nix.gc.automatic = true;
  nix.gc.dates = "daily";
  nix.gc.options = "--delete-older-than 7d";

  # NOTE: sops would be a good way to handle secrets once I need it. syncthing was wonky so not using it there.
  # sops = {
  #   age.keyFile = "${jonoHome}/sync/common/private/sops-age-keys.txt";
  #   defaultSopsFile = ../../secrets.yaml;
  #   secrets.syncthing_gui_pass = {};
  # };

  # users.users = {

  #   jono = {
  #     isNormalUser = true;
  #     description = "jono";
  #     extraGroups = [ "networkmanager" "wheel" "docker" ];
  #     shell = pkgs.fish;
  #   };
  #   # backup = {
  #   #   description = "user for pull backups with sanoid";
  #   #   shell = pkgs.bash;
  #   #   group = "backup";
  #   #   isSystemUser = true;
  #   # };
  # };

  # users.groups.backup = {};

  ## enable ZFS auto snapshot on datasets (alternative to sanoid)
  ## You need to set the auto snapshot property to "true"
  ## on datasets for this to work, such as
  # zfs set com.sun:auto-snapshot=true rpool/nixos/home
  services.zfs = {
    autoSnapshot = {
      enable = false;
      flags = "-k -p --utc";
      monthly = 48;
    };
  };

  boot.zfs.extraPools = [ "dpool" ];

  boot.zfs.forceImportRoot = false;
  boot.initrd.systemd.enable = true;

  services.duplicati = {
    # run as user to read home dir
    enable = true;
    user = "jono";
  };

  # encrypted data drive. aka /dev/disks/by-id/ata-WDC_WD20EZRX-00D8PB0_WD-WCC4N1390887-part1
  # environment.etc.crypttab.text =
  #   "datadrive UUID=a8271935-0b31-44a6-8ed8-5627626ea945 /home/jono/sync/configs/nix/hosts/dobro/files/secondary-hd.keyfile luks";

  # local nas
  fileSystems."/media/nas_backup" = {
    device = "nas.alb:/shares/backup";
    fsType = "nfs";
  };

  # offsite backup drive
  fileSystems."/media/berk_nas" = {
    device = "//192.168.1.140/jono";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      automount_opts =
        "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=15s,x-systemd.mount-timeout=15s";

    in [
      "${automount_opts},nofail,uid=jono,gid=users,credentials=/etc/samba/credentials/berk"
    ];
  };

  digitus.services = {
    syncthing = {

      enable = true;

      folderDevices = {

        common = { devices = [ "choco" "zeeba" "orc" "galaxyS23" ]; };
        
        more = { devices = [ "choco" "zeeba" "orc" ]; };
        
        camera = {
          path = "/dpool/camera/JonoCameraS23";
          devices = [ "galaxyS23" ];
        };

        configs = { devices = [ "choco" "zeeba" "orc" ]; };
        
        savr_data = {
          devices = [ "choco" "zeeba" "galaxyS23" ];
        };
      };

    };
  };

  services = {

    davfs2.enable = true;

    sanoid = {
      enable = true;

      package = pkgs.sanoid;

      # manually run> sudo zfs allow -u backup send,snapshot,hold dpool

      datasets = {
        "dpool/thunderbird_data" = {
          recursive = true;
          hourly = 24;
          daily = 7;
          monthly = 3;
          autoprune = true;
          autosnap = true;
        };
      };

    };

    syncoid = {
      enable = true;

      # I think there is some permissions issue with the identity file, so this may not be working

      user = "jono";
      sshKey = "${jonoHome}/.ssh/id_ed25519";
      commands = {
        "backup-thunderbird" = {
          source = "dpool/thunderbird_data";
          target = "backup@zeeba:dpool/dobro/thunderbird_data";
          recursive = true;
          # extraArgs = [ "--compress" ];
          sendOptions = "v";
          recvOptions = "v";
        };
      };
    };

  };


  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  };

  environment.systemPackages = with pkgs; [
    iftop
    util-linux

    e2fsprogs

    # these are needed for synciod (shouldnt they be included in that package?)
    lzop
    mbuffer

  ];

  zfs-root = {
    boot = {
      devNodes = "/dev/disk/by-id/";
      bootDevices = [ "ata-SanDisk_SSD_PLUS_1000GB_23370R800944" ];
      immutable.enable = false;
      removableEfi = true;
      luks.enable = true;
    };
  };

  boot.initrd.availableKernelModules =
    [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelParams = [ ];

  networking.hostId = "6dce6507";

  networking.hostName = "dobro";

  # import preconfigured profiles
  imports = [
    inputs.nix-flatpak.nixosModules.nix-flatpak

    ./boot.nix
    ./fileSystems.nix

    ../../modules/common-nixos.nix
    ../../modules/linux-desktop.nix
    ../../modules/syncthing.nix

    ../../modules/gnome.nix
    #../../modules/kde.nix

  ];

}
