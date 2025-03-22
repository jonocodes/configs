# https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS.html
# https://github.com/ne9z/dotfiles-flake/tree/2e39ad6ee4edebf7f00e4bf76d35c56d98f78fd7

{ pkgs, pkgs-unstable, inputs, config, ... }:
let
  inherit (inputs) self;

in {

    fonts.fontconfig.enable = false;

    home.file.".thunderbird".source =
      config.lib.file.mkOutOfStoreSymlink /dpool/thunderbird_data;

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
        # (lib.hiPrio
        #   windsurf) # https://github.com/NixOS/nixpkgs/issues/356478#issuecomment-2559417152

        warp-terminal

        android-studio

        yaak  # for now this brings up a blank screen

        #   nix binary runner helpers
        # nix-index
        # nix-locate
        steam-run # x86 only
        # nodejs_22
      ] ++ (with pkgs;
        [

          tilix # temp moved here because compile problem on 9/15/24
        
#          firefox-bin

          # android-studio # very old version, 2023
          # android-studio-full  # this takes so long to install because it has to build arm v8 every time

          # TODO: waiting on https://github.com/flox/flox/issues/2811
          inputs.flox.packages.${pkgs.system}.default

        ]);


      # services.flatpak = {
        # enable = true;

        # packages = [

        #   "com.github.tchx84.Flatseal"

        #   "io.dbeaver.DBeaverCommunity"
        #   "io.github.aandrew_me.ytdn" # video downloader
        #   "com.github.unrud.VideoDownloader"

        #   "org.gnome.meld"

        #   "org.videolan.VLC"
        #   "org.gimp.GIMP"
        #   "io.gitlab.adhami3310.Impression"
        #   "com.spotify.Client"
        #   "org.sqlitebrowser.sqlitebrowser"

        #   "org.keepassxc.KeePassXC"

        #   "org.gnome.baobab" # gnome disk util
        #   "org.libreoffice.LibreOffice" # for editing csv
        #   #      "com.github.xournalpp.xournalpp"  # for editing pdfs
        #   "com.usebruno.Bruno"
        #   "org.gnome.gitlab.cheywood.Buffer" # text editor

        #   "org.signal.Signal"
        #   "com.ticktick.TickTick"
        #   "md.obsidian.Obsidian"
        #   "net.lutris.Lutris"
        #   "us.zoom.Zoom"
        #   "com.slack.Slack"

        #   "io.github.ungoogled_software.ungoogled_chromium"

        #   "de.schmidhuberj.Flare" # signal client

        #   "com.jetbrains.PyCharm-Professional"

        #   "io.github.mhogomchungu.media-downloader"

        # ];
      # };


  imports = [
    # inputs.nix-flatpak.nixosModules.nix-flatpak

    inputs.nix-flatpak.homeManagerModules.nix-flatpak

    ../modules/common.nix
    ../modules/linux-desktop.nix
    # ../modules/email.nix

  ];

}
