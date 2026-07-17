# t3code 0.0.28 fork — final working state (2026-07-16)

## Status: WORKING

Build succeeded. Service activated with the fork.

## What works

- `pkgs.t3code` is overridden to `t3code-server-0.0.28` via a lute-flake overlay
  (`home-manager/hosts/lute/flake.nix` overlays.default).
- The derivation (`home-manager/packages/t3code-fork.nix`) fetches source from
  `pingdotgg/t3code` tag `v0.0.28`, fetches pnpm deps offline via
  `fetchPnpmDeps` (fetcherVersion=4), installs with `pnpm install --offline`,
  builds via `vp run --filter t3 build`, compiles node-pty from source.
- The OPENCODE_CONFIG_CONTENT patch (same as the 0.0.24 fix) is applied in
  postInstall: the bin.mjs honors an inherited OPENCODE_CONFIG_CONTENT env var.
- The service systemd unit loads OPENCODE_CONFIG_CONTENT from
  `~/.t3-opencode-config.env` (written by home-manager activation).

## Key files

| File | Purpose |
|------|---------|
| `home-manager/packages/t3code-fork.nix` | The Nix derivation (server-only t3code v0.0.28) |
| `home-manager/hosts/lute/flake.nix` | Overlay wiring (lute-flake exposes overlays.default) |
| `home-manager/flake.nix` (line ~122) | `pkgs.appendOverlays` in mkHomeWithFlake |
| `home-manager/modules/t3code.nix` | The systemd service module (uses pkgs.t3code via `services.t3code.package`) |
| `home-manager/hosts/lute/default.nix` (line ~205) | Lute's host config that enables the service |
| `nixos/hosts/lute/default.nix` | Firewall: `allowedTCPPorts = [ 4444 3773 ]` |

## Build invocation (for manual testing)

```bash
cd /home/jono/sync/configs/nixos
nix-build /tmp/t3code-build.nix --no-out-link
```

where `/tmp/t3code-build.nix` is:

```nix
let
  pkgs = import <nixpkgs> {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
  import /home/jono/sync/configs/home-manager/packages/t3code-fork.nix {
    inherit (pkgs) lib stdenv fetchFromGitHub fetchPnpmDeps pnpm_10
      nodejs_24 makeWrapper cacert python3 pkg-config node-gyp installShellFiles
      openssl jq sqlite zstd;
  }
```

## Hashes

| Hash | Purpose |
|------|---------|
| `sha256-InVrw9L281QSSPrHSiZuivmb+FkYEd6FkHwHIAAxmGk=` | Source tarball v0.0.28 |
| `sha256-DgUQpJZPRIZ99VuVfLf0FFK6EZtutPB9WSOiBsCReD8=` | pnpm deps (full workspace, fetcherVersion=4) |

## Build pipeline

1. `fetchPnpmDeps` — fetches the entire workspace tree offline (tarball store).
2. `buildPhase`: `pnpm install --offline` → `(cd apps/server && ../../node_modules/.bin/vp run --filter t3 build)` → `node-gyp rebuild` (node-pty).
3. `installPhase`: copies workspace state into `$out/libexec/t3code/`:
   - `.pnpm` store (npm deps)
   - `apps/server/{dist,node_modules}`
   - `apps/web/dist` (bundled frontend)
   - `packages/{contracts,shared,tailscale,ssh,client-runtime,effect-acp,effect-codex-app-server}`
   - Removes dangling symlinks (remaining after pruning)
   - Wraps `node` to run `bin.mjs` as `$out/bin/t3code`
4. `postInstall` (inline): applies OPENCODE_CONFIG_CONTENT regex patch.

## Upstream bugs needing tracking with this fork

- **OPENCODE_CONFIG_CONTENT hardcode** — server unconditionally forces it to `{}`.
  Patched here; if/when upstream fixes it, the regex becomes a no-op.
- **OpenCode skill discovery** — upstream PR #3154 (not in 0.0.28 either).
- **Claude cwd probing** — upstream PR #2124 (not in 0.0.28 either).

## Working tokens (as of last activation)

The ExecStartPre issued 10 long-lived tokens when the service started.
Find the latest with:

  journalctl --user -u t3code.service --no-pager | grep "Pairing token:" | tail -10

**API change from 0.0.24:** The bootstrap endpoint is now
`POST /api/auth/browser-session` (was `/api/auth/bootstrap`).
The JSON body is the same: `{"credential":"<TOKEN>"}`.

To pair a browser: go to the URL printed in the `serve` startup logs,
or manually POST to the browser-session endpoint, or use the pairing
URL printed on start:

  journalctl --user -u t3code.service --no-pager | grep "Pairing URL"

## Outstanding work

- **Once the upstream nixpkgs tracks a version >= 0.0.29 stable**, evaluate whether
  the fork still adds value (0.0.24–0.0.28 were mostly vendored dep churn, not
  functional changes). If nixpkgs catches up, drop the overlay.

- **If you forget: the service gives you tokens on every restart**:
  ```bash
  systemctl --user restart t3code.service
  journalctl --user -u t3code.service --no-pager | grep "Pairing token:" | tail -10
  ```

- **To switch back to nixpkgs pkgs.t3code**: remove the overlay from
  `lute/flake.nix` and delete `openCodeConfigPath` from the host config. The
  0.0.24 derivation + the in-module patch still works.

## Where we left off

**Working state**: source unpacks, build phase runs `pnpm install` and
calls `./node_modules/.bin/vp pack --filter t3`. The build fails because
**pnpm tries to self-bootstrap its pinned version (10.24.0) via corepack**
in the build sandbox.

The pinned version (10.24.0) is different from the system pnpm_10
(10.33.4 from nixpkgs). When pnpm sees a `packageManager` field in
`package.json`, it tries to download that exact version into
`$HOME/.local/share/pnpm/.tools/pnpm/...` — but the sandbox has no
network access, so it fails with:

```
ERR_PNPM_META_FETCH_FAIL  GET https://registry.npmjs.org/pnpm
request to https://registry.npmjs.org/pnpm failed, reason:
getaddrinfo EAI_AGAIN registry.npmjs.org
```

We tried `COREPACK_ENABLE_STRICT=0` and `COREPACK_ENABLE_DOWNLOAD_PROMPT=0`
in the env, plus setting `HOME=/tmp/build-home` to a writable dir.
pnpm still triggers the bootstrap attempt.

## Next steps

Three viable paths forward (any one will unblock the build):

### Option A: patch package.json to drop `packageManager` (recommended)

In `buildPhase`, before running `pnpm install`:

```bash
sed -i 's/"packageManager": "pnpm@10.24.0",//' package.json
# or use jq for safer patching:
jq 'del(.packageManager)' package.json > package.json.new && mv package.json.new package.json
```

This tells pnpm to use the system version directly. Cleanest fix.

### Option B: use `--use-node-version` / ignore-corepack flags

Check `pnpm install --help` for a flag that bypasses the version check.
Possible candidates:

- `pnpm install --config.manage-package-manager-versions=false`
- `pnpm install --prefer-offline` (if we pre-populate the cache)
- Set `npm_config_manage_package_manager_versions=false`

If any of these work, no source patching needed.

### Option C: vendor pnpm 10.24.0 into the derivation

Add a second `buildInputs` entry that provides pnpm 10.24.0 (via
`buildNpmPackage` or a fetcher) and prepend it to PATH. Then corepack
finds it locally and doesn't try to download.

Most work, least clean. Avoid unless A and B both fail.

## File state

`home-manager/packages/t3code-fork.nix` — the
in-progress derivation. Key sections:

- Function args (line 20+): lib, stdenv, fetchFromGitHub, **pnpm_10**,
  nodejs_24, makeWrapper, cacert, python3, pkg-config, node-gyp,
  installShellFiles, openssl, jq.
- `src`: `fetchFromGitHub` from `pingdotgg/t3code` tag `v0.0.28`,
  hash `sha256-InVrw9L281QSSPrHSiZuivmb+FkYEd6FkHwHIAAxmGk=`
  (tarball hash, not unpacked tree hash).
- `nativeBuildInputs`: pnpm_10, nodejs_24, node-gyp, pkg-config,
  python3, openssl, cacert, makeWrapper, installShellFiles, jq.
- `env`: sets `ELECTRON_SKIP_BINARY_DOWNLOAD=1`,
  `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`, `npm_config_nodedir=${nodejs_24}`,
  `COREPACK_ENABLE_STRICT=0`, `COREPACK_ENABLE_DOWNLOAD_PROMPT=0`,
  `HOME=/tmp/build-home`.
- `buildPhase`: `mkdir -p $HOME` → `pnpm install --frozen-lockfile
  --ignore-scripts` → `./node_modules/.bin/vp pack --filter t3` →
  node-gyp rebuild for node-pty.
- `installPhase`: copies `apps/server/{dist,node_modules}`,
  `apps/web/dist`, and the workspace packages
  (`packages/{contracts,shared,tailscale,ssh,client-runtime}`) into
  `$out/libexec/t3code/`. Wraps node to run
  `$out/libexec/t3code/apps/server/dist/bin.mjs` as `$out/bin/t3code`.
- `meta`: MIT, x86_64-linux + aarch64-linux, mainProgram = t3code.

## Build invocation

```bash
cd /home/jono/sync/configs/nixos
nix-build /tmp/t3code-build.nix --no-out-link
```

where `/tmp/t3code-build.nix` is:

```nix
let
  pkgs = import <nixpkgs> {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
  import home-manager/packages/t3code-fork.nix {
    inherit (pkgs) lib stdenv fetchFromGitHub pnpm_10 nodejs_24 makeWrapper
      cacert python3 pkg-config node-gyp installShellFiles openssl jq;
  }
```

This is a one-off eval, not in any flake. Once the build succeeds, we'll
wrap it in an overlay inside `home-manager/hosts/lute/flake.nix` (or a
lute-specific flake) so the `services.t3code.package` option in
`home-manager/modules/t3code.nix` can pick it up.

## Follow-on work once the build is green

1. **Apply the OPENCODE_CONFIG_CONTENT patch** to the built
   `bin.mjs`. The pattern (verified against v0.0.28 source):
   `apps/server/src/provider/opencodeRuntime.ts:350-354`:
   ```ts
   env: {
     ...input.environment,
     OPENCODE_CONFIG_CONTENT: OPENCODE_EMPTY_CONFIG_CONTENT,
   },
   ```
   The patched form should match what `home-manager/modules/t3code.nix`
   already does for 0.0.24. Move that regex into a derivation-level
   `postInstall` (instead of the in-module `overrideAttrs`).

2. **Wire the package into the home flake** as an overlay so the
   existing `services.t3code.package` option resolves to this fork.
   Pattern:
   ```nix
   # in hosts/lute/flake.nix outputs
   overlays.default = final: prev: {
     t3code = final.callPackage
       home-manager/packages/t3code-fork.nix
       { ... };
   };
   ```
   Then in the parent `home-manager/flake.nix`, apply it via
   `pkgs = import nixpkgs { inherit system; overlays = [ lute-flake.overlays.default ]; };`
   or similar.

3. **Decide whether to upstream this**. The derivation is structured
   to be a self-contained nixpkgs-style package (fetches from GitHub,
   no external flake inputs, only nixpkgs). It would slot into
   `pkgs/by-name/t3/t3code/` as an alternative to the current
   Electron-wrapping derivation. Worth proposing to nixpkgs as a
   separate attribute (e.g. `t3code-server`) since it solves a
   different problem from the desktop build.

## Verified facts about v0.0.28

- Source: https://github.com/pingdotgg/t3code/tree/v0.0.28
- Tarball hash: `sha256-InVrw9L281QSSPrHSiZuivmb+FkYEd6FkHwHIAAxmGk=`
- Build toolchain: pnpm 10.x + vite-plus (`vp`); Bun is devcontainer-only.
- Lockfile is `pnpm-lock.yaml` (pnpm 9.x format).
- node-pty has no linux prebuild; must be compiled via node-gyp.
- `packageManager: pnpm@10.24.0` in root package.json → triggers
  corepack bootstrap unless patched.
- Server entrypoint: `apps/server/dist/bin.mjs` (built via
  `vp pack --filter t3`).
- Web frontend: `apps/web/dist/` (served by the server).
- Workspace deps consumed by server at runtime:
  `packages/contracts`, `packages/shared`, `packages/tailscale`,
  `packages/ssh`, `packages/client-runtime`.

## Build toolchain references

- `pkgs.pnpm_10` — `/nix/store/xys5zgl9dnfljrxc8d7v45vrjrb4hgx7-pnpm-10.33.4/bin/pnpm` (10.33.4)
- `pkgs.nodejs_24` — `/nix/store/5a8ysg1jnj8jmzzyfcfw7rvpvnp5rfpa-nodejs-24.15.0` (24.15.0)
- `pkgs.node-gyp` — bundled with nodejs_24
- `pkgs.pkg-config`, `pkgs.openssl` — for native module compilation
- `pkgs.python3` — required by node-gyp
- `pkgs.cacert` — for npm registry TLS

## Open question: pnpm 10.24 vs 10.33

The pnpm-lock.yaml is generated against pnpm 10.x. Whether 10.33.4 vs
the locked 10.24.0 produces a bit-identical install is unknown.
If we go with Option A (patch package.json), we're using 10.33.4.
If lockfile resolution drifts, the build will fail with version
constraint errors. May need to also pass `--no-frozen-lockfile` if
that happens, or vendor 10.24.0 (Option C).

## What's NOT being done in this fork

- Web frontend dev server / HMR — we build the production
  `apps/web/dist` and serve it as static files via the server.
- Update-relay infrastructure (`apps/relay`, `infra/relay`).
- Marketing site.
- Desktop bundle (Electron + electron-builder).
- Tests (`vp test run`). Could be added but skipped for now — the
  goal is just a working server.
- node-pty alternative (e.g. BunPTY) — upstream 0.0.28 also has
  BunPTY but the build picks node-pty by default.