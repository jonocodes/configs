{ pkgs, pkgs-unstable, inputs, modulesPath, home-manager, ... }:
let 
# was not able to get calibre to work right: https://github.com/Leseratte10/acsm-calibre-plugin/issues/68
# patched-calibre =   pkgs.calibre.overrideAttrs (attrs: {
#     preFixup = (
#       builtins.replaceStrings
#         [
#           ''
#             --prefix PYTHONPATH : $PYTHONPATH \
#           ''
#         ]
#         [
#           ''
#             --prefix LD_LIBRARY_PATH : ${pkgs.libressl.out}/lib \
#             --prefix PYTHONPATH : $PYTHONPATH \
#           ''
#         ]
#         attrs.preFixup
#     );
#   });
inherit (inputs) self;
in {
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];
  hardware.sane.enable = true;
  hardware.graphics.enable = true;

  programs.nix-ld.enable = true;  # for remote vscode. dont know if this works yet

  services.xserver = { enable = true; };

  xdg.portal.enable = true;

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "user-with-access-to-virtualbox" ];

  programs.adb.enable = true;
  users.users.jono.extraGroups = ["adbusers"];
  # android_sdk.accept_license = true;


  home-manager.users.jono = {config, ...}: {
  
    # imports = [ nix-flatpak.modules.home-manager ];

    # imports = [
    #   (inputs.nix-flatpak.modules/home-manager)
    # ];

    home.packages = with pkgs-unstable;
    [
      # tilix

      gnumake
      just

      # NOTE: vs code extensions I like: Nix IDE, Python, Black, parquet-viewer, SQLite viewer, codium, rainbow csv, docker, expo tools .

      # hunspell-dict-en-us-wordlist
      hunspellDicts.en_US
      flyctl

      rclone
      rclone-browser    # TODO: declarative config for /home/jono/.config/rclone . see https://github.com/nix-community/home-manager/pull/6101
      # pcmanfm # lightweight file manager, with right click tar
      numix-icon-theme
      numix-icon-theme-square

      devenv
      # openssl # needed for vscode php
      # nix-vscode-server
      # nix-ld # for vscode remote editing

      # move(d) to flatpak: 
      # vlc
      # gimp
      # spotify
      # impression # gtk usb disk writer
      # libreoffice
      # onlyoffice-bin_latest
      # sqlitebrowser
      # gnome-disk-utility
      # meld
      # bruno
      # keepassxc
      # ticktick
      # obsidian
      # # vnote # open source obsidian alternative
      # lutris
      # signal-desktop

      chromium
      element-desktop
      trayscale
#      syncthing-tray
      telegram-desktop
      # vscodium
      vscode  # needed for dev containers
      thunderbird-bin
      # jetbrains.pycharm-professional

      ghostty

    ] ++ (with pkgs; [

      tilix # temp moved here because compile problem on 9/15/24
      # pdm
      
      # TODO: move to flatpak?
      firefox-bin

      # zoom-us
      # slack
      # flatpak
#      android-studio-full
      # calibre # for putting library books onto kobo reader
      # patched-calibre

    ]);


    # tell user services to start when enabled. needed by home manager
    systemd.user.startServices = "sd-switch";


    services.flatpak = {

      enable = true;
      update.auto = {
        enable = true;
        onCalendar = "daily";
      };
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

        "org.gnome.baobab"  # gnome disk util
        "org.libreoffice.LibreOffice" 	# for editing csv
#      "com.github.xournalpp.xournalpp"  # for editing pdfs
        "com.usebruno.Bruno"
        "org.gnome.gitlab.cheywood.Buffer"  # text editor

        "org.signal.Signal"
        "com.ticktick.TickTick"
        "md.obsidian.Obsidian"
        "net.lutris.Lutris"
        "us.zoom.Zoom"
        "com.slack.Slack"

        "io.github.ungoogled_software.ungoogled_chromium"

        "de.schmidhuberj.Flare" # signal client

        "com.jetbrains.PyCharm-Professional"

      ];
    };

  };

  services.flatpak = {

    # NOTE: there is no feedback/logging of these, so you can watch flatpak progress like so: watch systemctl status flatpak-managed-install.service

    enable = true;
    update.auto = {
      enable = true;
      onCalendar = "daily";
    };
    packages = [

      # "com.jetbrains.PyCharm-Professional"
      # "com.vscodium.codium"
      # "org.mozilla.firefox"
      # "org.mozilla.Thunderbird"
		
    ];
  };


  # add support for manually running downloaded AppImages
  #  this can probably be updated to something here: https://mynixos.com/search?q=appimage
  boot.binfmt.registrations.appimage = {
    wrapInterpreterInShell = false;
    interpreter = "${pkgs.appimage-run}/bin/appimage-run";
    recognitionType = "magic";
    offset = 0;
    mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
    magicOrExtension = ''\x7fELF....AI\x02'';
  };


}
