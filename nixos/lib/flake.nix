{
  description = "Shared builder library for per-host NixOS flakes";

  # This flake only needs nixpkgs to provide the lib.nixosSystem function
  # Actual package versions come from each host's inputs
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }: {
    # Export default input URLs - hosts can reference these
    defaultInputs = {
      nixpkgs = "nixpkgs/nixos-25.11";
      nixpkgs-unstable = "nixpkgs/nixos-unstable";
      nix-flatpak = "github:gmodena/nix-flatpak";
      disko = "github:nix-community/disko";
      nixos-hardware = "github:NixOS/nixos-hardware";
    };
    
    # Default system architecture (most hosts are x86_64-linux)
    defaultSystem = "x86_64-linux";

    # Export the shared builder function for per-host flakes
    lib.mkHost = { inputs, hostName, system ? "x86_64-linux", configPath, sharedModulesPath ? null }:
      let
        # Extract the inputs we need from the host's inputs
        inherit (inputs) nixpkgs nixpkgs-unstable;
      in {
        nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs sharedModulesPath;
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          };
          modules = [ configPath ];
        };
      };
  };
}

