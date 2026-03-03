{
  description = "nixahi host inputs (independent lock file)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    # Pin 25.05 for asahi drivers (kernel, mesa) to avoid LLVM/Rust incompatibilities. when I upgraded to driver asahi-20250723, wayland/x11/kde got choppier
    nixpkgs-asahi.url = "nixpkgs/nixos-25.05";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = inputs: {
    # Just expose the inputs for the parent flake to use
    inherit inputs;
  };
}
