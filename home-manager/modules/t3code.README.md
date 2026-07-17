# services.t3code

Headless web GUI for coding agents (codex, claude-code, opencode). Runs as a
`jono`-user systemd service bound to `0.0.0.0:3773` on lute. The web UI is
reached at <http://lute:3773>.

## Pairing model

The upstream server has **no static auth-token mode**. The only ways in are:

1. **One-time pairing tokens**, single-use, default TTL 5 minutes.
2. **`desktop-bootstrap`** handoff via `--bootstrap-fd`, used by the
   Electron desktop app from the same machine.

Both are single-shot. Multi-device LAN use needs many tokens. The module
works around this by issuing a batch of long-lived (default `30d`)
`client`-role pairing tokens on every service start via `ExecStartPre`:

```bash
journalctl --user -u t3code.service --no-pager | grep "Pairing token:"
```

Each LAN browser consumes one token on first load and stores a session
cookie (`t3_session`); subsequent loads on that browser don't need another
token. The state lives in `~/.t3/userdata/state.sqlite`.

## Get a fresh token

```bash
# Tokens are written to ~/.t3/pairing-tokens at every service restart.
# The file includes the server URL, a fresh batch of single-use tokens,
# and instructions.
cat ~/.t3/pairing-tokens
head -1 ~/.t3/pairing-tokens  | grep -v '^#'  # latest unconsumed token
```

From any LAN host with SSH:

```bash
ssh lute "head -1 ~/.t3/pairing-tokens | grep -v '^#'"
# Or use scp:
scp lute:~/.t3/pairing-tokens /dev/stdout | tail -10
```

Each token expires 30 days after creation. The default batch is 10; tune
via `services.t3code.pairingTokenCount`. Restarting the service does NOT
invalidate existing tokens — it just adds more.

## Use one

Open <http://lute:3773/pair#token=XXXXXXXXXXXXXXXX> in a browser. The
fragment auto-fills the token field on the pairing page. Paste the raw
token if you don't want to use the URL.

## Provider CLIs

t3code shells out to provider CLIs per session. They must be on the
service's PATH. `home-manager/modules/common.nix` installs `claude-code`
and `gh` for the user; `programs.opencode` in `home-manager/hosts/lute`
installs `opencode`. `services.t3code.extraPackages` adds them to the
unit's PATH explicitly.

`codex` is **not** installed (you said you don't need it).

## Opencode model discovery (upstream bug + workaround)

Upstream t3code hardcodes `OPENCODE_CONFIG_CONTENT="{}"` when it spawns
the opencode subprocess, which makes every provider/model invisible in
the UI (you see "no models found"). The module works around this:

1. **Patches `pkgs.t3code`** at build time: a regex on the built
   `bin.mjs` replaces the unconditional override with a conditional one
   that only fires when `OPENCODE_CONFIG_CONTENT` is *not* already set
   in the parent's env. Apply only when `opencodeConfigPath` is set.
2. **Writes the opencode config** to `~/.t3-opencode-config.env`
   (mode 0600) on every `home-manager switch` via an activation hook.
3. **Loads it** in the systemd unit via `EnvironmentFile=`.

The net effect: when the t3code UI opens a session against the opencode
provider, it sees the user's real `~/.config/opencode/opencode.json`
(ollama providers, custom models, etc.) instead of an empty default.

`programs.opencode.settings` in `hosts/lute/default.nix` is the source
of truth for the opencode config — managed by home-manager, so it lives
in the Nix store and gets read by the activation hook without an impure
flag.

If the upstream bug is fixed, drop `opencodeConfigPath` from the host
config and the patch becomes a no-op (the regex won't match the new
source).

## Opencode skill discovery (upstream gap, no workaround yet)

The opencode provider in t3code does not surface skills from
`~/.agents/skills/` (or wherever opencode discovers them). The
`loadOpenCodeInventory` function calls `app.agents()` and `provider.list()`
but **not** `app.skills()` — so even though opencode CLI shows your
skills, t3code never sees them. Codex has full skill support via a
`skills/list` JSON-RPC call; opencode does not.

Tracked upstream as **[PR #3154 — "Add OpenCode skill discovery"](https://github.com/pingdotgg/t3code/pull/3154)**
(opened 2026-06-18, still open as of this writing). When it lands,
bump the t3code version and the gap closes.

Until then, options for actually using skills in t3code:

- Use the **claude-code** provider in t3code (its driver handles skills).
  The Claude provider uses the same Anthropic API surface as `~/.claude/`
  skills if you point `ANTHROPIC_HOME` / use the `claude` CLI as the
  binary.
- Switch the primary provider to **codex** (full skill support upstream).
  Requires installing + authenticating codex.

A local patch via `overrideAttrs` mirroring PR #3154 is possible but
fragile — it would diverge as soon as upstream merges. Better to wait.

## Claude skill discovery (cwd not threaded — upstream bug)

The Claude provider's capability probe does not thread `cwd` through,
so project-level `.claude/skills/` (e.g. `~/src/coolify/.claude/skills/`)
is not discovered by t3code's composer autocomplete. User-level
`~/.claude/skills/` may or may not show up depending on the probe path
taken. Tracked upstream as:

- **[#2048](https://github.com/pingdotgg/t3code/issues/2048)** — the bug
- **[PR #2124](https://github.com/pingdotgg/t3code/pull/2124)** — the
  fix, still open as of this writing

Restating the bug for posterity (lute @ 2026-07-16):

> Claude skills in `~/.claude/skills/` (symlinked to `~/.agents/skills/`)
> are visible in the `claude` CLI but not in t3code's composer. Project
> skills at `/home/jono/src/coolify/.claude/skills/` are likewise missing.
> Restarting t3 does not help — fix is upstream.

## Files

- Module: `home-manager/modules/t3code.nix`
- Host config: `home-manager/hosts/lute/default.nix` (`services.t3code` block)
- System firewall: `nixos/hosts/lute/default.nix` (`allowedTCPPorts` includes 3773)
- State dir: `~/.t3/userdata/` (managed by `programs.t3code` upstream module)
- Active tokens table: `sqlite3 ~/.t3/userdata/state.sqlite "SELECT * FROM auth_pairing_links;"`