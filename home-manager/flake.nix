{
  description = "Jono's top flake for home manager";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    
    nix-flatpak.url = "github:gmodena/nix-flatpak"; # unstable branch. Use github:gmodena/nix-flatpak/?ref=<tag> to pin releases.


    # to run a single package from master:
    #   NIXPKGS_ALLOW_UNFREE=1 nix run github:NixOS/nixpkgs/master#code-cursor --impure

    # android-nixpkgs = {
    #   url = "github:tadfisher/android-nixpkgs";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";

      # url = "github:jonocodes/home-manager/thunderbird-gmail-oauth2";
    };

    # when trying the upstream home syncthing
#     home-manager-master.url = "github:nix-community/home-manager/master";

    home-manager-master = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  #  flox.url = "github:flox/flox/v1.5.0";
   flox.url = "github:flox/flox/v1.7.2";
    # flox.url = "github:flox/flox/8778414b043705d97898eaee0a427c51da859fb8";
#    flox-master.url = "github:flox/flox/4f0624804eb9fe78c08eb2e5ac941b562c8c8fb0";  # until /v1.3.17 comes out

    # sops-nix.url = "github:Mic92/sops-nix";

    # package index for use with comma
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

  };

  nixConfig = {
    # Bypass Git dirty checks
    bash-prompt = "";  # Disable purity checks for flakes

  	# download-buffer-size = 524288000;

    extra-trusted-public-keys = [ "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=" ];
    extra-substituters = [ "https://cache.flox.dev" ];
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
            else ./hosts/_base.nix)

          nix-index-database.homeModules.nix-index

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
        "jono@dobro" = mkHome "dobro" "x86_64-linux";
        "jono@zeeba" = mkHome "zeeba" "x86_64-linux";
        "jono@orc" = mkHome "orc" "aarch64-linux";
        "jono@imbp" = mkHome "imbp" "x86_64-linux";
        "jono@nixahi" = mkHome "nixahi" "aarch64-linux";
        "jono@matcha" = mkHome "matcha" "x86_64-linux";
      };

    };
}
