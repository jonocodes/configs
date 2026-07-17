# t3code 0.0.28 fork — handoff notes (2026-07-16)

Goal: build a server-only Nix derivation of `pingdotgg/t3code` v0.0.28
replacing the nixpkgs `pkgs.t3code` (currently 0.0.24, Electron desktop
wrapper, builds with pnpm + Bun).

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

`/home/jono/sync/configs/nixos/packages/t3code-fork.nix` — the
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
  import /home/jono/sync/configs/nixos/packages/t3code-fork.nix {
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
       /home/jono/sync/configs/nixos/packages/t3code-fork.nix
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