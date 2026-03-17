# TODO: upstream to nixpkgs:
#   - Rename this file to package.nix
#   - Place at pkgs/by-name/co/coolify-cli/package.nix
#   - Fill in maintainers with your nixpkgs maintainer handle
#   - Open PR referencing https://github.com/NixOS/nixpkgs/issues/303482
#   - After merge, remove this file and use pkgs.coolify-cli directly

{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "coolify-cli";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "coollabsio";
    repo = "coolify-cli";
    rev = "v${version}";
    hash = "sha256-i6ikBckrKERWJ8GcgqXQ3/oU0C0TJ40UOC5WOT7zJWs=";
  };

  vendorHash = "sha256-stWvIJJDZifJBelF/5DVapGY10HAnMROJcbadqkqBIA=";

  # entrypoint is in the coolify/ subdirectory, not the repo root
  subPackages = [ "coolify" ];

  env.CGO_ENABLED = 0;

  # flags from upstream .goreleaser.yml
  ldflags = [
    "-s" "-w"
    "-X github.com/coollabsio/coolify-cli/internal/version.version=${version}"
  ];

  meta = with lib; {
    description = "CLI for managing Coolify instances";
    homepage = "https://github.com/coollabsio/coolify-cli";
    changelog = "https://github.com/coollabsio/coolify-cli/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ jonocodes ];
    mainProgram = "coolify";
  };
}
