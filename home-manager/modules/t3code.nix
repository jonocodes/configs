{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.t3code;

  # Patch t3code to honor an externally-set OPENCODE_CONFIG_CONTENT instead
  # of unconditionally forcing it to "{}". Upstream bug: the server spreads
  # the env and then overwrites OPENCODE_CONFIG_CONTENT with an empty string,
  # which makes every provider/model invisible in the UI.
  #
  # We post-process the built bin.mjs to replace:
  #     env: { ...input.environment ?? process.env, OPENCODE_CONFIG_CONTENT: OPENCODE_EMPTY_CONFIG_CONTENT }
  # with:
  #     env: { ...input.environment ?? process.env, ...(process.env.OPENCODE_CONFIG_CONTENT ? {} : { OPENCODE_CONFIG_CONTENT: OPENCODE_EMPTY_CONFIG_CONTENT }) }
  patchedT3code = cfg.package.overrideAttrs (old: {
    pname = old.pname or "t3code";
    version = old.version or "patched";
    postInstall = (old.postInstall or "") + ''
      target="$out/libexec/t3code/apps/server/dist/bin.mjs"
      if [ ! -f "$target" ]; then
        echo "patchedT3code: $target not found, skipping patch"
        exit 0
      fi
      # If the package already ships the fix (e.g. the 0.0.28 fork), skip.
      if grep -q 'process.env.OPENCODE_CONFIG_CONTENT ? {}' "$target"; then
        echo "patchedT3code: already patched, skipping"
        exit 0
      fi
      ${python3}/bin/python3 - "$target" <<'PYEOF'
      import re, sys
      path = sys.argv[1]
      src = open(path).read()
      pat = re.compile(
          r"env:\s*\{\s*\.\.\.input\.environment\s*\?\?\s*process\.env,\s*\n(\s+)OPENCODE_CONFIG_CONTENT:\s*OPENCODE_EMPTY_CONFIG_CONTENT\s*\n(\s+)\}",
          re.MULTILINE,
      )
      repl = (
          "env: {\n"
          "    ...input.environment ?? process.env,\n"
          "    ...(process.env.OPENCODE_CONFIG_CONTENT ? {} : { OPENCODE_CONFIG_CONTENT: OPENCODE_EMPTY_CONFIG_CONTENT })\n"
          "  }"
      )
      new_src, n = pat.subn(repl, src)
      if n == 0:
          print(f"patchedT3code: pattern not found in {path}; skipping (was upstream source changed?)")
          sys.exit(0)
      if n > 1:
          print(f"patchedT3code: WARNING — replaced {n} occurrences (expected 1)")
      open(path, "w").write(new_src)
      print(f"patchedT3code: patched {path} ({n} occurrence)")
      PYEOF
    '';
  });
  effectivePackage = if cfg.opencodeConfigPath != null then patchedT3code else cfg.package;

  python3 = pkgs.python3;

in {
  options.services.t3code = {
    enable = mkEnableOption "t3code web GUI service (user service)";

    package = mkOption {
      type = types.package;
      default = pkgs.t3code;
      defaultText = literalExpression "pkgs.t3code";
      description = ''
        The t3code package to use. Note: when `opencodeConfigPath` is set,
        the package is automatically post-processed to forward
        `OPENCODE_CONFIG_CONTENT` to the opencode subprocess (workaround for
        upstream <https://github.com/pingdotgg/t3code/issues>). Setting a
        custom package there should still work, but the patch will be applied
        to whichever package you specify.
      '';
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Host/interface the t3code server binds to. Use 127.0.0.1 to restrict to loopback.";
    };

    port = mkOption {
      type = types.port;
      default = 3773;
      description = "Port the t3code server listens on.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.t3/userdata";
      defaultText = literalExpression ''"''${config.home.homeDirectory}/.t3/userdata"'';
      description = "Directory where t3code stores its state, database, and config files.";
    };

    authToken = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "some-long-random-string";
      description = ''
        DEPRECATED — the upstream server doesn't accept a static --auth-token flag.
        Use `pairingTokenCount` / `pairingTokenTtl` instead. Setting this option
        currently has no effect.
      '';
    };

    pairingTokenCount = mkOption {
      type = types.ints.unsigned;
      default = 10;
      example = 20;
      description = ''
        Number of long-lived pairing tokens to issue on each service start
        (via `ExecStartPre`). Each token is single-use — one per LAN host
        (or browser, if you don't reuse cookies). Tokens are logged to the
        journal with the prefix "Pairing token:". Set to 0 to skip the
        ExecStartPre entirely (only the short-lived 5-minute token printed
        by `t3 serve` will be available).
      '';
    };

    pairingTokenTtl = mkOption {
      type = types.str;
      default = "30d";
      example = "30d";
      description = ''
        TTL of each pairing token issued at startup. Use Go duration syntax
        like "5m", "1h", "720h", "30d".
      '';
    };

    pairingTokenLabel = mkOption {
      type = types.str;
      default = "lute-lan-client";
      description = ''
        Prefix label recorded on each token issued at startup. The token
        index is appended (e.g. "lute-lan-client-1"). Helps when reviewing
        `t3 auth pairing list`.
      '';
    };

opencodeConfigPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = literalExpression ''"''${config.home.homeDirectory}/.config/opencode/opencode.json"'';
      description = ''
        Path to a JSON file whose contents are passed to the opencode
        subprocess as `OPENCODE_CONFIG_CONTENT`. This is needed because
        upstream t3code forces `OPENCODE_CONFIG_CONTENT="{}"` on the
        opencode subprocess, which makes every provider/model invisible
        in the UI. Pointing this at your real `opencode.json` lets your
        custom providers/models show up.

        On every `home-manager switch`, the file's contents are copied to
        `~/.t3-opencode-config.env` (mode 0600, owned by the user) and
        loaded by systemd as an EnvironmentFile. The contents do NOT
        appear in the Nix store. Do not put secrets in this file — use
        a credential helper or shell env instead.

        Set to null to keep t3code's default (no models visible).
      '';
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--log-websocket-events" ];
      description = "Additional arguments to pass to `t3code`.";
    };

    # Extra packages that must be on PATH inside the service so t3code can
    # shell out to provider CLIs (claude-code, opencode, codex, gh, git, ...).
    # Order doesn't matter — the service prepends its own PATH on top.
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.claude-code pkgs.opencode pkgs.codex ]";
      description = "Provider CLIs (and other tools) that t3code should be able to find on PATH.";
    };
  };

  config = mkIf cfg.enable {
    # Write the opencode config to the runtime dir on every home-manager
    # activation so systemd can find it at service start. systemd evaluates
    # `EnvironmentFile=` before running `ExecStartPre=`, so this MUST happen
    # here (or via a tmpfiles.d entry), not in a pre-exec script.
    home.activation.t3codeWriteOpencodeConfig = lib.mkIf (cfg.opencodeConfigPath != null) (lib.hm.dag.entryAfter [ "linkGeneration" ] (
      let
        configContent = builtins.readFile cfg.opencodeConfigPath;
      in
      ''
        target="$HOME/.t3-opencode-config.env"
        content=$(printf '%s' ${lib.escapeShellArg configContent} | tr '\n' ' ')
        mkdir -p "$(dirname "$target")"
        printf 'OPENCODE_CONFIG_CONTENT=%s\n' "$content" > "$target"
        chmod 600 "$target"
      ''
    ));
    # Use the upstream home-manager programs.t3code module for its config-file
    # machinery (settings.json, keybindings.json, client-settings.json in
    # ~/.t3/userdata). We only set the package — no static config files, so
    # everything stays mutable from the UI.
    programs.t3code.enable = true;
    programs.t3code.package = effectivePackage;

    # Activation: snapshot the rendered unit path before/after a home-manager
    # switch, and re-start the service if the unit content is unchanged.
    # Without this, every `home-manager switch` (even when only nixpkgs bumped
    # by a single commit) stops the service and kills any in-flight agent
    # sessions. This hook is copied from services.happy-coder-daemon.
    home.activation.t3codeSnapshotUnit = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      _t3codeUnitHash=""
      _t3codeUnitPath="$HOME/.config/systemd/user/t3code.service"
      if [ -L "$_t3codeUnitPath" ]; then
        _t3codeUnitHash=$(sha256sum "$(readlink -f "$_t3codeUnitPath")" 2>/dev/null | cut -d' ' -f1 || true)
      fi
    '';

    home.activation.t3codeRestoreIfUnchanged = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      _t3codeUnitPath="$HOME/.config/systemd/user/t3code.service"
      _t3codeUnitHashNew=""
      if [ -L "$_t3codeUnitPath" ]; then
        _t3codeUnitHashNew=$(sha256sum "$(readlink -f "$_t3codeUnitPath")" 2>/dev/null | cut -d' ' -f1 || true)
      fi
      if [ -n "$_t3codeUnitHash" ] && [ "$_t3codeUnitHash" = "$_t3codeUnitHashNew" ]; then
        systemctl --user start t3code.service || true
      fi
    '';

    systemd.user.services.t3code = {
      Unit = {
        Description = "t3code — web GUI for coding agents";
        Documentation = "https://t3.codes";
        After = [ "network.target" ];
      };

      Service = {
        Type = "simple";
        WorkingDirectory = config.home.homeDirectory;

        # Issue a batch of fresh long-lived pairing tokens before starting
        # the server. Without this, only the short-lived (5 min) one-time
        # token printed by `t3 serve` is available, which is useless for a
        # headless service that's only reached intermittently.
        #
        # Each token is single-use (the server marks it consumed on first
        # POST to /api/auth/bootstrap), so we issue enough for one token per
        # LAN host. Pull more by restarting the service — the next batch is
        # logged to the journal:
        #   journalctl --user -u t3code.service | grep "Pairing token:"
        ExecStartPre = lib.optional (cfg.pairingTokenCount > 0) (
          let
            script = pkgs.writeShellScript "t3code-issue-pairing-tokens" (
              ''
              set -euo pipefail
              token_file="${config.home.homeDirectory}/.t3/pairing-tokens"
              cat > "$token_file" <<'HEADER'
# t3code pairing tokens (single-use, one per LAN browser session).
# Restart the service to issue a fresh batch:
#   systemctl --user restart t3code.service
# Server URL: http://192.168.30.117:3773
HEADER
              chmod 600 "$token_file"
              '' + lib.concatMapStringsSep "\n" (
                i: ''
                  credential=$(${effectivePackage}/bin/t3code auth pairing create \
                    --ttl ${lib.escapeShellArg cfg.pairingTokenTtl} \
                    --label ${lib.escapeShellArg "${cfg.pairingTokenLabel}-${toString i}"} \
                    --json | ${lib.getExe pkgs.jq} -r .credential)
                  echo "$credential" >> "$token_file"
                  echo "Pairing token: $credential"
                ''
              ) (lib.range 1 cfg.pairingTokenCount)
            );
          in
          "${script}"
        );

        ExecStart = lib.mkForce (lib.concatMapStringsSep " " (s: lib.escapeShellArg s) (
          [ "${effectivePackage}/bin/t3code" "serve" "--host" cfg.host "--port" "${toString cfg.port}" "--no-browser" "--auto-bootstrap-project-from-cwd=false" ]
          ++ cfg.extraArgs
        ));

        Restart = "on-failure";
        RestartSec = "5s";

        # The default NixOS service PATH (set by systemd's user manager) is too
        # sparse to find the provider CLIs. Build a deterministic PATH that
        # includes t3code itself, the extras, and the regular nix profile path
        # (so anything in ~/.nix-profile/bin is also reachable).
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "PATH=${makeBinPath ([ effectivePackage ] ++ cfg.extraPackages)}:/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:${config.home.homeDirectory}/.nix-profile/bin"
        ];

        # OPENCODE_CONFIG_CONTENT carries a (possibly multi-line) JSON blob,
        # which can't go inline in `Environment=` (systemd doesn't handle
        # multi-line values). The home-manager activation script writes it
        # to ~/.t3-opencode-config.env (mode 0600) before the service starts,
        # and we load it via EnvironmentFile=. systemd evaluates
        # EnvironmentFile= BEFORE running ExecStartPre=, so the file must
        # already exist when the service starts — hence the activation hook.
        EnvironmentFile = lib.mkIf (cfg.opencodeConfigPath != null) [
          "${config.home.homeDirectory}/.t3-opencode-config.env"
        ];

        LimitNOFILE = "65536";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
