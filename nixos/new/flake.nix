{
  description = "Jono's NixOS configurations (new method - per-host flakes)";

  inputs = {
    # Define default inputs once - host flakes will follow these
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    
    # Import builder library
    # Note: Must use absolute paths since this flake is in a subdirectory
    lib.url = "path:/home/jono/sync/configs/nixos/lib";
    lib.inputs.nixpkgs.follows = "nixpkgs";
    
    # Import per-host flakes
    plex.url = "path:/home/jono/sync/configs/nixos/hosts/plex";
    plex.inputs.nixpkgs.follows = "nixpkgs";
    plex.inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
    plex.inputs.nix-flatpak.follows = "nix-flatpak";
    plex.inputs.disko.follows = "disko";
    plex.inputs.nixos-hardware.follows = "nixos-hardware";
    plex.inputs.parent.follows = "lib";
  };

  nixConfig = {
    bash-prompt = "";
  };

  outputs = { self, plex, ... }@inputs: {
    # Re-export host configurations for easy access
    nixosConfigurations = {
      inherit (plex.nixosConfigurations) plex;
    };
  };
}

