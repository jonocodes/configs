{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

in {

  # services.headscale = {
  #   enable = true;

  # };

  imports = [
    ../modules/common.nix
  ];

}
