
# to build all these packages > nix-build

{
  pkgs ? import <nixpkgs> {},
}: let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-24.05";
  inherit (pkgs) callPackage python3Packages;
in {
  windsurf = callPackage ./windsurf.nix {inherit nixpkgs;};

}
