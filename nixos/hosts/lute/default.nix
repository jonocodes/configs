{ pkgs, pkgs-unstable, inputs, ... }:
let
  inherit (inputs) self;

  # vars = import ../vars.nix;
  # jonoHome = vars.jonoHome;

in {

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-c8bb8fca-3b35-485a-9e71-e872bf697719".device = "/dev/disk/by-uuid/c8bb8fca-3b35-485a-9e71-e872bf697719";

  # not sure why, but I needed to do this to use caches in devenv with php ?
  # nix.settings.trusted-users = [ "root" "jono" ];

  # root/system garbage collector
  # nix.gc.automatic = true;
  # nix.gc.dates = "daily";
  # nix.gc.options = "--delete-older-than 7d";

  # networking.hosts = {
    # "198.54.114.213" = ["rokeachphoto.com"];
  # };

  # networking.extraHosts = ''
  #   198.54.114.213  rokeachphoto.com
  # '';


  # boot.supportedFilesystems."fuse.sshfs" = true;

  boot.supportedFilesystems = [ "zfs" ];

  # users.groups.backup = {};

  ## enable ZFS auto snapshot on datasets (alternative to sanoid)
  ## You need to set the auto snapshot property to "true"
  ## on datasets for this to work, such as
  # zfs set com.sun:auto-snapshot=true rpool/nixos/home
  # services.zfs = {
  #   autoSnapshot = {
  #     enable = false;
  #     flags = "-k -p --utc";
  #     monthly = 48;
  #   };
  # };

  # boot.zfs.extraPools = [ "dpool" ];

  boot.zfs.forceImportRoot = false;
  boot.initrd.systemd.enable = true;

  services.duplicati = {
    # run as user to read home dir
    enable = true;
    user = "jono";
  };

  # local nas
  fileSystems = {

    # NOTE: turned this off for a bit while I mess with different routers
    # "/media/nas_backup" = {
    #   device = "nas.alb:/shares/backup";
    #   fsType = "nfs";
    # };

    # # offsite backup drive (routed through matcha)
    # "/media/berk_nas" = {
    #   device = "//192.168.1.140/jono";
    #   fsType = "cifs";
    #   options = let
    #     # this line prevents hanging on network split
    #     automount_opts =
    #       "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=15s,x-systemd.mount-timeout=15s";

    #   in [
    #     "${automount_opts},nofail,uid=jono,gid=users,credentials=/etc/samba/credentials/berk"
    #   ];
    # };

    # "/media/matcha_home" = {
    #   device = "jono@matcha:/home/jono";
    #   fsType = "fuse.sshfs";
    #   options = [
    #     "reconnect"
    #     "allow_other"
    #     "x-systemd.automount"  # mount on first access?
    #     "IdentityFile=${jonoHome}/.ssh/id_ed25519"
    #   ];
    # };

    # offsite backup via direct ssh (more stable)
    # "/media/berk_nas_ssh" = {
    #   device = "sshd@192.168.1.140:/HD/HD_a2";
    #   fsType = "fuse.sshfs";
    #   options = [
    #     # "reconnect"
    #     # "allow_other"
    #     "IdentityFile=${jonoHome}/.ssh/id_ed25519"
    #     # "StrictHostKeyChecking=no"
    #     # "UserKnownHostsFile=/dev/null"
    #     # "uid=jono"
    #     # "gid=users"
    #   ];
    # };

  };


  digitus.services = {

    syncthing = {

      enable = true;

      folderDevices = {

        common = { devices = [ "choco" 
        #"zeeba" "orc" "galaxyS23" "matcha" 
        ]; };
        
        more = { devices = [ "choco" 
        #"zeeba" "orc" "matcha" 
        ]; };
        
        # camera = {
        #   path = "/dpool/camera/JonoCameraS23";
        #   devices = [ "galaxyS23" ];
        # };

        configs = { devices = [ "choco"
        # "zeeba" "orc" "matcha"
         ]; };
        
      };

    };
  };

  services = {

    davfs2.enable = true;

    # sanoid = {
    #   enable = true;

    #   package = pkgs.sanoid;

    #   # manually run> sudo zfs allow -u backup send,snapshot,hold dpool

    #   datasets = {
    #     "dpool/thunderbird_data" = {
    #       recursive = true;
    #       hourly = 24;
    #       daily = 7;
    #       monthly = 3;
    #       autoprune = true;
    #       autosnap = true;
    #     };
    #   };

    # };

    # syncoid = {
    #   enable = true;

    #   # I think there is some permissions issue with the identity file, so this may not be working

    #   user = "jono";
    #   sshKey = "${jonoHome}/.ssh/id_ed25519";
    #   commands = {
    #     "backup-thunderbird" = {
    #       source = "dpool/thunderbird_data";
    #       target = "backup@zeeba:dpool/dobro/thunderbird_data";
    #       recursive = true;
    #       # extraArgs = [ "--compress" ];
    #       sendOptions = "v";
    #       recvOptions = "v";
    #     };
    #   };
    # };

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


  boot.initrd.availableKernelModules =
    [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelParams = [ ];

  networking.hostId = "5943eb19";

  networking.hostName = "lute";

  # import preconfigured profiles
  imports = [
    ./hardware-configuration.nix
    inputs.nix-flatpak.nixosModules.nix-flatpak

    # ./boot.nix
    # ./fileSystems.nix

    ../../modules/common-nixos.nix
    ../../modules/home-lan.nix
    ../../modules/linux-desktop.nix
    ../../modules/syncthing.nix

    ../../modules/gnome.nix
    #../../modules/kde.nix

  ];

}
