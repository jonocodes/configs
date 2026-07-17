# Fork of pingdotgg/t3code at v0.0.28.
#
# Why: nixpkgs tracks 0.0.24; upstream has moved to 0.0.29-nightly with a
# new build toolchain (vite-plus). Bumping nixpkgs would drag unrelated
# updates, so we vendor the headless server from a pinned tag.
#
# Build pipeline (per upstream .github/workflows/release.yml):
#   fetch-pnpm-deps → cached offline pnpm store
#   pnpm install --offline (with the fetched store)
#   ./node_modules/.bin/vp pack --filter t3   # vite-plus builds the server
#   node-gyp rebuild                           # node-pty native
#
# What we DON'T ship (not needed for headless server):
#   - Electron desktop bundle
#   - Marketing site
#   - Update-relay infrastructure
#
# Intended to be submitted upstream as an alternative nixpkgs derivation
# for the server-only use case (current nixpkgs wraps the desktop).

{ lib
, stdenv
, fetchFromGitHub
, fetchPnpmDeps
, pnpm_10
, nodejs_24
, makeWrapper
, cacert
, python3
, pkg-config
, node-gyp
, installShellFiles
, openssl
, jq
, sqlite
, zstd
, ...
}:

let
  pname = "t3code-server";
  version = "0.0.28";

  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    tag = "v${version}";
    hash = "sha256-InVrw9L281QSSPrHSiZuivmb+FkYEd6FkHwHIAAxmGk=";
  };

  # Fetch the entire pnpm dependency tree for the `t3` workspace filter.
  # Note: `apps/server/vite.config.ts` has `dependsOn: ["@t3tools/web#build"]`,
  # so even just building the server pulls in web deps too. Fetching the
  # whole workspace tree (no --filter) avoids missing-deps errors.
  # This is done as a separate derivation so all registry fetches happen
  # in a fixed-output (offline) context. Hash to be computed on first
  # build attempt.
  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    pnpm = pnpm_10;
    hash = "sha256-DgUQpJZPRIZ99VuVfLf0FFK6EZtutPB9WSOiBsCReD8=";
    fetcherVersion = 4;
  };
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version src;

  nativeBuildInputs = [
    pnpm_10
    nodejs_24
    node-gyp
    pkg-config
    python3
    openssl
    cacert
    makeWrapper
    installShellFiles
    jq
    sqlite
  ];

  dontStrip = true;

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    npm_config_nodedir = "${nodejs_24}";
    COREPACK_ENABLE_STRICT = "0";
    COREPACK_ENABLE_DOWNLOAD_PROMPT = "0";
    HOME = "/tmp/build-home";
  };

  buildPhase = ''
    runHook preBuild

    mkdir -p "$HOME"

    # Strip the `packageManager` field so pnpm doesn't try to self-bootstrap
    # 10.24.0 via corepack (no network in sandbox). The system pnpm_10 is
    # 10.33.4; the lockfile is still compatible (lockfileVersion 9.x covers
    # all 10.x versions).
    ${jq}/bin/jq "del(.packageManager)" package.json > package.json.tmp
    mv package.json.tmp package.json

    # The fetched pnpm store is in the read-only nix store as a single
    # tar.zst archive (fetcherVersion=4 format). pnpm needs a writable
    # directory; extract into $HOME/.local/share/pnpm/store/v3.
    pnpm_store="$HOME/.local/share/pnpm/store/v3"
    mkdir -p "$pnpm_store"
    ${zstd}/bin/zstd -dc "${pnpmDeps}/pnpm-store.tar.zst" | tar -x -C "$pnpm_store"
    chmod -R u+w "$pnpm_store"

    # 1. install pnpm deps from the offline store. We use --frozen-lockfile
    # without --filter to install the full workspace; the build command
    # downstream filters to the server.
    pnpm install --offline --frozen-lockfile --ignore-scripts \
      --store-dir "$pnpm_store"

    # 2. Build the server. The server's `vite.config.ts` declares a `build`
    #    task that depends on the web app too. Must be run from the server's
    #    directory so relative paths resolve correctly. `vp` is the
    #    vite-plus CLI installed as a workspace devDependency.
    ( cd apps/server && ../../node_modules/.bin/vp run --filter t3 build )

    # 3. node-pty has no linux prebuild. Build from source.
    # Use the node-gyp shipped with nodejs_24 (in pkgs.nodejs_24's npm);
    # npx would try to fetch from the registry and fail in the sandbox.
    pty_pkg="$(node -e "console.log(require.resolve('node-pty/package.json', { paths: ['./apps/server'] }))")"
    pty_dir="$(dirname "$pty_pkg")"
    ( cd "$pty_dir" && ${nodejs_24}/lib/node_modules/npm/bin/node-gyp-bin/node-gyp rebuild )

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/libexec/t3code/apps/server" "$out/libexec/t3code/apps/web"

    # pnpm hoists deps into a workspace-level node_modules/.pnpm/ store and
    # symlinks individual packages into each workspace's node_modules. We
    # need both: the .pnpm store (target of the symlinks) AND the per-
    # workspace node_modules (the symlinks themselves).
    #
    # The pnpm store also has symlinks pointing to workspace apps/packages
    # we don't ship (apps/mobile, apps/marketing, apps/desktop, etc.).
    # Prune those after copying — they're not needed for the server.
    mkdir -p "$out/libexec/t3code/node_modules"
    cp -r node_modules/.pnpm "$out/libexec/t3code/node_modules/" || true
    cp -r node_modules/.modules.yaml "$out/libexec/t3code/node_modules/" 2>/dev/null || true
    # Prune any remaining broken symlinks. pnpm creates some that point to
    # workspace packages we don't ship (apps/mobile, apps/marketing,
    # apps/desktop, packages/effect-acp, etc.). The check is intentionally
    # broad: anything pointing outside the pnpm store is removed.
    find "$out/libexec/t3code" -type l ! -exec test -e {} \; -print -delete 2>/dev/null || true

    cp -r apps/server/dist "$out/libexec/t3code/apps/server/"
    cp -r apps/server/node_modules "$out/libexec/t3code/apps/server/"

    if [ -d apps/web/dist ]; then
      cp -r apps/web/dist "$out/libexec/t3code/apps/web/"
    fi

    # Workspace packages referenced by the server at runtime. The server
    # symlinks to these via packages/<name>, so we need to materialize them.
    for pkg in packages/contracts packages/shared packages/tailscale packages/ssh packages/client-runtime packages/effect-acp packages/effect-codex-app-server; do
      if [ -d "$pkg" ]; then
        mkdir -p "$out/libexec/t3code/$pkg"
        [ -d "$pkg/dist" ] && cp -r "$pkg/dist" "$out/libexec/t3code/$pkg/"
        [ -d "$pkg/node_modules" ] && cp -r "$pkg/node_modules" "$out/libexec/t3code/$pkg/"
      fi
    done

    makeWrapper ${nodejs_24}/bin/node "$out/bin/t3code" \
      --add-flags "$out/libexec/t3code/apps/server/dist/bin.mjs" \
      --prefix PATH : ${lib.makeBinPath [ nodejs_24 ]} \
      --set NODE_PATH "$out/libexec/t3code/apps/server/node_modules"

    # Apply the OPENCODE_CONFIG_CONTENT patch (same fix as in
    # home-manager/modules/t3code.nix for pkgs.t3code 0.0.24). The
    # upstream server unconditionally sets OPENCODE_CONFIG_CONTENT="{}"
    # on the opencode subprocess, which hides every provider/model.
    # We patch it to respect an inherited env var if set.
    target="$out/libexec/t3code/apps/server/dist/bin.mjs"
    if [ -f "$target" ]; then
      echo "t3code-fork: applying OPENCODE_CONFIG_CONTENT patch"
      ${python3}/bin/python3 - "$target" <<'PYEOF'
import re, sys
path = sys.argv[1]
src = open(path).read()
pat = re.compile(
    r"env:\s*\{\s*\.\.\.input\.environment\s*,?\s*\n\s*OPENCODE_CONFIG_CONTENT:\s*OPENCODE_EMPTY_CONFIG_CONTENT\s*,?\s*\n\s*\}",
    re.MULTILINE,
)
repl = (
    "env: {\n"
    "    ...input.environment,\n"
    "    ...(process.env.OPENCODE_CONFIG_CONTENT ? {} : { OPENCODE_CONFIG_CONTENT: OPENCODE_EMPTY_CONFIG_CONTENT })\n"
    "  }"
)
new_src, n = pat.subn(repl, src)
if n == 0:
    print("t3code-fork: pattern not found (upstream source may have changed)")
else:
    if n > 1:
        print("t3code-fork: WARNING — replaced", n, "occurrences (expected 1)")
    open(path, "w").write(new_src)
    print("t3code-fork: patched", n, "occurrence")
PYEOF
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "t3code headless server (fork at v0.0.28)";
    longDescription = ''
      Server-only build of t3code. The full release ships an Electron
      desktop app; this derivation skips the desktop wrapper and ships
      only the Node.js server (`t3code` CLI) and the bundled web
      frontend, suitable for systemd service deployment.

      See home-manager/modules/t3code.nix in this flake for a drop-in
      systemd unit, pairing-token provisioning, and the
      OPENCODE_CONFIG_CONTENT patch (also applicable here).
    '';
    homepage = "https://github.com/pingdotgg/t3code";
    license = licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "t3code";
  };
})