{ pkgs, pkgs-unstable, lib, inputs, modulesPath, home-manager, hostVars, ... }:
let

  syncthingIgnores = builtins.readFile ../files/syncthingIgnores.txt;

in {

  home.username = hostVars.username;
  home.homeDirectory = hostVars.homeDirectory;

  home.stateVersion = lib.mkDefault "25.11";

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  home.file = lib.mkMerge [

    {
      "sync/common/.stignore".text = syncthingIgnores;
      "sync/configs/.stignore".text = syncthingIgnores;
      "sync/more/.stignore".text = syncthingIgnores;
      # "sync/savr_data/.stignore".text = syncthingIgnores;

      # ".ssh/authorized_keys" = {
      #   text = pubKeys;
      # };

      ".claude/hooks/sudo-check.sh" = {
        executable = true;
        source = ../files/claude-sudo-check.sh;
      };

      # MCP servers config - claude reads this from home directory.
      # Note: mcpServers in ~/.claude/settings.json is NOT read by claude for MCP;
      # it must live here in ~/.mcp.json (user-level) or .mcp.json (project-level).
      ".mcp.json".text = builtins.toJSON {
        mcpServers = {
          playwright = {
            command = "npx";
            args = [ "-y" "@playwright/mcp@latest" ];
          };
        };
      };

      ".config/opencode/AGENTS.md".source = ../files/AGENTS.md;

      ".codex/AGENTS.md".source = ../files/AGENTS.md;
      ".claude/CLAUDE.md".source = ../files/AGENTS.md;

      ".config/opencode/plugins/sudo-check.ts".source = ../files/opencode-sudo-check.ts;

      # restores scrolling to screen command
      ".screenrc".text = "termcapinfo xterm* ti@:te@";
      ".tmux.conf".text = "set -g mouse on";
    }

    # (lib.mapAttrs'
    #   (name: _: {
    #     name = ".ssh/${name}";
    #     value = { source = "${sshKeyDir}/${name}"; };
    #   })
    #   sshKeys)
  ];

  # home.sessionVariables = {
  #   HAPPY_SERVER_URL = "https://happy-server.wolf-typhon.ts.net";
  # };

  # only enableing bash here so user shell aliases work across shells
  programs.bash = {
    enable = true;

    # HM only sources hm-session-vars.sh from ~/.profile (login shells), so
    # interactive non-login bash misses home.sessionVariables (EDITOR, BROWSER,
    # XDG_*). Source it here too. The file self-guards via __HM_SESS_VARS_SOURCED,
    # and our fish session leaks that flag with incomplete values, so unset it
    # first to force a full re-export.
    initExtra = ''
      unset __HM_SESS_VARS_SOURCED
      . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    '';
  };

  programs.fish = {

    enable = true;

    # Use unstable to keep fish in sync with the NixOS system fish (which is
    # newer than the stable 25.11 fish). Mismatched versions cause the 4.3
    # fish_key_bindings migration to loop forever — the older fish re-sets the
    # universal var on every shell startup.
    package = pkgs-unstable.fish;

    # HM's manpage→fish completion generator hard-codes
    # $fish/share/fish/tools/create_manpage_completions.py; fish 4.8.1 removed
    # that path, so the build fails. Native fish completions are unaffected.
    generateCompletions = false;

    interactiveShellInit = ''
      set fish_greeting # Disable greeting
    '';

    shellInit = ''
      # config.fish sources hm-session-vars.fish before this, but the stale
      # __HM_SESS_VARS_SOURCED flag leaking from the systemd user environment
      # makes it bail early. Clear the flag and
      # re-run the function it already defined to force a full re-export.
      set -e __HM_SESS_VARS_SOURCED
      setup_hm_session_vars

      # set -x FLAKE_OS ${hostVars.configsRoot}/nixos
      # set -x FLAKE_HOME ${hostVars.configsRoot}/home-manager
      # set -x HAPPY_SERVER_URL "https://happy-server.wolf-typhon.ts.net"
      '';

    shellAbbrs = {

      cat = "bat";

      p = "ping dgt.is";

      "..." = "cd ../..";

      # TODO: clean up syncthing conflicts like so:
      # DIFFPROG=org.gnome.meld ./syncthing-resolve-conflicts -d ./common -f

      # or use git-merge! https://www.rafa.ee/articles/resolve-syncthing-conflicts-using-three-way-merge/

    };

  };

  home.shellAliases = {

    # using impure to source secrets from the filesystem
    i-nixos = "nh os switch --show-activation-logs $FLAKE_OS --impure";

    # Per-host flakes have their own lock; parent-flake update doesn't
    # cascade into path: inputs, so update it first.
    u-nixos = "test -e $FLAKE_OS/hosts/$hostname/flake.nix && nix flake update --flake $FLAKE_OS/hosts/$hostname; cp $FLAKE_OS/flake.lock $FLAKE_OS/lock_backups/$hostname-nixos-flake.lock && i-nixos --update";

    i-home = "nh home switch --show-activation-logs $FLAKE_HOME";

    # Per-host flakes (lute, ocarina, zeeba, matcha, orc) have their own lock;
    # parent-flake update doesn't cascade into path: inputs, so update it first.
    u-home = "test -e $FLAKE_HOME/hosts/$hostname/flake.nix && nix flake update --flake $FLAKE_HOME/hosts/$hostname; cp $FLAKE_HOME/flake.lock $FLAKE_HOME/lock_backups/$hostname-home-flake.lock && i-home --update";

    i = lib.mkDefault "i-nixos && i-home";

    u = lib.mkDefault "u-home && u-nixos";

    cl = "sudo -v && claude --dangerously-skip-permissions";

    fa = "flox activate";
  };

  home.sessionVariables = {

    EDITOR = "micro";

    FLAKE_OS ="${hostVars.configsRoot}/nixos";

    FLAKE_HOME = "${hostVars.configsRoot}/home-manager";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "fnb" = { # namecheap
        HostName = "199.188.200.147";
        Port = 21098;
        User = "foodjkut";
        AddKeysToAgent = "yes";
      };
      "rokeachphoto" = { # namecheap
        HostName = "198.54.114.213";
        Port = 21098;
        User = "rokeeued";
        AddKeysToAgent = "yes";
      };
      "berk_nas" = { # WD My Cloud Nas
        HostName = "berk-nas";
        User = "sshd";
        AddKeysToAgent = "yes";
      };
    };

    # extraConfig = ''
    #   # Auto-include all keys
    #   ${lib.concatMapStrings (key: key + "\n") pubKeys}
    # '';
  };

  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      user = {
        name = "Jono";
        email = "jono@foodnotblogs.com";
      };
    };
  };
  

  # favor apps to not use root for security
  # requires a logout of gnome after an install to show the launcher?
  home.packages = with pkgs-unstable;
    [

      # system, terminal
      bat
      jq
      file
      screen
      tmux
      gnumake
      just
      unzip
      pv
      # parallel-disk-usage # pdu cli
      fishPlugins.z # using this instead of zoxide since I prefer its tab completion
      # encfs # removed from nixpkgs — depended on deprecated fuse2
      lsof
      lazydocker
      lazygit
      witr

      # editors, networking
      # htop
      btop
      iotop
      wget
      dig
      inetutils
      nmap
      iperf3
      speedtest-cli
      sqlite

      lynx
      # browsh

      # helix
      micro

      # nix helpers
      nvd
      # rnix-lsp
      nh
      comma  # run uninstalled apps ie > , xeyes . does not work well
      # age # for sops encryption
      # sops

      #   nix binary runner helpers
      # nix-index
      # nix-locate
      # steam-run # x86 only
      # TODO: https://github.com/thiagokokada/nix-alien
      #   other methods: https://unix.stackexchange.com/questions/522822/different-methods-to-run-a-non-nixos-executable-on-nixos

      # AI tools
      gh # home-manager programs.gh.settings does not really cover all auth I want anyway. still need to manually 'gh auth login' first time.
      claude-code
      nodejs # needed for npx (used by claude mcp servers)
      # opencode # now installed via programs.opencode in lute/default.nix
      # codex
      # happy-coder # this is just for the cli, though you probably dont need it since, its mostly used through the happy-coder-daemon
      # ollama-rocm
      ripgrep

    ] ++ (with pkgs; [

    ]);

  # Seed claude settings.json as a writable file so plugins can modify it.
  # Only writes if the file doesn't already exist (preserving plugin-installed state).
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_file="$HOME/.claude/settings.json"
    if [ ! -f "$settings_file" ] || [ -L "$settings_file" ]; then
      rm -f "$settings_file"
      mkdir -p "$(dirname "$settings_file")"
      cat > "$settings_file" << 'SETTINGS_EOF'
{
  "skipDangerousModePermissionPrompt": true,
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/sudo-check.sh"
          }
        ]
      }
    ]
  },
  "web_fetch": {
    "allowed_domains": ["*"]
  }
}
SETTINGS_EOF
    fi
  '';

}
