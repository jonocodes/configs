{ pkgs, pkgs-unstable, inputs, config, ... }:
let
  inherit (inputs) self;

    # node wrapper with playwright available via NODE_PATH and browsers pre-configured
  playwright-node = pkgs-unstable.writeShellScriptBin "playwright-node" ''
    export PLAYWRIGHT_BROWSERS_PATH="${pkgs-unstable.playwright-driver.browsers}"
    export NODE_PATH="${pkgs-unstable.playwright-test}/lib/node_modules''${NODE_PATH:+:$NODE_PATH}"
    exec ${pkgs-unstable.nodejs}/bin/node "$@"
  '';


  coolify-cli = pkgs.callPackage ../../packages/coolify-cli {};
  limux = pkgs.callPackage ../../packages/limux {};

in {

    fonts.fontconfig.enable = false;

    home.file.".thunderbird".source =
      config.lib.file.mkOutOfStoreSymlink /dpool/thunderbird_data;

    # apps specific to this host
    home.packages = with pkgs-unstable;
      [
        coolify-cli
        limux

    		killall
        hunspellDicts.en_US
        # rclone

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

        lazydocker
        lazyjournal

        distrobox

        # zed-editor # switched to flatpak

        #   nix binary runner helpers
        # nix-index
        # nix-locate
        steam-run # x86 only
        # nodejs_22

        # handbrake
        digikam
        smartmontools

        # AI tools
        # gh
        # opencode

        code-cursor
        # codex
        # happy-coder

        # claude-code
        nodejs
        playwright-mcp
        playwright-test
        playwright-node

      ] ++ (with pkgs;
        [
          inputs.llm-agents.packages.${pkgs.system}.ccusage

          # temp moved here because of cmake error. https://github.com/NixOS/nixpkgs/issues/445447
          rclone-browser # TODO: declarative config for /home/jono/.config/rclone . see https://mynixos.com/home-manager/options/programs.rclone.remotes.%3Cname%3E

          tilix # temp moved here because compile problem on 9/15/24

          vscode

          inputs.flox.packages.${pkgs.system}.default

        ]);

  # services.happy-coder-daemon = {
  #   enable = true;

  #   environment = {
  #     HAPPY_SERVER_URL = "https://happy-server.wolf-typhon.ts.net";
  #     # HAPPY_LOG_LEVEL = "info";
  #   };
  # };

  services.podman = {
    enable = true;
  };

  programs.rclone = {
    enable = true;
    remotes.berk_nas = {
      config = {
        type = "sftp";
        host = "berk-nas";
        user = "sshd";
        shell_type = "unix";
        md5sum_command = "md5sum";
        sha1sum_command = "none";
      };
      # file containing unobscured password
      secrets.pass = "${config.home.homeDirectory}/.config/secrets/rclone_berk_nas_pass";
    };
  };


  programs.fish = {

    shellInit = ''
      set -gx PLAYWRIGHT_BROWSERS_PATH "${pkgs-unstable.playwright-driver.browsers}"
      # set -gx PLAYWRIGHT_BROWSERS_PATH_1541 "..."  # moved to flox
    '';

    shellAbbrs = {

      backup-media-to-nas = "rclone sync -i --skip-links --size-only --exclude '.*' /dpool/media /media/nas_backup/jono/media";

      backup-camera-to-nas = "rclone sync -i --skip-links --size-only --exclude '.*' /dpool/camera /media/nas_backup/jono/camera";

      backup-camera-to-berk = "rclone sync -i --skip-links --size-only --exclude '.*' /dpool/camera berk_nas:/mnt/HD/HD_a2/jono/camera";

    };
  };
  

  # home.sessionVariables = {
  #   HAPPY_SERVER_URL = "https://happy-server.wolf-typhon.ts.net";
  # };

  imports = [

    inputs.nix-flatpak.homeManagerModules.nix-flatpak

    ../../modules/common.nix
    ../../modules/linux-desktop.nix
    ../../modules/happy/happy-coder-daemon.nix
  ];

}
