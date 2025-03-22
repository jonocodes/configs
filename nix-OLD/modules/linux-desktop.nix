{ pkgs, pkgs-unstable, inputs, modulesPath, home-manager, ... }:
let

  inherit (inputs) self;
in {
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];
  hardware.sane.enable = true;
  hardware.graphics.enable = true;

  programs.nix-ld.enable = true; # for remote vscode. dont know if this works yet

  services.xserver = { enable = true; };

  xdg.portal.enable = true;

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "user-with-access-to-virtualbox" ];

  programs.adb.enable = true;
  users.users.jono.extraGroups = [ "adbusers" ];
  # android_sdk.accept_license = true;

  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ]; # used by nixd

  home-manager.users.jono = { config, ... }: {

    # imports = [ nix-flatpak.modules.home-manager ];

    # imports = [
    #   (inputs.nix-flatpak.modules/home-manager)
    # ];

    home.packages = with pkgs-unstable;
      [

        # NOTE: vs code extensions I like: Nix IDE, Python, Black, parquet-viewer, SQLite viewer, codium/cline, rainbow csv, docker, expo tools

        #  programs.vscode = {
        #   enable = true;
        #   extensions = with pkgs.vscode-extensions; [
        #     ms-python.python  # Python extension
        #     ms-vscode.cpptools  # C++ extension
        #     eamodio.gitlens  # GitLens extension
        #     esbenp.prettier-vscode  # Prettier (for formatting)
        #   ];
        # };

        # also add to keybindings.json:
        # {
        #     "key": "shift shift",
        #     "command": "workbench.action.quickOpen",
        # }]

        # like:

        # {
        #   home.file.".config/Code/User/keybindings.json".source = pkgs.writeText "keybindings.json" ''
        #     [
        #       {
        #         "key": "shift shift",
        #         "command": "workbench.action.quickOpen"
        #       }
        #     ]
        #   '';
        # }

        telegram-desktop
        # # vscodium
        # vscode # needed for dev containers

    ] ++ (with pkgs; [

      # tilix # temp moved here because compile problem on 9/15/24
      
      # # TODO: move to flatpak?
      # firefox-bin

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

        # "com.github.tchx84.Flatseal"

#         "org.keepassxc.KeePassXC"

        # "io.dbeaver.DBeaverCommunity"
        # "io.github.aandrew_me.ytdn" # video downloader
        # "com.github.unrud.VideoDownloader"

        # "org.gnome.meld"

        # "org.videolan.VLC"
        # "org.gimp.GIMP"
        # "io.gitlab.adhami3310.Impression"
        # "com.spotify.Client"
        # "org.sqlitebrowser.sqlitebrowser"


        # "org.gnome.baobab" # gnome disk util
        # "org.libreoffice.LibreOffice" # for editing csv
        # #      "com.github.xournalpp.xournalpp"  # for editing pdfs
        # "com.usebruno.Bruno"
        # "org.gnome.gitlab.cheywood.Buffer" # text editor

        # "org.signal.Signal"
        # "com.ticktick.TickTick"
        # "md.obsidian.Obsidian"
        # "net.lutris.Lutris"
        # "us.zoom.Zoom"
        # "com.slack.Slack"

        # "io.github.ungoogled_software.ungoogled_chromium"

        # "de.schmidhuberj.Flare" # signal client

        # "com.jetbrains.PyCharm-Professional"

        # "io.github.mhogomchungu.media-downloader"

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
#       "com.github.tchx84.Flatseal"

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
    mask = "\\xff\\xff\\xff\\xff\\x00\\x00\\x00\\x00\\xff\\xff\\xff";
    magicOrExtension = "\\x7fELF....AI\\x02";
  };

}
