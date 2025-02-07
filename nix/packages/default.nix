
# to build all these packages just run in this dir > nix-build

{
  pkgs ? import <nixpkgs> {},
}: let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-24.11";
  inherit (pkgs) callPackage python3Packages;
in {
  windsurf = callPackage ./windsurf.nix {inherit nixpkgs;};
  # ghostty = callPackage ./ghostty;    # never figured out how to run ghostly without pulling and building the shell from github
}
