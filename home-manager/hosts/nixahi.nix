{ pkgs, pkgs-unstable, inputs, nix-flatpak, home-manager-master, hostVars, ... }:
let

  # nixahi uses a non-standard sync location
  syncRoot = "${hostVars.homeDirectory}/syncHome";

  coolify-cli = pkgs.callPackage ../packages/coolify-cli {};

  # pkgs-playwright-1541 = import inputs.nixpkgs-playwright-1541 {  # moved to flox
  #   system = pkgs.system;
  # };

  # node wrapper with playwright available via NODE_PATH and browsers pre-configured
  playwright-node = pkgs-unstable.writeShellScriptBin "playwright-node" ''
    export PLAYWRIGHT_BROWSERS_PATH="${pkgs-unstable.playwright-driver.browsers}"
    export NODE_PATH="${pkgs-unstable.playwright-test}/lib/node_modules''${NODE_PATH:+:$NODE_PATH}"
    exec ${pkgs-unstable.nodejs}/bin/node "$@"
  '';

in {

  # Not yet working
  services.syncthing = {

      # TODO: passwordFile
      # but how is this different than guiPasswordFile? https://github.com/NixOS/nixpkgs/pull/290485#pullrequestreview-2701652766

      # TODO: set cert and key to get a static ID
      # key = "${</path/to/key.pem>}";

      enable = false;  # TODO: enable once 'devices' works. waiting on 25.05 to get more stable

      # tray.enable = true;  # dont think this works

      #  guiAddress = "0.0.0.0:8888";  # Custom port 8888

      extraOptions = [
        "-data=${syncRoot}"
        "-config=${syncRoot}/.config/syncthing"
      ];

      settings = {

        gui = {
          tls = false;
          theme = "default";
        };
        options = {
          listenAddresses = [ "tcp://0.0.0.0:22001" "quic://0.0.0.0:22001" ];
        };

        devicesXXX = {  # NOT WORKING. this should break
          "choco" = {
            id = "ITAESBW-TIKWVEX-ITJPOWT-PM7LSDA-O23Q2FO-6L5VSY2-3UW5VM6-I6YQAAR";
          };

          zeeba.id = "FHJMBVS-QFCCTVG-XQCQTCB-RTX6I37-B76EXZ7-Y7VSFBZ-YT5QWFK-4XQVGAH";
        };

        folders = {
          "more" = {
            path = "${syncRoot}/more";
            devices = [ "choco" ];
          };
        };
      };
    };

  home.packages = with pkgs-unstable;
    [

      # lazydocker

      # lazygit

      # trayscale # looks featurefull does not seem to work in kde
      # tailscale-systray # lists connected nodes, but has no toggles
      # KTailctl flatpak works best in KDK
      # in gnome probably us the extension

      # firefoxpwa

      bruno # since the ARM version is not in flathub

      obsidian # since it turns black in flathub

      telegram-desktop # flatpak version crashes

      # jetbrains.pycharm-professional


      uv # since the flox version is not working

      ticktick  # TODO: enable once my master change merges to unstable

      vim

      # for AI
      # gh
      # opencode
      # claude-code

      code-cursor
      
      nodejs
      playwright-mcp
      playwright-test
      playwright-node

      coolify-cli

    ] ++ (with pkgs;
      [
        inputs.flox.packages.${pkgs.system}.default
      ]);

  programs.fish.shellInit = ''
    set -gx PLAYWRIGHT_BROWSERS_PATH "${pkgs-unstable.playwright-driver.browsers}"
    # set -gx PLAYWRIGHT_BROWSERS_PATH_1541 "..."  # moved to flox
  '';

  imports = [

    inputs.nix-flatpak.homeManagerModules.nix-flatpak

    ../modules/common.nix
    ../modules/linux-desktop.nix
    ../modules/email.nix

        # (home-manager-master + "/modules/services/syncthing.nix")

  ];



  # TODO: try from https://unmovedcentre.com/posts/managing-nix-config-host-variables/

  # imports = lib.flatten [

  #   inputs.nix-flatpak.homeManagerModules.nix-flatpak

  #   # inputs.sops-nix.${platformModules}.sops

  #   (map lib.custom.relativeToRoot [

  #     modules/common.nix
  #     modules/linux-desktop.nix
  #     modules/email.nix

  #   ])
  # ];


}
