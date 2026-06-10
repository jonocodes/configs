{ pkgs, pkgs-unstable, inputs, ... }:
let
  inherit (inputs) self;

  vars = import ../vars.nix;
  jonoHome = vars.jonoHome;

in {

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-c8bb8fca-3b35-485a-9e71-e872bf697719".device = "/dev/disk/by-uuid/c8bb8fca-3b35-485a-9e71-e872bf697719";

  # boot.supportedFilesystems."fuse.sshfs" = true;

  boot.supportedFilesystems = [ "zfs" "fuse.sshfs" ];

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


  # this came from the original hardware config. it does work without it.
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # disable the internal speaker, which seems to turn on when monitors turn off. since pipewire is falling back. 
  #  I dont think this is working as expected.
  environment.etc."wireplumber/wireplumber.conf.d/51-disable-internal-audio.conf".text = ''
    monitor.alsa.rules = [
      {
        matches = [
          { device.name = "alsa_card.pci-0000_c5_00.6" }
        ]
        actions = {
          update-props = {
            device.disabled = true
          }
        }
      }
    ]
  '';



  boot.zfs.extraPools = [ "dpool" ];

  # boot.zfs.forceImportRoot = false;
  boot.initrd.systemd.enable = true;

  services.duplicati = {
    # run as user to read home dir
    enable = true;
    user = vars.username;
  };

  # local nas
  fileSystems = {

    # NOTE: turned this off for a bit while I mess with different routers
    "/media/nas_backup" = {
      device = "lacie:/shares/backup";
      fsType = "nfs";
    };

    # offsite backup drive (routed through matcha)
    "/media/berk_nas" = {
      device = "//berk-nas/jono";
      fsType = "cifs";
      options = let
        # this line prevents hanging on network split
        automount_opts =
          "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=15s,x-systemd.mount-timeout=15s";

      in [
        "${automount_opts},nofail,uid=jono,gid=users,credentials=/etc/samba/credentials/berk"
      ];
    };

    "/media/matcha_home" = {
      device = "${vars.username}@matcha:${vars.homeDirectory}";
      fsType = "fuse.sshfs";
      options = [
        "reconnect"
        "allow_other"
        "x-systemd.automount"  # mount on first access?
        "IdentityFile=${jonoHome}/.ssh/id_ed25519"
      ];
    };

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

        common = { devices = [ "choco" "zeeba" 
        #"orc" "galaxyS23" "matcha" 
        ]; };
        
        more = { devices = [ "choco" "zeeba"
        #  "orc" "matcha" 
        ]; };
        
        camera = {
          path = "/dpool/camera/JonoCameraS23";
          devices = [ "galaxyS23" ];
        };

        mobile = {
          devices = [ "galaxyS23" ];
        };

        configs = { devices = [ "choco" "zeeba"
         # "orc" "matcha"
        ]; };
        
      };

    };
  };

  services.code-server = {
    enable = true;
    user = vars.username;
    host = "0.0.0.0";
    port = 4444;
    auth = "none";
    extraArguments = [
      "--disable-telemetry"
      "${vars.homeDirectory}/src"
    ];
    extraEnvironment = {
      HOME = vars.homeDirectory;
    };
  };

  systemd.services.code-server.preStart = ''
    ${pkgs.code-server}/bin/code-server --install-extension bbenoist.nix
  '';

  # open firewall for code-server
  networking.firewall.allowedTCPPorts = [ 4444 ];

  services = {

    davfs2.enable = true;

    sanoid = {
      enable = true;
      package = pkgs.sanoid;

      # One-time setup on lute:
      #   sudo zfs allow -u jono send,snapshot,hold,bookmark,destroy,mount dpool/thunderbird_data
      # One-time setup on zeeba:
      #   sudo zfs create dpool/lute
      #   sudo zfs allow -u backup create,mount,receive,destroy,rollback,canmount dpool/lute

      datasets = {
        "dpool/thunderbird_data" = {
          recursive = true;
          hourly = 24;
          daily = 7;
          monthly = 3;
          autoprune = true;
          autosnap = true;
        };
        "dpool/files" = {
          recursive = true;
          hourly = 24;
          daily = 7;
          monthly = 3;
          autoprune = true;
          autosnap = true;
        };
        "dpool/camera" = {
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
      # Use the module default `syncoid` system user (key under /var/lib/syncoid
      # is auto-mapped into the unit's chroot via StateDirectory=syncoid).
      sshKey = "/var/lib/syncoid/.ssh/id_ed25519";
      # Don't pass -v to `zfs send`: it spawns a progress thread that calls
      # timer_create(), which the upstream unit's SystemCallFilter=~@timer
      # kills with SIGSYS. (See sendOptions = "" below.)
      commands = {
        "backup-thunderbird" = {
          source = "dpool/thunderbird_data";
          target = "backup@zeeba:dpool/lute/thunderbird_data";
          recursive = true;
          sendOptions = "";
          recvOptions = "v";
        };
        "backup-files" = {
          source = "dpool/files";
          target = "backup@zeeba:dpool/lute/files";
          recursive = true;
          sendOptions = "";
          recvOptions = "v";
        };
        "backup-camera" = {
          source = "dpool/camera";
          target = "backup@zeeba:dpool/lute/camera";
          recursive = true;
          sendOptions = "";
          recvOptions = "v";
        };
      };
    };

  };

  # zeeba's host key — written to /etc/ssh/ssh_known_hosts which is visible
  # inside syncoid's chroot (since /etc is bind-mounted in).
  programs.ssh.knownHosts.zeeba = {
    hostNames = [ "zeeba" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBFywxBdIOFjj34k6ATjyXjsg3cT4TvPbP8dNqpYPVZo";
  };

  # Notify ntfy.sh on syncoid run finish (success and failure).
  # NOTE: I need to manually subscribe to this topic on my phone/desktop —
  # nothing else is watching it. Topic is a long random string for obscurity
  # (ntfy.sh has no auth). On phone, filter by priority if success pings
  # are too noisy (~3/hr with three commands).
  systemd.services."syncoid-backup-thunderbird".unitConfig = {
    OnFailure = [ "syncoid-failure-notify@%n.service" ];
    OnSuccess = [ "syncoid-success-notify@%n.service" ];
  };

  # Stagger the three syncoid timers (default is all hourly at :00) so they
  # don't fight for bandwidth. Sanoid still fires at :00 so snapshots are
  # fresh before each sync.
  systemd.timers."syncoid-backup-thunderbird".timerConfig.OnCalendar = pkgs.lib.mkForce "*:15";
  systemd.timers."syncoid-backup-files".timerConfig.OnCalendar = pkgs.lib.mkForce "*:30";
  systemd.timers."syncoid-backup-camera".timerConfig.OnCalendar = pkgs.lib.mkForce "*:45";
  systemd.services."syncoid-backup-files".unitConfig = {
    OnFailure = [ "syncoid-failure-notify@%n.service" ];
    OnSuccess = [ "syncoid-success-notify@%n.service" ];
  };
  systemd.services."syncoid-backup-camera".unitConfig = {
    OnFailure = [ "syncoid-failure-notify@%n.service" ];
    OnSuccess = [ "syncoid-success-notify@%n.service" ];
  };

  systemd.services."syncoid-failure-notify@" = {
    description = "Notify ntfy.sh on syncoid failure (%i)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.curl}/bin/curl -fsS -m 15 -H 'Title: syncoid failed on lute' -H 'Priority: high' -H 'Tags: warning' -d 'syncoid unit failed — check journalctl on lute (%i)' https://ntfy.sh/lute-jono-backups-9f3a2c";
    };
  };

  # systemd.services."syncoid-success-notify@" = {
  #   description = "Notify ntfy.sh on syncoid success (%i)";
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = "${pkgs.curl}/bin/curl -fsS -m 15 -H 'Title: syncoid ok on lute' -H 'Priority: low' -H 'Tags: white_check_mark' -d 'syncoid unit completed (%i)' https://ntfy.sh/lute-jono-backups-9f3a2c";
  #   };
  # };


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

    # for video thumbnails in gnome
    ffmpeg-headless
    ffmpegthumbnailer

    opencode

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

    ../../modules/coolify/from-source

  ];

  # turning this off for now since I need to use port 3000 . I never fully checked that this is working anyway
  # services.coolify = {
  #   enable = true;
  #   openFirewall = true;
  # };

  # services.ntfy-sh = {
  #   enable = true;
  #   settings.base-url = "htt8888888888888888888888888888888p://lute:2586";
  #   settings.listen-http = ":2586";
  # };

}
