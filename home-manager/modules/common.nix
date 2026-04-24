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
      "sync/savr_data/.stignore".text = syncthingIgnores;

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
          # TODO: telegram MCP via npx does not work - it is an external plugin requiring bun.
          # The proper flow is: claude plugin install telegram@claude-plugins-official
          # then: claude --channels plugin:telegram@claude-plugins-official
          # But --channels requires the plugin to be registered in settings.json (writable).
          # We tried programs.claude-code.mcpServers - generates a file but claude ignores it.
          # We tried programs.claude-code.settings - works but makes settings.json read-only,
          #   blocking `claude plugin install`. Workaround: home.activation to seed a writable
          #   settings.json, then manually run `claude plugin install telegram@...` once.
          #   Even after that, `--channels` loads the plugin but it doesn't actually connect.
          # Leaving telegram out for now.
          # telegram = {
          #   command = "npx";
          #   args = [ "-y" "telegram@claude-plugins-official" ];
          # };
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

  programs.fish = {

    enable = true;

    interactiveShellInit = ''
      set fish_greeting # Disable greeting
    '';

    shellInit = ''
      set -x EDITOR micro

      set -x FLAKE_OS ${hostVars.configsRoot}/nixos
      set -x FLAKE_HOME ${hostVars.configsRoot}/home-manager

      set -x HAPPY_SERVER_URL "https://happy-server.wolf-typhon.ts.net"
      '';

    shellAbbrs = {

      cat = "bat";

      p = "ping dgt.is";

      "..." = "cd ../..";


      # TODO: clean up syncthing conflicts like so:
      # DIFFPROG=org.gnome.meld ./syncthing-resolve-conflicts -d ./common -f

      # or use git-merge! https://www.rafa.ee/articles/resolve-syncthing-conflicts-using-three-way-merge/

    };

    shellAliases = {

      # using impure to source secrets from the filesystem
      i-nixos = "nh os switch --show-activation-logs $FLAKE_OS --impure";

      u-nixos = "cp $FLAKE_OS/flake.lock $FLAKE_OS/lock_backups/$hostname-nixos-flake.lock && i-nixos --update";

      i-home = "nh home switch --show-activation-logs $FLAKE_HOME";

      u-home = "cp $FLAKE_HOME/flake.lock $FLAKE_HOME/lock_backups/$hostname-home-flake.lock && i-home --update";

      i = lib.mkDefault "i-nixos && i-home";

      u = lib.mkDefault "u-home && u-nixos";

      cl = "sudo -v && claude --dangerously-skip-permissions";
      clt = "sudo -v && claude --dangerously-skip-permissions --plugin-dir ~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram";
      fa = "flox activate";
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "fnb" = { # namecheap
        hostname = "199.188.200.147";
        port = 21098;
        user = "foodjkut";
        addKeysToAgent = "yes";
      };
      "rokeachphoto" = { # namecheap
        hostname = "198.54.114.213";
        port = 21098;
        user = "rokeeued";
        addKeysToAgent = "yes";
      };
      "berk_nas" = { # WD My Cloud Nas
        hostname = "192.168.1.140";
        user = "sshd";
        addKeysToAgent = "yes";
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
      encfs
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
      # bun # needed for claude telegram plugin - disabled while telegram integration is shelved
      opencode
      codex
      happy-coder # this is just for the cli, though you probably dont need it since, its mostly used through the happy-coder-daemon
      ollama
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
