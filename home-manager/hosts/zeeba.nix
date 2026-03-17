{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

  coolify-cli = pkgs.callPackage ../packages/coolify-cli {};

in {

  home.packages = with pkgs-unstable;
    [
      cloudflared # tried to get cloudflare tunnel working, but no success
      # atuin
      # helix
      # devenv
      # docker-network-coolify
      docker-compose  # installed this because 'docker compose' is not working?
      claude-code

      coolify-cli

    ] ++ (with pkgs; [

      lzop # for syncoid compression
      mbuffer
    ]);

  imports = [ 
    ../modules/common.nix
  ];

}
