{ pkgs, pkgs-unstable, inputs, modulesPath, nixos-hardware, ... }:
let

  syncthingIgnores = builtins.readFile ../../files/syncthingIgnores.txt;

in {

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.enableAllFirmware = true;

  nix.settings = {
    download-buffer-size = 500000000;
  };


#   nixpkgs.config.allowUnfree = true;


     environment.systemPackages = with pkgs; [
#    networkmanager
#    networkmanagerapplet
        broadcom-bt-firmware
      ];



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
        savr_data = {
          devices = [ "choco" "dobro" ];
        };

      };
    };

  };


  home-manager.users.jono = {config, ...}: {
    # The home.stateVersion option does not have a default and must be set, bummer
    home.stateVersion = "24.11";

    imports = [ ../../modules/user-jono.nix ];

    home.file = {
      "sync/common/.stignore".text = syncthingIgnores;
      "sync/configs/.stignore".text = syncthingIgnores;
      "sync/more/.stignore".text = syncthingIgnores;
      "sync/savr_data/.stignore".text = syncthingIgnores;
    };

    home.packages = with pkgs-unstable;
      [
#         helix
        # devenv
      ] ++ (with pkgs; [

      ]);




      services.flatpak = {

        packages = [

          "com.github.tchx84.Flatseal"

          "org.mozilla.firefox"

#           "io.dbeaver.DBeaverCommunity"
#           "io.github.aandrew_me.ytdn" # video downloader
#           "com.github.unrud.VideoDownloader"
#
#           "org.gnome.meld"
#
#           "org.videolan.VLC"
#           "org.gimp.GIMP"
#           "io.gitlab.adhami3310.Impression"
#           "com.spotify.Client"
#           "org.sqlitebrowser.sqlitebrowser"
#
#           "org.keepassxc.KeePassXC"
#
#           "org.gnome.baobab" # gnome disk util
#           "org.libreoffice.LibreOffice" # for editing csv
#           #      "com.github.xournalpp.xournalpp"  # for editing pdfs
#           "com.usebruno.Bruno"
#           "org.gnome.gitlab.cheywood.Buffer" # text editor
#
#           "org.signal.Signal"
#           "com.ticktick.TickTick"
#           "md.obsidian.Obsidian"
#           "net.lutris.Lutris"
#           "us.zoom.Zoom"
#           "com.slack.Slack"
#
#           "io.github.ungoogled_software.ungoogled_chromium"
#
#           "de.schmidhuberj.Flare" # signal client
#
#           "com.jetbrains.PyCharm-Professional"
#
#           "io.github.mhogomchungu.media-downloader"

        ];
      };


  };

  networking.hostName = "imbp";

  imports = [

    (let inherit (inputs) nixos-hardware; in nixos-hardware.nixosModules.apple-t2)

    inputs.nix-flatpak.nixosModules.nix-flatpak

    ./hardware-configuration.nix
    ../../modules/common-nixos.nix
    ../../modules/syncthing.nix

     ../../modules/linux-desktop.nix
    ../../modules/kde.nix

  ];

}
