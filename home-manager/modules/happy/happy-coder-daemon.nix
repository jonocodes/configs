{ config, lib, pkgs, pkgs-unstable, ... }:

with lib;

let
  cfg = config.services.happy-coder-daemon;

in {
  options.services.happy-coder-daemon = {
    enable = mkEnableOption "Happy Coder daemon service (user service)";

    package = mkOption {
      type = types.package;
      default = pkgs-unstable.happy-coder; # since its not yet in stable. could also pull from llm-agents.nix
      defaultText = literalExpression "pkgs.happy-coder";
      description = "The happy-coder package to use.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.happy-coder";
      defaultText = literalExpression ''"''${config.home.homeDirectory}/.happy-coder"'';
      description = "Directory where happy-coder stores its data";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--yolo" ];
      description = "Additional arguments to pass to happy daemon start";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        HAPPY_LOG_LEVEL = "debug";
      };
      description = "Environment variables to set for the happy-coder daemon";
    };
  };

  config = mkIf cfg.enable {
    # Ensure data directory exists
    home.file."${cfg.dataDir}/.keep".text = "";

    # During a home-manager switch, the service gets stopped if its unit file path
    # changes (even when content is identical — e.g. nixpkgs bump). This kills active
    # happy sessions. These two activation hooks detect whether the unit content actually
    # changed, and if not, restart the service so sessions aren't needlessly interrupted.
    home.activation.happyCoderSnapshotUnit = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      _happyUnitHash=""
      _happyUnitPath="$HOME/.config/systemd/user/happy-coder-daemon.service"
      if [ -L "$_happyUnitPath" ]; then
        _happyUnitHash=$(sha256sum "$(readlink -f "$_happyUnitPath")" 2>/dev/null | cut -d' ' -f1 || true)
      fi
    '';

    home.activation.happyCoderRestoreIfUnchanged = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      _happyUnitPath="$HOME/.config/systemd/user/happy-coder-daemon.service"
      _happyUnitHashNew=""
      if [ -L "$_happyUnitPath" ]; then
        _happyUnitHashNew=$(sha256sum "$(readlink -f "$_happyUnitPath")" 2>/dev/null | cut -d' ' -f1 || true)
      fi
      if [ -n "$_happyUnitHash" ] && [ "$_happyUnitHash" = "$_happyUnitHashNew" ]; then
        # Unit content unchanged — home-manager stopped it unnecessarily, bring it back
        $DRY_RUN_CMD systemctl --user start happy-coder-daemon.service || true
      fi
    '';

    systemd.user.services.happy-coder-daemon = {
      Unit = {
        Description = "Happy Coder Daemon - Mobile control for Claude Code";
        Documentation = "https://github.com/slopus/happy-cli";
        After = [ "network.target" ];
      };

      Service = {
        Type = "forking";
        WorkingDirectory = cfg.dataDir;

        ExecStart = "${cfg.package}/bin/happy daemon start ${escapeShellArgs cfg.extraArgs}";
        ExecStop = "${cfg.package}/bin/happy daemon stop";

        Restart = "on-failure";
        RestartSec = "10s";

        Environment = mapAttrsToList (name: value: "${name}=${value}") cfg.environment
          ++ [ "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:${config.home.homeDirectory}/.nix-profile/bin" ];

        LimitNOFILE = "65536";

        # TODO: orphaned claude processes accumulate ~285MB each on --resume (memory leak)
        # Track: https://github.com/slopus/happy-cli/issues/164
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
