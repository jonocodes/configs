{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

  coolify-cli = pkgs.callPackage ../packages/coolify-cli {};

in {

  home.packages = with pkgs-unstable;
    [
      # coolify-cli
      nodejs
      yarn

    ] ++ (with pkgs;
      [
        # Required for Prisma on NixOS
        openssl
        openssl.dev
        prisma-engines

        # Required for sharp image processing
        vips
        pkg-config
        gcc

        # Build tools (gnumake is in common.nix)
        python3
      ]);

  # Environment variables for Prisma on NixOS
  home.sessionVariables = {
    PRISMA_QUERY_ENGINE_LIBRARY = "${pkgs.prisma-engines}/lib/libquery_engine.node";
    PRISMA_QUERY_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/query-engine";
    PRISMA_SCHEMA_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/schema-engine";
  };

  # services.happy-coder-daemon = {
  #   enable = true;

  #   environment = {
  #     HAPPY_SERVER_URL = "https://happy-server.wolf-typhon.ts.net";
  #     # HAPPY_LOG_LEVEL = "info";
  #   };
  # };

  imports = [
    ../modules/common.nix
    ../modules/happy/happy-coder-daemon.nix
  ];

}
