{
  description = "Jono's ...";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    nix-flatpak.url =
      "github:gmodena/nix-flatpak"; # unstable branch. Use github:gmodena/nix-flatpak/?ref=<tag> to pin releases.

    #     android-nixpkgs = {
    #       url = "github:tadfisher/android-nixpkgs";
    #       inputs.nixpkgs.follows = "nixpkgs";
    #     };

    flox.url = "github:flox/flox/v1.3.15";

    # sops-nix.url = "github:Mic92/sops-nix";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

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
        # dobro = mkHost "dobro" "x86_64-linux";
        # # x200 = mkHost "x200" "x86_64-linux";
        # plex = mkHost "plex" "x86_64-linux";
        # zeeba = mkHost "zeeba" "x86_64-linux";
        # t430 = mkHost "t430" "x86_64-linux";
        # orc = mkHost "orc" "aarch64-linux";
        imbp = mkHost "imbp" "x86_64-linux";
      };

    };
}
