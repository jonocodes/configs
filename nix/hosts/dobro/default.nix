# https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS.html
# https://github.com/ne9z/dotfiles-flake/tree/2e39ad6ee4edebf7f00e4bf76d35c56d98f78fd7

{ pkgs, pkgs-unstable, inputs, modulesPath, android-nixpkgs, nixpkgs, nix-flatpak, config, ... }:
let
  inherit (inputs) self;

  local = self.packages;

  jonoHome = "/home/jono";

  syncthingGuiPass = "$2a$10$ucKVjnQbOk9E//OmsllITuuDkQKkPBaL0x39Zuuc1b8Kkn2tmkwHm";

  syncthingIgnores = builtins.readFile ../../files/syncthingIgnores.txt;

  crossSecret = builtins.readFile /home/jono/sync/common/private/testsecret.txt;

  # androidSdkModule = import ((builtins.fetchGit {
  #   url = "https://github.com/tadfisher/android-nixpkgs.git";
  #   ref = "main";  # Or "stable", "beta", "preview", "canary"
  # }) + "/hm-module.nix");

in {

  # not sure why, but I needed to do this to use caches in devenv with php ?
  nix.settings.trusted-users = [ "root" "jono" ];

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
    options =
      let
        # this line prevents hanging on network split
        automount_opts =
          "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=15s,x-systemd.mount-timeout=15s";

      in
      [ "${automount_opts},nofail,uid=jono,gid=users,credentials=/etc/samba/credentials/berk" ];
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

    syncthing = {

      # TODO: make my own syncthing wrapper so I can programatically manage the syncthing network: https://github.com/Yeshey/nixOS-Config/blob/468f1f63f0efa337370d317901bb92fc421b3033/modules/nixos/mySystem/syncthing.nix#L173

      # NOTE: waiting on ability to do ignore inline: https://github.com/NixOS/nixpkgs/pull/353770


      # if there are sync issues, they can often be resolved like so> /nix/store/gij0yzbyi9d64rh4f62386fqd3x4nl8g-syncthing-1.28.0/bin/syncthing --reset-database

      enable = true;
      user = "jono";
      dataDir = "${jonoHome}/sync";
      configDir = "${jonoHome}/.config/syncthing";

      overrideDevices = true;
      overrideFolders = true;

      guiAddress = "0.0.0.0:8384";

      settings = {

        gui = {

          # TODO: once this merges I can move the password to sops. https://github.com/NixOS/nixpkgs/pull/290485

          user = "admin";

          # NOTE: syncthing config accepts raw or brcypt hashed password

          password = syncthingGuiPass;
        };

        defaults = {
          folder.path = "~/sync";
        };

        folders = {

          # NOTE: you need a corresponding .stignore file specified in home dir for each folder here

          "common" = {
            path = "${jonoHome}/sync/common";
            devices = [ "choco" "zeeba" "galaxyS23" "pop-mac" ];

            versioning = {
              type = "staggered";
              params = {
                cleanInterval = "3600";
                maxAge = "1";
              };
            };
          };
          "more" = {
            path = "${jonoHome}/sync/more";
            devices = [ "choco" "zeeba" "pop-mac" ];
          };
          "camera" = {
            path = "/dpool/camera/JonoCameraS23";
            devices = [ "galaxyS23" ];
          };
          # "phone_photos" = {
          #   path = "/dpool/camera/JonoCameraS20";
          #   devices = [ "galaxyS20" ];
          # };
          "configs" = {
            path = "${jonoHome}/sync/configs";
            devices = [ "choco" "zeeba" "pop-mac" ];
          };
          "savr_data" = {
            path = "${jonoHome}/sync/savr_data";
            devices = [ "choco" "zeeba" "galaxyS23" "pop-mac" ];
          };
        };

        devices = {
          "choco".id = "ITAESBW-TIKWVEX-ITJPOWT-PM7LSDA-O23Q2FO-6L5VSY2-3UW5VM6-I6YQAAR";
          
          "zeeba".id = "2PYYQJJ-SETCMFF-3IOL6F6-SZC2QQ6-EZXAAAM-XZ6R3DW-ZANZFFK-PQ7LBAU";
          
          "pop-mac".id = "N7XVA3T-WPY2XRB-P44F7KS-CEFRIDX-KK6DEYQ-UM2URKO-DVA2G2O-FLO6IAV";
        
          "galaxyS23".id = "GNT4UMD-JUYX45B-ODZXIZL-Q4JBCN5-DR5FEEI-LKLP667-VYEEJLP-GF4UCQO";
          
          # "plex" = {
          #   id =
          #     "KUJBRR4-XZRTGFD-DDUQA5E-K2TFBPY-ROBDN2S-IKXFYHS-HELJG3N-P6WJYAH";
          # };
        };

      };

    };
  };

  # just since so much dev work requires node
  programs.npm.enable = true;

  environment.systemPackages = with pkgs; [
    # local.windsurf
    iftop
    util-linux

    # these are needed for synciod (shouldnt they be included in that package?)
    lzop
    mbuffer
  ];

  home-manager.users.jono = {config, lib, pkgs, ...}: {

    # The home.stateVersion option does not have a default and must be set
    home.stateVersion = "24.11";

    fonts.fontconfig.enable = false;

    home.file.".thunderbird".source = config.lib.file.mkOutOfStoreSymlink /dpool/thunderbird_data;

    home.file = {
      "sync/common/.stignore".text = syncthingIgnores;
      "sync/configs/.stignore".text = syncthingIgnores;
      "sync/more/.stignore".text = syncthingIgnores;
      "sync/savr_data/.stignore".text = syncthingIgnores;      
    };

    # apps specific to this host
    home.packages = with pkgs-unstable;
    [
      android-studio
      nodejs_22
    ] ++ (with pkgs; [
      # android-studio # very old version, 2023
      # android-studio-full  # this takes so long to install because it has to build arm v8 every time
    ]);


    # these go to /etc/profiles/per-user/jono/share/applications/
    # xdg.desktopEntries = {

    #   pycharm_conda = {
    #     name = "PyCharm (in conda)";
    #     genericName = "Python IDE";
    #     exec = "conda-shell -c pycharm-professional";
    #     terminal = false;
    #     categories = [ "Development" ];
    #     icon = "pycharm-professional";
    #   };

    #   vscodium_conda = {
    #     categories = [ "Utility" "TextEditor" "Development" "IDE" ];
    #     exec = "conda-shell -c codium %F";
    #     genericName = "Text Editor";
    #     icon = "vscodium";
    #     # keywords=["vscode"];
    #     # MimeType=text/plain;inode/directory
    #     name = "VSCodium (in conda)";
    #     startupNotify = true;
    #     # startupWMClass="vscodium";
    #   };

    # };

    programs.fish = {
      enable = true;

      shellInit = ''
        # eval /home/jono/.conda/bin/conda "shell.fish" "hook" $argv | source

        set -x POPULUS_ENVIRONMENT dev
        set -x POPULUS_DATACENTER us

        set -x EDITOR micro

        # set -x NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE 1

        ## Android
        set --export ANDROID_HOME $HOME/Android/Sdk
        set -gx PATH $ANDROID_HOME/emulator $PATH;
        set -gx PATH $ANDROID_HOME/tools $PATH;
        set -gx PATH $ANDROID_HOME/tools/bin $PATH;
        set -gx PATH $ANDROID_HOME/platform-tools $PATH;
      '';

      interactiveShellInit = ''
        set fish_greeting # Disable greeting

        # eval /home/jono/.conda/bin/conda "shell.fish" "hook" $argv | source

        # conda-shell -c fish
      '';

      shellAbbrs = {
        cat = "bat";
        p = "ping google.com"; # "ping nixos.org";

        "..." = "cd ../..";

        u = "sudo date && os-update && time os-build && os-switch";

        # pop-devenv = "nix develop --impure path:$HOME/sync/configs/devenv/nix-populus-conda";

        # conda-populus =
        #   "conda activate populus-env && alias python=$HOME/.conda/envs/populus-env/bin/python";

      };

      shellAliases = {

        # update the checksum of the repos
        os-update = "cd $HOME/sync/configs/nix && nix flake update && cd -";

        # list incoming changes, compile, but dont install/switch to them
        os-build =
          "nix build --out-link /tmp/result --dry-run $HOME/sync/configs/nix#nixosConfigurations.dobro.config.system.build.toplevel && nix build --out-link /tmp/result $HOME/sync/configs/nix#nixosConfigurations.dobro.config.system.build.toplevel && nvd diff /run/current-system /tmp/result";

        # switch brings in flake file changes. as well as the last 'build'
        os-switch = "sudo nixos-rebuild switch -v --flake $HOME/sync/configs/nix";

      };

    };

    home.sessionVariables.JONO1 = "bar";

    # this to try to fix libc++6 errors needed for airflow
#    home.sessionVariables.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib/:$LD_LIBRARY_PATH";

    programs.git = {
      enable = true;
      userName = "Jono";
      userEmail = "jono@foodnotblogs.com";
      lfs.enable = true;
    };

  };

  # from old host file

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

    ../../modules/gnome.nix
    #../../modules/kde.nix
    # ../../packages/windsurf.nix

   ];

}
