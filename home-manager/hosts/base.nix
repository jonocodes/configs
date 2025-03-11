{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

in {

  imports = [
    ../modules/common.nix
  ];

}
