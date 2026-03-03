{
  description = "nixahi host inputs (independent lock file)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = inputs: {
    # Just expose the inputs for the parent flake to use
    inherit inputs;
  };
}
