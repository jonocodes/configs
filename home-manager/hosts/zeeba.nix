{ config, pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

  coolify-cli = pkgs.callPackage ../packages/coolify-cli {};

in {

  home.packages = with pkgs-unstable;
    [
      # cloudflared # tried to get cloudflare tunnel working, but no success
      # atuin
      # helix
      # devenv
      # docker-network-coolify
      docker-compose  # installed this because 'docker compose' is not working?

    ] ++ (with pkgs; [

      lzop # for syncoid compression
      mbuffer

      # ccusage from llm-agents (now uses Node.js - no AVX2 requirement)
      inputs.llm-agents.packages.${pkgs.system}.ccusage

    ]);

  # Happy Coder daemon - runs as user service
  # Server config: runs 24/7 for remote Claude Code sessions
  services.happy-coder-daemon = {
    enable = true;

    extraArgs = [
      "--yolo"
    ];

    environment = {
      HAPPY_SERVER_URL = "https://happy-server.wolf-typhon.ts.net";
      # HAPPY_LOG_LEVEL = "info";
    };
  };

  imports = [
    ../modules/common.nix
    ../modules/happy/happy-coder-daemon.nix
  ];

}
