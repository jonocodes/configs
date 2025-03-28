{
  description = "Jono's NixOS top flake for all systems";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    
    nix-flatpak.url = "github:gmodena/nix-flatpak"; # unstable branch. Use github:gmodena/nix-flatpak/?ref=<tag> to pin releases.

    # android-nixpkgs = {
    #   url = "github:tadfisher/android-nixpkgs";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flox.url = "github:flox/flox/v1.3.16";

    sops-nix.url = "github:Mic92/sops-nix";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs"; # Important:  Disko should use the same nixpkgs version

    nixos-hardware.url = "github:NixOS/nixos-hardware";

  };

  nixConfig = {
    extra-trusted-public-keys = "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=";
    extra-substituters = "https://cache.flox.dev";
  };


  outputs = { self, nixpkgs, nixpkgs-unstable, nix-flatpak, home-manager, flox, sops-nix, disko, nixos-hardware }@inputs:
    let

      localpackages = import ./packages {
        inherit nixpkgs;
        pkgs = nixpkgs.legacyPackages;
      };

      # packages.${system} = import ./packages {
      #   inherit nixpkgs;
      #   pkgs = nixpkgs.legacyPackages.${system};
      # };

      mkHost = hostName: system:
        nixpkgs.lib.nixosSystem {

          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;

            config.permittedInsecurePackages =
              [ "electron-*" ]; # I dont think wildcards actually work

          };

          specialArgs = {


            # By default, the system will only use packages from the
            # stable channel.  You can selectively install packages
            # from the unstable channel.  You can also add more
            # channels to pin package version.
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;

              config.allowUnfree = true;

              config.permittedInsecurePackages =
                [ "electron-19.1.9" "electron-25.9.0" "jitsi-meet-1.0.8043" ];

              # gnome with drm video
              config.chromium.enableWideVine = true;

              config.android_sdk.accept_license = true;

            };

            # make all inputs available in other nix files
            inherit inputs;
            
            # nixos-hardware = inputs.nixos-hardware;
          };

          modules = [

            ./hosts/${hostName}

            sops-nix.nixosModules.sops
            disko.nixosModules.disko

            # android-nixpkgs.nixosModules.android-nixpkgs

            # home-manager
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.users.jono.imports = [
                nix-flatpak.homeManagerModules.nix-flatpak
              ];

            }

          ];
        };
    in {
      nixosConfigurations = {
      	t430 = mkHost "t430" "x86_64-linux";
        x200 = mkHost "x200" "x86_64-linux";
        # dobro = mkHost "dobro" "x86_64-linux";
        # plex = mkHost "plex" "x86_64-linux";
        # zeeba = mkHost "zeeba" "x86_64-linux";
        # orc = mkHost "orc" "aarch64-linux";
        # imbp = mkHost "imbp" "x86_64-linux";
      };

    };
}
