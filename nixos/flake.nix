{
  description = "Jono's ...";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";


    # TODO: replace this with the offical service once merged
    #   https://github.com/NixOS/nixpkgs/pull/347605

    nix-flatpak.url =
      "github:gmodena/nix-flatpak"; # unstable branch. Use github:gmodena/nix-flatpak/?ref=<tag> to pin releases.

    #     android-nixpkgs = {
    #       url = "github:tadfisher/android-nixpkgs";
    #       inputs.nixpkgs.follows = "nixpkgs";
    #     };

    # TODO: can probably remove this since its in home manager now
    flox.url = "github:flox/flox/v1.3.15";

    # sops-nix.url = "github:Mic92/sops-nix";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # pinning this because it constantly rebuild the kernel. remove the rev if I want to update 
    nixos-hardware.url = "github:NixOS/nixos-hardware/009b764ac98a3602d41fc68072eeec5d24fc0e49";

  };

  nixConfig = {
    # Bypass Git dirty checks
    bash-prompt = "";  # Disable purity checks for flakes

    # dont know if this does anything
    extra-trusted-public-keys = [ "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=" ];
    extra-substituters = [ "https://cache.flox.dev" ];  
  
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nix-flatpak, disko
    , nixos-hardware, flox }@inputs:
    let

      mkHost = hostName: system:
        nixpkgs.lib.nixosSystem {

          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
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
