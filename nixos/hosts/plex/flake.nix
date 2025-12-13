# Per-host flake for independent package management
# Inputs will be provided by parent flake using inputs.follows
{
  inputs = {
    # These will be overridden by parent flake using inputs.follows
    # Defaults here are just fallbacks if flake is used standalone
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    disko.url = "github:nix-community/disko";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    parent.url = "path:../../lib";
    # Note: When used via new/flake.nix, this will be overridden by inputs.follows
  };

  outputs = { parent, ... }@inputs: 
    parent.lib.mkHost {
      inherit inputs;
      hostName = "plex";
      configPath = ./default.nix;
      sharedModulesPath = /home/jono/sync/configs/nixos/modules;
      # system = parent.defaultSystem;  # x86_64-linux, can override for ARM
    };
}

