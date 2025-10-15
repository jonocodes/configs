{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

in {

  home.packages = with pkgs-unstable;
    [
      cloudflared # tried to get cloudflare tunnel working, but no success
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
