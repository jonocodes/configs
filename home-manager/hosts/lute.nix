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

    		killall
        hunspellDicts.en_US
        rclone

        # pcmanfm # lightweight file manager, with right click tar
        numix-icon-theme
        numix-icon-theme-square

        # devenv
        # nixpkgs-fmt # depricated to nixfmt
        nixfmt # depricated to nixfmt-classic ?
        alejandra
        nixd

        # chromium
        element-desktop
        trayscale
        #      syncthing-tray
        telegram-desktop
        # vscodium
        # vscode # needed for dev containers
        thunderbird-bin
        # jetbrains.pycharm-professional
        gnome-tweaks

        ghostty

        code-cursor
        claude-code

        lazydocker
        lazyjournal

        distrobox

        #   nix binary runner helpers
        # nix-index
        # nix-locate
        steam-run # x86 only
        # nodejs_22

        handbrake
        digikam
        smartmontools

      ] ++ (with pkgs;
        [

          # temp moved here because of cmake error. https://github.com/NixOS/nixpkgs/issues/445447
          rclone-browser # TODO: declarative config for /home/jono/.config/rclone . see https://github.com/nix-community/home-manager/pull/6101

          tilix # temp moved here because compile problem on 9/15/24

          vscode

          inputs.flox.packages.${pkgs.system}.default

        ]);


  imports = [

    inputs.nix-flatpak.homeManagerModules.nix-flatpak

    ../modules/common.nix
    ../modules/linux-desktop.nix
  ];

}
