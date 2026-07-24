# paseo — self-hosted orchestration platform for coding agents (https://paseo.sh).
#
# paseo is NOT in nixpkgs. It ships as the proprietary, pre-built npm package
# `@getpaseo/cli` (bin: `paseo`), which bundles the daemon + web UI + CLI. We
# package it with buildNpmPackage from a tiny wrapper project whose only
# dependency is that CLI, pinned via the vendored package-lock.json here.
#
# The published package pulls in `node-pty` (a native module), so the build
# compiles it against this nixpkgs nodejs — hence node-gyp/python in the build.
#
# ── Updating to a new paseo version ──────────────────────────────────────────
#   1. Bump `version` below.
#   2. Regenerate the lockfile (from this directory):
#        npm install --package-lock-only
#      after setting the same version in package.json's dependency.
#   3. Set `npmDepsHash` to lib.fakeHash, run `nix build`, copy the real hash
#      from the error into `npmDepsHash`.
# ─────────────────────────────────────────────────────────────────────────────
{
  lib,
  buildNpmPackage,
  fetchNpmDeps,
  nodejs,
  python3,
  makeWrapper,
}:

buildNpmPackage rec {
  pname = "paseo";
  version = "0.1.110";

  # The wrapper project (package.json + package-lock.json) lives alongside this
  # file. It has no source of its own — `npm ci` just materialises the CLI and
  # its dependency tree into node_modules.
  src = lib.cleanSource ./.;

  # Hash of the fetched npm dependency tarballs (fetchNpmDeps of the lockfile).
  # See the "Updating" note above to regenerate.
  npmDepsHash = "sha256-KFeA5J88hm1vCAjxoQRRXe1pJCO9bD33zieg/BuKy3w=";

  # Our wrapper has no build step; `npm ci` + native rebuild of node-pty is all
  # we need. Skip the (nonexistent) `npm run build`.
  dontNpmBuild = true;

  # node-pty compiles via node-gyp, which needs python at build time.
  nativeBuildInputs = [ python3 makeWrapper ];

  inherit nodejs;

  # buildNpmPackage's default install copies the whole project (including the
  # populated node_modules) to $out/lib/node_modules/<pname>. It only links
  # bins declared in OUR package.json (there are none), so expose the CLI's
  # `paseo` bin ourselves. We invoke node on the CLI's own bin entrypoint,
  # preserving the DEP0040 warning suppression it ships with.
  postInstall = ''
    pkgdir="$out/lib/node_modules/paseo-cli-wrapper/node_modules/@getpaseo/cli"
    if [ ! -f "$pkgdir/bin/paseo" ]; then
      echo "paseo: expected CLI entrypoint at $pkgdir/bin/paseo, not found" >&2
      exit 1
    fi
    makeWrapper ${nodejs}/bin/node $out/bin/paseo \
      --add-flags "--disable-warning=DEP0040" \
      --add-flags "$pkgdir/bin/paseo"
  '';

  # Smoke-test that the bin actually starts.
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/paseo --version >/dev/null
  '';

  meta = {
    description = "Self-hosted orchestration platform for coding agents (daemon + web UI + CLI)";
    homepage = "https://paseo.sh";
    downloadPage = "https://github.com/getpaseo/paseo";
    license = lib.licenses.unfree;
    mainProgram = "paseo";
    platforms = lib.platforms.unix;
  };
}
