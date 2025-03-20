{
  description = "Jono's top flake for home manager";

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

      # url = "github:jonocodes/home-manager/thunderbird-gmail-oauth2";
    };

    # when trying the upstream home syncthing
#     home-manager-master.url = "github:nix-community/home-manager/master";

    home-manager-master = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flox.url = "github:flox/flox/";  # /v1.3.16

    # sops-nix.url = "github:Mic92/sops-nix";

    # package index for use with comma
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nix-flatpak, home-manager, home-manager-master, nix-index-database, flox }@inputs:
    let

      mkHome = hostName: system: home-manager.lib.homeManagerConfiguration {

        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        extraSpecialArgs = {

          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };

          inherit inputs;
        };

        modules = [

          (if builtins.pathExists ./hosts/${hostName}.nix
            then ./hosts/${hostName}.nix
            else ./hosts/base.nix)

          nix-index-database.hmModules.nix-index

          {
            # TODO: this section can be removed when home manager 25.05 is stable
            disabledModules = [ "services/syncthing.nix" ];
            imports = [
              (home-manager-master + "/modules/services/syncthing.nix")
            ];
          }

        ];
      };
    in {
      homeConfigurations = {
        # "jono@dobro" = mkHome "dobro" "x86_64-linux";
        # "jono@zeeba" = mkHome "zeeba" "x86_64-linux";
        "jono@orc" = mkHome "orc" "aarch64-linux";
        "jono@imbp" = mkHome "imbp" "x86_64-linux";
        "jono@nixahi" = mkHome "nixahi" "aarch64-linux";
      };

    };
}
