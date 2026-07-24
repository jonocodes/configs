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
  # limux: parked — does not build yet (glad GL-loader link failure on all arches).
  # See home-manager/packages/limux/default.nix BUILD STATUS note.
  # limux = pkgs.callPackage ../../packages/limux {};

  tabby = pkgs.callPackage ../../packages/tabby {};  # Eugeny/tabby GUI terminal (NOT TabbyML)

in {

    fonts.fontconfig.enable = false;

    home.file.".thunderbird".source =
      config.lib.file.mkOutOfStoreSymlink /dpool/thunderbird_data;

    # apps specific to this host
    home.packages = with pkgs-unstable;
      [
        coolify-cli
        # limux  # parked — see let-binding above
        tabby

    		killall
        hunspellDicts.en_US
        # rclone
        gocryptfs

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

        # distrobox

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
        # openai-whisper

        code-cursor
        cursor-cli
        # codex
        # happy-coder

        # claude-code
        nodejs
        playwright-mcp
        playwright-test
        playwright-node

        pi-coding-agent

      ] ++ (with pkgs;
        [
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.ccusage

          # temp moved here because of cmake error. https://github.com/NixOS/nixpkgs/issues/445447

          tilix # temp moved here because compile problem on 9/15/24

          vscode

          inputs.flox.packages.${pkgs.stdenv.hostPlatform.system}.default

        ]);

  # services.happy-coder-daemon = {
  #   enable = true;

  #   environment = {
  #     HAPPY_SERVER_URL = "https://happy-server.wolf-typhon.ts.net";
  #     # HAPPY_LOG_LEVEL = "info";
  #   };
  # };

  programs.rclone = {
    enable = true;
    remotes = {
      berk_nas = {
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
      choco = {
        config = {
          type = "sftp";
          host = "choco";
          user = "jono";
          shell_type = "unix";
          # md5sum_command = "md5sum";
          # sha1sum_command = "none";
          known_hosts_file = "${config.home.homeDirectory}/.ssh/known_hosts";
        };
        # file containing unobscured password
        # secrets.pass = "${config.home.homeDirectory}/.config/secrets/rclone_berk_nas_pass";
      };
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

  programs.opencode = {
    enable = true;
    web = {
      enable = true;
      extraArgs = [ "--hostname" "0.0.0.0" "--port" "4100" ];
    };
  };

  # t3code: headless web GUI for coding agents. Runs as a user systemd service
  # bound to 0.0.0.0:3773.
  #
  # UPSTREAM HAS NO STATIC AUTH MODE — only single-use pairing tokens. The
  # module issues a batch of 30-day tokens at every service start and writes
  # them to ~/.t3/pairing-tokens (mode 0600). To pair a new browser:
  #
  #   cat ~/.t3/pairing-tokens
  #   # open http://lute:3773, paste any token
  #
  # Docs: home-manager/modules/t3code.README.md
  #
  # claude-code + gh are already on user PATH via home-manager/modules/common.nix;
  # opencode is provided by programs.opencode above. We just need opencode
  # in the service's explicit PATH so t3code can shell out to it.
  #
  # ── UPSTREAMING / how to drop the custom bits once these land ──────────────
  # Both pieces below are local stopgaps that upstream work will replace:
  #
  #   1. The patched package (services.t3code.package, below) works around the
  #      OPENCODE_CONFIG_CONTENT bug — https://github.com/pingdotgg/t3code/issues/4239
  #      Fix PR: https://github.com/pingdotgg/t3code/pull/4242
  #      → Once the fix ships in nixpkgs-unstable, delete
  #        home-manager/packages/t3code-patched.nix and set
  #        `package = pkgs-unstable.t3code;` (stock).
  #
  #   2. This whole `services.t3code` config is served by our LOCAL module
  #      (../../modules/t3code.nix). Upstream home-manager is adding the
  #      equivalent as `programs.t3code.server` —
  #      https://github.com/nix-community/home-manager/pull/9695
  #      → Once that merges and reaches our home-manager input, delete
  #        ../../modules/t3code.nix (+ its README) and migrate this block to
  #        `programs.t3code.server = { enable = true; extraPackages = [...]; };`.
  # ──────────────────────────────────────────────────────────────────────────
  services.t3code = {
    enable = true;
    # nixpkgs-unstable's t3code (0.0.28), patched for the
    # OPENCODE_CONFIG_CONTENT bug (t3code#4239) so opencode honours an
    # inherited config. See home-manager/packages/t3code-patched.nix.
    # NOTE: overriding the unwrapped derivation forces a full local rebuild
    # (incl. the Electron desktop build).
    # package = pkgs.callPackage ../../packages/t3code-patched.nix {
    #   t3code = pkgs-unstable.t3code;
    # };
    extraPackages = [ pkgs.opencode ];
  };

  # paseo: self-hosted web service for orchestrating coding agents
  # (https://paseo.sh). Headless daemon + bundled web UI as a user service on
  # 0.0.0.0:6767 — reach it at http://lute:6767. Not in nixpkgs, so built
  # locally from the @getpaseo/cli npm package (../../packages/paseo).
  #
  # Auth: the daemon reads a plaintext password from the passwordFile below and
  # hashes it into its config on startup. Create it once (it is NOT tracked by
  # nix and never enters the store):
  #   umask 077 && printf '%s' 'your-password' > ~/.config/secrets/paseo-password
  # then `systemctl --user restart paseo.service`. Log in at http://lute:6767.
  #
  # Relay is disabled (LAN-only web service). Set services.paseo.relay = true
  # to enable paseo's hosted E2E relay for mobile/off-LAN pairing.
  services.paseo = {
    enable = true;
    passwordFile = "${config.home.homeDirectory}/.config/secrets/paseo-password";
    # Allow any Host header. paseo's default DNS-rebinding allowlist only
    # permits localhost/*.localhost and raw IPs, so reaching it by name
    # (http://lute:6767, a Tailscale MagicDNS name, …) otherwise returns
    # 403 "Invalid Host header". The password above is the real access gate,
    # so allowing any host is fine here. To tighten, replace "true" with a
    # comma-separated list, e.g. "lute,.lan,.ts.net".
    hostnames = "true";
    # Agent CLIs paseo can spawn. claude-code + gh come from common.nix; add
    # them explicitly so they're on the service's PATH too.
    extraPackages = [ pkgs.opencode pkgs.claude-code ];
  };

  imports = [

    inputs.nix-flatpak.homeManagerModules.nix-flatpak

    ../../modules/common.nix
    ../../modules/linux-desktop.nix
    ../../modules/happy/happy-coder-daemon.nix
    ../../modules/t3code.nix
    ../../modules/paseo.nix

  ];

}
