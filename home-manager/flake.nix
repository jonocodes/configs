{
  description = "Jono's top flake";

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

#     home-manager-master.url = "github:nix-community/home-manager/master";

    home-manager-master = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

#     flox.url = "github:flox/flox/v1.3.15";

    # sops-nix.url = "github:Mic92/sops-nix";

  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nix-flatpak, home-manager, home-manager-master }@inputs:
    let


#     TODO: home manager is not sticking. when rebooting I need to home-manager switch to enable it again. i think the nixos config is overriddling it? when I update that, it steamrolls home manager


      mkHome = hostName: system: home-manager.lib.homeManagerConfiguration {

        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;

#             config.permittedInsecurePackages =
#               [ "electron-*" ]; # I dont think wildcards actually work

        };

        extraSpecialArgs = {

          # By default, the system will only use packages from the
          # stable channel.  You can selectively install packages
          # from the unstable channel.  You can also add more
          # channels to pin package version.
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;

            config.allowUnfree = true;

#               config.permittedInsecurePackages =
#                 [ "electron-19.1.9" "electron-25.9.0" "jitsi-meet-1.0.8043" ];
#
#               # gnome with drm video
#               config.chromium.enableWideVine = true;
#
#               config.android_sdk.accept_license = true;

          };

          # make all inputs available in other nix files
          inherit inputs;

        };

        modules = [

          ./hosts/${hostName}

          # android-nixpkgs.nixosModules.android-nixpkgs

          {
            disabledModules = [ "services/syncthing.nix" ];
            imports = [
              (home-manager-master + "/modules/services/syncthing.nix")
            ];
          }


        ];
      };
    in {
      homeConfigurations = {
        # dobro = mkHost "dobro" "x86_64-linux";
        # # x200 = mkHost "x200" "x86_64-linux";
        # plex = mkHost "plex" "x86_64-linux";
        # zeeba = mkHost "zeeba" "x86_64-linux";
      	# t430 = mkHost "t430" "x86_64-linux";
        # orc = mkHost "orc" "aarch64-linux";
        "jono@imbp" = mkHome "imbp" "x86_64-linux";
      };

    };
}
