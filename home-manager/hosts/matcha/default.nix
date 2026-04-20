{ pkgs, pkgs-unstable, inputs, config, modulesPath, openclaw, ... }:
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
    ../../modules/happy/happy-coder-daemon.nix

    openclaw.homeManagerModules.openclaw
  ];

  # programs.openclaw = {
  #   documents = ./documents;

  #   package = openclaw.packages.${pkgs.system}.openclaw-gateway;

  #   bundledPlugins = {
  #     goplaces.enable = false;
  #   };

  #   instances.default = {
  #     enable = true;

  #     systemd = {
  #       enable = true;
  #     };

  #     gatewayPort = 18999;

  #     config = {
  #       gateway = {
  #         mode = "local";
  #         port = 18999;
  #         controlUi.allowedOrigins = [ "*" ];
  #       };

  #       env.vars = {
  #         ZAI_API_KEY = "/home/jono/.secrets/openclaw/ZAI_API_KEY";
  #       };

  #       models.providers.zai = {
  #         baseUrl = "https://api.z.ai/api/coding/paas/v4";
  #         api = "openai-completions";
  #         models = [
  #           { id = "glm-5";          name = "GLM-5"; }
  #           { id = "glm-5-turbo";    name = "GLM-5 Turbo"; }
  #           { id = "glm-4.7";        name = "GLM-4.7"; }
  #           { id = "glm-4.7-flash";  name = "GLM-4.7 Flash"; }
  #           { id = "glm-4.7-flashx"; name = "GLM-4.7 FlashX"; }
  #         ];
  #       };

  #       agents.defaults.model.primary = "zai/glm-4.7";
  #     };
  #   };
  # };

}
