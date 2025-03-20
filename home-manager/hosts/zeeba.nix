{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

in {

  home.packages = with pkgs-unstable;
    [
      # atuin
      # helix
      # devenv
    ] ++ (with pkgs; [

      lzop # for syncoid compression
      mbuffer
    ]);

  imports = [ 
    ../modules/common.nix
  ];

}
