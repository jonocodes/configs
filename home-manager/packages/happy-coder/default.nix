{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
, makeWrapper
}:

buildNpmPackage rec {
  pname = "happy-coder";
  version = "0.13.0";

  src = fetchFromGitHub {
    owner = "slopus";
    repo = "happy-cli";
    rev = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    # To get the correct hash:
    # 1. Set hash to lib.fakeSha256 or all A's
    # 2. Run: nix build .#happy-coder
    # 3. Copy the expected hash from the error message
    # 4. Replace the hash above
  };

  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  # To get the correct npmDepsHash:
  # 1. Set to lib.fakeHash or all A's
  # 2. Run: nix build .#happy-coder
  # 3. Copy the expected hash from the error message
  # 4. Replace the hash above
  #
  # Alternative method using prefetch-npm-deps:
  # 1. Clone the repo
  # 2. Run: nix-shell -p prefetch-npm-deps
  # 3. Run: prefetch-npm-deps package-lock.json
  # 4. Use the output hash

  nativeBuildInputs = [ makeWrapper ];

  # Don't run npm build script (package is pre-built)
  dontNpmBuild = true;

  # The package provides these binaries
  # From package.json: "bin": { "happy": "bin/happy.mjs", "happy-mcp": "bin/happy-mcp.mjs" }

  # Ensure the binaries have the correct Node.js shebang
  postPatch = ''
    # Check if binaries need patching
    for bin in bin/*.mjs; do
      if [ -f "$bin" ]; then
        # Add Node.js shebang if missing
        if ! head -1 "$bin" | grep -q '^#!'; then
          sed -i '1i#!/usr/bin/env node' "$bin"
        fi
      fi
    done
  '';

  # Make sure binaries can find node_modules
  postInstall = ''
    # Wrap binaries to ensure they can find dependencies
    for bin in $out/bin/*; do
      if [ -f "$bin" ]; then
        wrapProgram "$bin" \
          --prefix NODE_PATH : "$out/lib/node_modules/${pname}/node_modules"
      fi
    done
  '';

  meta = with lib; {
    description = "Mobile and Web client CLI for Claude Code and Codex";
    longDescription = ''
      Happy Coder is a free, open-source CLI tool that enables mobile control
      for Claude Code. It provides end-to-end encrypted communication and allows
      you to control Claude AI from your phone, receive push notifications,
      and seamlessly switch between devices.
    '';
    homepage = "https://github.com/slopus/happy-cli";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
    mainProgram = "happy";
  };
}
