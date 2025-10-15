{
  description = "Jono's ...";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";


    # TODO: replace this with the offical service once merged
    #   https://github.com/NixOS/nixpkgs/pull/347605

    nix-flatpak.url =
      "github:gmodena/nix-flatpak"; # unstable branch. Use github:gmodena/nix-flatpak/?ref=<tag> to pin releases.

    # sops-nix.url = "github:Mic92/sops-nix";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # pinning this because it constantly rebuilds the kernel. remove the rev if I want to update. then copy it from flake.lock
    # nixos-hardware.url = "github:NixOS/nixos-hardware/497ae1357f1ac97f1aea31a4cb74ad0d534ef41f";

    # I uncommented the rev here on 7/13/25 and there was no rebuild ??
    nixos-hardware.url = "github:NixOS/nixos-hardware";

  };

  nixConfig = {
    # Bypass Git dirty checks
    bash-prompt = "";  # Disable purity checks for flakes

    # dont know if this does anything
    # extra-trusted-public-keys = [ "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=" ];
    # extra-substituters = [ "https://cache.flox.dev" ];  
  
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nix-flatpak, disko
    , nixos-hardware }@inputs:
    let

      mkHost = hostName: system:
        nixpkgs.lib.nixosSystem {

          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ # TODO: remove this once the issue is fixed https://github.com/nixos/nixpkgs/issues/438765
              (_: prev: {
                tailscale = prev.tailscale.overrideAttrs (old: {
                  checkFlags =
                    builtins.map (
                      flag:
                        if prev.lib.hasPrefix "-skip=" flag
                        then flag + "|^TestGetList$|^TestIgnoreLocallyBoundPorts$|^TestPoller$"
                        else flag
                    )
                    old.checkFlags;
                });
              })
            ];
          };

          specialArgs = {
            inherit inputs;

            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;

              # gnome with drm video
              # config.chromium.enableWideVine = true;

              # config.android_sdk.accept_license = true;

            };

          };

          modules = [

            ./hosts/${hostName}

            #             sops-nix.nixosModules.sops
            disko.nixosModules.disko

          ];
        };
    in {
      nixosConfigurations = {
        dobro = mkHost "dobro" "x86_64-linux";
        zeeba = mkHost "zeeba" "x86_64-linux";
        # x200 = mkHost "x200" "x86_64-linux";
        # plex = mkHost "plex" "x86_64-linux";
        # t430 = mkHost "t430" "x86_64-linux";
        orc = mkHost "orc" "aarch64-linux";
        imbp = mkHost "imbp" "x86_64-linux";
        nixahi = mkHost "nixahi" "aarch64-linux";
      };

    };
}
