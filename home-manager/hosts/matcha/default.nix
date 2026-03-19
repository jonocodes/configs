{ pkgs, pkgs-unstable, inputs, config, modulesPath, ... }:
let
  inherit (inputs) self;

in {

  # services.happy-coder-daemon = {
  #   enable = true;

  #   environment = {
  #     HAPPY_SERVER_URL = "https://happy-server.wolf-typhon.ts.net";
  #     # HAPPY_LOG_LEVEL = "info";
  #   };
  # };

  imports = [
    ../../modules/common.nix
    # ../../modules/happy/happy-coder-daemon.nix
  ];

}
