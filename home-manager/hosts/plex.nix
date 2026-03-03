{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

in {

  home.packages = with pkgs-unstable;
    [
    ] ++ (with pkgs; [

      # lzop # for syncoid compression
      mbuffer
    ]);

  imports = [ 
    ../modules/common.nix
  ];

}
