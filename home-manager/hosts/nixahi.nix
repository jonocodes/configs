{ pkgs, pkgs-unstable, inputs, nix-flatpak, home-manager-master, ... }:
let

  syncRoot = "/home/jono/syncHome";

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


  # home.stateVersion = "25.05";

  home.packages = with pkgs-unstable;
    [
      # trayscale # looks featurefull does not seem to work in kde
      # tailscale-systray # lists connected nodes, but has no toggles
      # KTailctl flatpak works best in KDK
      # in gnome probably us the extension

      firefoxpwa

      bruno # since the ARM version is not in flathub

      obsidian # since it turns black in flathub

      telegram-desktop # flatpak version crashes

    ] ++ (with pkgs;
      [

        # TODO: waiting on https://github.com/flox/flox/issues/2811
        # inputs.flox.packages.${pkgs.system}.default

      ]);

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
