{ pkgs, pkgs-unstable, inputs, nix-flatpak, ... }:
let

in {

  home.packages = with pkgs-unstable;
    [
      # trayscale # looks featurefull does not seem to work in kde
      # tailscale-systray # lists connected nodes, but has no toggles
      # KTailctl flatpak works best in KDK
      # in gnome probably us the extension

      firefoxpwa

    ] ++ (with pkgs;
      [

      ]);

  imports = [

    inputs.nix-flatpak.homeManagerModules.nix-flatpak

    ../modules/common.nix
    ../modules/linux-desktop.nix
    ../modules/email.nix

    #     (home-manager-master + "/modules/services/syncthing.nix")

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
