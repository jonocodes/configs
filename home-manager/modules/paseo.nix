# paseo — self-hosted web service for orchestrating coding agents.
# https://paseo.sh  (source: https://github.com/getpaseo/paseo)
#
# Runs the paseo daemon headlessly with its bundled web UI as a user systemd
# service. We only care about the self-hosted web service here (not the
# desktop/mobile apps or the hosted relay), so by default the relay is
# disabled and the daemon binds to the LAN for browser access — e.g.
# http://lute:6767 — gated behind a password.
#
# paseo isn't in nixpkgs; the package is built locally from the proprietary
# `@getpaseo/cli` npm package. See ../packages/paseo.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.paseo;

  paseoExe = lib.getExe cfg.package;

  # The env file that carries PASEO_PASSWORD to the service. Written at
  # activation from cfg.passwordFile (see below) so the password never lands
  # in the world-readable nix store.
  passwordEnvFile = "${config.home.homeDirectory}/.paseo-password.env";

in {
  options.services.paseo = {
    enable = mkEnableOption "paseo web service (headless daemon + web UI, user service)";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../packages/paseo { };
      defaultText = literalExpression "pkgs.callPackage ../packages/paseo { }";
      description = "The paseo package to use (provides the `paseo` CLI/daemon).";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = ''
        Host/interface the daemon binds to. Use "127.0.0.1" to restrict to
        loopback (e.g. when fronting it with a reverse proxy / tunnel), or
        "0.0.0.0" to reach it from other devices on the LAN.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 6767;
      description = "Port the paseo daemon/web UI listens on.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.paseo";
      defaultText = literalExpression ''"''${config.home.homeDirectory}/.paseo"'';
      description = ''
        paseo home directory (`--home` / PASEO_HOME): daemon state, config.json,
        credentials, and the hashed password all live here.
      '';
    };

    webUi = mkOption {
      type = types.bool;
      default = true;
      description = "Serve the bundled web UI from the daemon (`--web-ui`).";
    };

    relay = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Connect to paseo's end-to-end-encrypted hosted relay so clients can
        reach the daemon without direct network access. Disabled by default —
        for a LAN-only self-hosted web service the daemon needs no outbound
        relay connection. Set true to enable relay/mobile pairing.
      '';
    };

    hostnames = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "lute,.lan,paseo.example.com";
      description = ''
        DNS-rebinding protection: comma-separated allowed Host headers
        (`--hostnames`). Use "true" to allow any host. Leave null to keep the
        daemon default (which permits localhost + the listen address).
      '';
    };

    passwordFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = literalExpression ''"''${config.home.homeDirectory}/.config/secrets/paseo-password"'';
      description = ''
        Path to a file containing the plaintext daemon password. On every
        `home-manager switch` its contents are copied (at runtime, NOT via the
        nix store) to `${passwordEnvFile}` (mode 0600) as PASEO_PASSWORD, which
        paseo hashes into its config on startup.

        Strongly recommended before exposing the daemon beyond loopback: the
        static web assets load without auth, but the API/WebSocket require the
        password. Leave null only for a loopback-only / trusted setup.
      '';
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--no-mcp" ];
      description = "Additional arguments passed to `paseo daemon start`.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.claude-code pkgs.opencode pkgs.codex ]";
      description = ''
        Agent provider CLIs (and other tools) that paseo should find on PATH
        when it shells out to run agents. git is already included by default.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = { PASEO_LOG_LEVEL = "debug"; };
      description = "Extra environment variables for the daemon.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = cfg.host == "127.0.0.1" || cfg.host == "localhost" || cfg.passwordFile != null;
      message = ''
        services.paseo: the daemon binds to ${cfg.host} (not loopback) but no
        passwordFile is set. Set services.paseo.passwordFile, or bind to
        127.0.0.1, before exposing paseo to the network.
      '';
    }];

    # Ensure the state dir exists.
    home.file."${cfg.stateDir}/.keep".text = "";

    # Copy the password into a 0600 env file at activation. Done at runtime
    # (`cat` in the activation script) rather than with builtins.readFile so
    # the secret never enters the nix store.
    home.activation.paseoWritePassword = mkIf (cfg.passwordFile != null)
      (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        _paseoSrc=${lib.escapeShellArg cfg.passwordFile}
        _paseoTarget=${lib.escapeShellArg passwordEnvFile}
        if [ -f "$_paseoSrc" ]; then
          $DRY_RUN_CMD install -m600 /dev/null "$_paseoTarget"
          $DRY_RUN_CMD printf 'PASEO_PASSWORD=%s\n' "$(cat "$_paseoSrc")" > "$_paseoTarget"
        else
          echo "services.paseo: passwordFile $_paseoSrc not found; PASEO_PASSWORD not set" >&2
        fi
      '');

    # A home-manager switch stops the unit whenever its file *path* changes,
    # even if the content is identical (e.g. a one-commit nixpkgs bump) — which
    # kills any in-flight agent sessions. Snapshot the unit hash before/after
    # and restart it ourselves if nothing actually changed. (Same pattern as
    # services.t3code / services.happy-coder-daemon.)
    home.activation.paseoSnapshotUnit = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      _paseoUnitHash=""
      _paseoUnitPath="$HOME/.config/systemd/user/paseo.service"
      if [ -L "$_paseoUnitPath" ]; then
        _paseoUnitHash=$(sha256sum "$(readlink -f "$_paseoUnitPath")" 2>/dev/null | cut -d' ' -f1 || true)
      fi
    '';

    home.activation.paseoRestoreIfUnchanged = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      _paseoUnitPath="$HOME/.config/systemd/user/paseo.service"
      _paseoUnitHashNew=""
      if [ -L "$_paseoUnitPath" ]; then
        _paseoUnitHashNew=$(sha256sum "$(readlink -f "$_paseoUnitPath")" 2>/dev/null | cut -d' ' -f1 || true)
      fi
      if [ -n "$_paseoUnitHash" ] && [ "$_paseoUnitHash" = "$_paseoUnitHashNew" ]; then
        # Use an absolute systemctl + XDG_RUNTIME_DIR, exactly as home-manager's
        # own reloadSystemd does — bare `systemctl` isn't on PATH during
        # activation, so it would silently no-op (and print "command not found").
        $DRY_RUN_CMD env XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
          ${pkgs.systemd}/bin/systemctl --user start paseo.service || true
      fi
    '';

    systemd.user.services.paseo = {
      Unit = {
        Description = "paseo — self-hosted web service for orchestrating coding agents";
        Documentation = "https://paseo.sh/docs";
        After = [ "network.target" ];
      };

      Service = {
        Type = "simple";
        WorkingDirectory = config.home.homeDirectory;

        ExecStart = lib.concatStringsSep " " (map lib.escapeShellArg (
          [
            paseoExe "daemon" "start"
            "--foreground"
            "--home" cfg.stateDir
            "--listen" "${cfg.host}:${toString cfg.port}"
            (if cfg.webUi then "--web-ui" else "--no-web-ui")
          ]
          ++ lib.optional (!cfg.relay) "--no-relay"
          ++ lib.optionals (cfg.hostnames != null) [ "--hostnames" cfg.hostnames ]
          ++ cfg.extraArgs
        ));

        Restart = "on-failure";
        RestartSec = "5s";

        # The systemd user-manager PATH is too sparse to find the agent CLIs
        # paseo spawns. Build a deterministic PATH: git + the configured extras,
        # then the usual nix profile locations.
        Environment = mapAttrsToList (n: v: "${n}=${v}") cfg.environment ++ [
          "HOME=${config.home.homeDirectory}"
          "PASEO_HOME=${cfg.stateDir}"
          "PATH=${makeBinPath ([ pkgs.git ] ++ cfg.extraPackages)}:/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:${config.home.homeDirectory}/.nix-profile/bin"
        ];

        EnvironmentFile = lib.mkIf (cfg.passwordFile != null) [ passwordEnvFile ];

        LimitNOFILE = "65536";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
