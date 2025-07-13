# https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS.html
# https://github.com/ne9z/dotfiles-flake/tree/2e39ad6ee4edebf7f00e4bf76d35c56d98f78fd7

{ pkgs, pkgs-unstable, inputs, modulesPath, android-nixpkgs, nixpkgs, ... }:
let
  inherit (inputs) self;

  local = self.packages;

  # TODO: move this to a common place
  syncthingIgnores = ''
    .direnv
    .devenv
    .git
    .venv
    .DS_Store
    node_modules
    result
  '';

  # androidSdkModule = import ((builtins.fetchGit {
  #   url = "https://github.com/tadfisher/android-nixpkgs.git";
  #   ref = "main";  # Or "stable", "beta", "preview", "canary"
  # }) + "/hm-module.nix");

in {

    # localpackages = import ../../packages {
    #   inherit nixpkgs;
    #   pkgs = nixpkgs.legacyPackages;
    # };


  # not sure why, but I needed to do this to use caches in devenv with php ?
  nix.settings.trusted-users = [ "root" "jono" ];

  users.users = {
    root = {
      initialHashedPassword =
        "$6$pB0sFZ55jt5R9Y/i$gNcFRYHWzCVm0ZxArZnW9pQD3gzAFqnAZl/4PwXiFdPdt5d7G7HsgtLYr8aSGYvtzILXWgxYpXL6qjgtELvTP1";
    };
    jono = {
      isNormalUser = true;
      description = "jono";
      extraGroups = [ "networkmanager" "wheel" "docker" ];
      shell = pkgs.fish;
    };
  };

  ## enable ZFS auto snapshot on datasets
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

  # fileSystems."/media/DataDrive" = { device = "/dev/mapper/datadrive"; };

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


  users.extraUsers.jono.extraGroups = [ "jackaudio" ];

  services.jack = {
    jackd.enable = true;
    # support ALSA only programs via ALSA JACK PCM plugin
    alsa.enable = false;
    # support ALSA only programs via loopback device (supports programs like Steam)
    loopback = {
      enable = true;
      # buffering parameters for dmix device to work with ALSA only semi-professional sound programs
      #dmixConfig = ''
      #  period_size 2048
      #'';
    };
  };

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
          "common" = {
            path = "/home/jono/sync/common";
            devices = [ "choco" "galaxyS23" "pop-mac" ];
          };
          "more" = {
            path = "/home/jono/sync/more";
            devices = [ "choco" "pop-mac" ];
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
            path = "/home/jono/sync/configs";
            devices = [ "choco" "pop-mac" ];
          };
          "savr_data" = {
            path = "/home/jono/sync/savr_data";
            devices = [ "choco" "galaxyS23" "pop-mac" ];
          };
        };

        devices = {
          "choco" = {
            id =
              "ITAESBW-TIKWVEX-ITJPOWT-PM7LSDA-O23Q2FO-6L5VSY2-3UW5VM6-I6YQAAR";
          };
          #	"bassoon" = {id="57MFVRK-UZTFSKP-WYPPHFJ-22VN4Y2-QX7MS4H-MFVFZNL-3QFQA5B-2SI4UQW";};
          "pop-mac" = {
            id =
              "N7XVA3T-WPY2XRB-P44F7KS-CEFRIDX-KK6DEYQ-UM2URKO-DVA2G2O-FLO6IAV";
          };
          # "galaxyS20" = {
          #   id =
          #     "5QQ7YWM-DQ4YDDS-U2LHCGZ-WPBRLAS-ZVUXIRY-4RDTG7I-L34H3IV-ZWGXSAD";
          # };
          "galaxyS23" = {
            id =
              "GNT4UMD-JUYX45B-ODZXIZL-Q4JBCN5-DR5FEEI-LKLP667-VYEEJLP-GF4UCQO";
          };
          # "plex" = {
          #   id =
          #     "KUJBRR4-XZRTGFD-DDUQA5E-K2TFBPY-ROBDN2S-IKXFYHS-HELJG3N-P6WJYAH";
          # };
        };

      };

    };
  };

  # environment.variables = { FOO = "bar"; };


  # home-manager.users.jono.home.packages = with pkgs-unstable;
  #   [
  #     guitarix
  #     qjackctl
  #   ] ++ (with pkgs; [
  #     android-studio-full
  #   ]);



  # just since so much dev work requires node
  programs.npm.enable = true;


    environment.systemPackages = with pkgs; [
      # local.windsurf
      # jq
      iftop
    ];

  home-manager.users.jono = {config, lib, pkgs, ...}: {



            # imports = [
            #   android-nixpkgs.hmModule

            #   {
            #     inherit config lib pkgs;
            #     android-sdk.enable = true;

            #     # Optional; default path is "~/.local/share/android".
            #     android-sdk.path = "${config.home.homeDirectory}/.android/sdk";

            #     android-sdk.packages = sdk: with sdk; [
            #       build-tools-34-0-0
            #       cmdline-tools-latest
            #       emulator
            #       platforms-android-34
            #       sources-android-34
            #     ];
            #   }
            # ];


    # The home.stateVersion option does not have a default and must be set
    home.stateVersion = "24.05";

    fonts.fontconfig.enable = false;

    home.file.".thunderbird".source = config.lib.file.mkOutOfStoreSymlink /dpool/thunderbird_data;

    home.file = {
      # "sync/shared.stignore".text = ''
      #   .direnv
      #   .devenv
      #   .git
      #   .venv
      #   .DS_Store
      #   node_modules
      #   result
      # '';

      # "sync/test.ignore".text = syncthingIgnores;

      "sync/common/.stignore".text = syncthingIgnores;
      "sync/configs/.stignore".text = syncthingIgnores;
      "sync/more/.stignore".text = syncthingIgnores;

      # "sync/common/.stignore".source = ../../files/shared.stignore;
      # "sync/configs/.stignore".source = ../../files/shared.stignore;
      # "sync/more/.stignore".source = ../../files/shared.stignore;
    };

    # apps specific to this host
    home.packages = with pkgs-unstable;
    [
      guitarix
      qjackctl

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

    #   db_proxies = {
    #     name = "Populus DB proxies";
    #     exec = ''conda-shell -c "make db-start-proxies"'';
    #     terminal = true;
    #     categories = [ "Development" ];
    #     settings = { Path = "/home/jono/src/terminal"; };

    #   };
    # };

    programs.fish = {
      enable = true;

      # shellHook = ''
      #   LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib/"
      # '';

      shellInit = ''
        # eval /home/jono/.conda/bin/conda "shell.fish" "hook" $argv | source

        set -x POPULUS_ENVIRONMENT dev
        set -x POPULUS_DATACENTER us

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

        eval /home/jono/.conda/bin/conda "shell.fish" "hook" $argv | source

        # conda-shell -c fish
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
          "nix build --out-link /tmp/result --dry-run /home/jono/sync/configs/nix#nixosConfigurations.dobro.config.system.build.toplevel && nix build --out-link /tmp/result /home/jono/sync/configs/nix#nixosConfigurations.dobro.config.system.build.toplevel && nvd diff /run/current-system /tmp/result";

        # switch brings in flake file changes. as well as the last 'build'
        os-switch = "sudo nixos-rebuild switch -v --flake /home/jono/sync/configs/nix";

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

  # I guess the following is no longer needed since the firewall is disabled
  # for syncthing remote management
  #  networking.firewall.allowedTCPPorts = [ 8384 22000 ];
  #  networking.firewall.allowedUDPPorts = [ 22000 21027 ];

  # import preconfigured profiles
  imports = [ 
    ./boot.nix
    ./fileSystems.nix

    ../../modules/common-nixos.nix
    ../../modules/linux-desktop.nix
    # ../../modules/populus-dev.nix

    ../../modules/gnome.nix
    # ../../modules/kde.nix
    # ../../packages/windsurf.nix
   ];

}
