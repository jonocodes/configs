# https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS.html
# https://github.com/ne9z/dotfiles-flake/tree/2e39ad6ee4edebf7f00e4bf76d35c56d98f78fd7

{ pkgs, pkgs-unstable, inputs, ... }:
let
  inherit (inputs) self;

  # local = self.packages;

  vars = import ../vars.nix;
  jonoHome = vars.jonoHome;

  # zeebaVars = import ../zeeba/vars.nix;
  # zeebaSyncthingId = (import ../zeeba/vars.nix).syncthingId;

  # jonoHome = "/home/jono";

  syncthingIgnores = builtins.readFile ../../files/syncthingIgnores.txt;

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

        common = { devices = [ "choco" "zeeba" "orc" "galaxyS23" "pop-mac" ]; };
        
        more = { devices = [ "choco" "zeeba" "orc" "pop-mac" ]; };
        
        camera = {
          path = "/dpool/camera/JonoCameraS23";
          devices = [ "galaxyS23" ];
        };

        configs = { devices = [ "choco" "zeeba" "orc" "pop-mac" ]; };
        
        savr_data = {
          devices = [ "choco" "zeeba" "galaxyS23" "pop-mac" ];
        };
      };

    };
  };

  services = {

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

  environment.systemPackages = with pkgs; [
    iftop
    util-linux

    # these are needed for synciod (shouldnt they be included in that package?)
    lzop
    mbuffer

    inputs.flox.packages.${pkgs.system}.default
  ];

  home-manager.users.jono = { config, lib, pkgs, ... }: {
    imports = [ ../../modules/user-jono.nix ];

    fonts.fontconfig.enable = false;

    home.file.".thunderbird".source =
      config.lib.file.mkOutOfStoreSymlink /dpool/thunderbird_data;

    home.file = {
      "sync/common/.stignore".text = syncthingIgnores;
      "sync/configs/.stignore".text = syncthingIgnores;
      "sync/more/.stignore".text = syncthingIgnores;
      "sync/savr_data/.stignore".text = syncthingIgnores;
    };

    # apps specific to this host
    home.packages = with pkgs-unstable;
      [

        hunspellDicts.en_US
        flyctl

        rclone
        rclone-browser # TODO: declarative config for /home/jono/.config/rclone . see https://github.com/nix-community/home-manager/pull/6101
        # pcmanfm # lightweight file manager, with right click tar
        numix-icon-theme
        numix-icon-theme-square

        devenv
        # nixpkgs-fmt # depricated to nixfmt
        nixfmt # depricated to nixfmt-classic ?
        alejandra
        nixd

        chromium
        element-desktop
        trayscale
        #      syncthing-tray
        telegram-desktop
        # vscodium
        vscode # needed for dev containers
        thunderbird-bin
        # jetbrains.pycharm-professional

        ghostty
        (lib.hiPrio
          windsurf) # https://github.com/NixOS/nixpkgs/issues/356478#issuecomment-2559417152
        comma  # run uninstalled apps ie > , xeyes

        warp-terminal

        android-studio

        #   nix binary runner helpers
        # nix-index
        # nix-locate
        steam-run # x86 only
        # nodejs_22
      ] ++ (with pkgs;
        [

          tilix # temp moved here because compile problem on 9/15/24
        
          # TODO: move to flatpak?
          firefox-bin

          # android-studio # very old version, 2023
          # android-studio-full  # this takes so long to install because it has to build arm v8 every time
        ]);


        
      services.flatpak = {

        packages = [

          "com.github.tchx84.Flatseal"

          "io.dbeaver.DBeaverCommunity"
          "io.github.aandrew_me.ytdn" # video downloader
          "com.github.unrud.VideoDownloader"

          "org.gnome.meld"

          "org.videolan.VLC"
          "org.gimp.GIMP"
          "io.gitlab.adhami3310.Impression"
          "com.spotify.Client"
          "org.sqlitebrowser.sqlitebrowser"

          "org.keepassxc.KeePassXC"

          "org.gnome.baobab" # gnome disk util
          "org.libreoffice.LibreOffice" # for editing csv
          #      "com.github.xournalpp.xournalpp"  # for editing pdfs
          "com.usebruno.Bruno"
          "org.gnome.gitlab.cheywood.Buffer" # text editor

          "org.signal.Signal"
          "com.ticktick.TickTick"
          "md.obsidian.Obsidian"
          "net.lutris.Lutris"
          "us.zoom.Zoom"
          "com.slack.Slack"

          "io.github.ungoogled_software.ungoogled_chromium"

          "de.schmidhuberj.Flare" # signal client

          "com.jetbrains.PyCharm-Professional"

          "io.github.mhogomchungu.media-downloader"

        ];
      };

  };

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
