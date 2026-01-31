{
  description = "Jono's NixOS configurations";

  inputs = {

    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    # TODO: replace this with the offical flatpak service once merged
    #   https://github.com/NixOS/nixpkgs/pull/347605

    nix-flatpak.url =
      "github:gmodena/nix-flatpak"; # unstable branch. Use github:gmodena/nix-flatpak/?ref=<tag> to pin releases.

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # pinning this because it constantly rebuilds the kernel. remove the rev if I want to update. then copy it from flake.lock
    # nixos-hardware.url = "github:NixOS/nixos-hardware/497ae1357f1ac97f1aea31a4cb74ad0d534ef41f";

    # I uncommented the rev here on 7/13/25 and there was no rebuild ??
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Infrastructure diagram generation
    nix-topology.url = "github:oddlama/nix-topology";

    # Per-host flakes (for independent lock files)
    plex-flake.url = "path:./hosts/plex";
    zeeba-flake.url = "path:./hosts/zeeba";
    lute-flake.url = "path:./hosts/lute";
    ocarina-flake.url = "path:./hosts/ocarina";
    imbp-flake.url = "path:./hosts/imbp";
  };

  nixConfig = {
    # Bypass Git dirty checks
    bash-prompt = "";  # Disable purity checks for flakes
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nix-flatpak, disko
    , nixos-hardware, nix-topology, plex-flake, zeeba-flake, lute-flake, ocarina-flake, imbp-flake }@inputs:
    let

      # Standard host builder (for hosts without per-host flakes)
      mkHost = hostName: system:
        nixpkgs.lib.nixosSystem {

          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ nix-topology.overlays.default ];
          };

          specialArgs = {
            inherit inputs;

            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };

          };

          modules = [

            ./hosts/${hostName}

            disko.nixosModules.disko
            nix-topology.nixosModules.default

          ];
        };

      # Per-host flake builder (uses inputs from the host's own flake)
      mkHostWithFlake = hostName: system: hostFlake:
        let
          # Use the host's own inputs from its flake
          hostInputs = hostFlake.inputs;

          # Conditionally include modules based on available inputs
          optionalModules =
            (if hostInputs ? disko then [ hostInputs.disko.nixosModules.disko ] else []);
        in
        hostInputs.nixpkgs.lib.nixosSystem {

          pkgs = import hostInputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
            # Use main flake's nix-topology overlay for consistent topology support
            overlays = [ nix-topology.overlays.default ];
          };

          specialArgs = {
            inputs = hostInputs;

            pkgs-unstable = import hostInputs.nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };

          };

          modules = [

            ./hosts/${hostName}

            # Include nix-topology from main flake for topology diagram support
            nix-topology.nixosModules.default

          ] ++ optionalModules;
        };

    in {
      nixosConfigurations = {
        dobro = mkHost "dobro" "x86_64-linux";

        # Hosts with independent flakes
        zeeba = mkHostWithFlake "zeeba" "x86_64-linux" zeeba-flake;
        plex = mkHostWithFlake "plex" "x86_64-linux" plex-flake;
        lute = mkHostWithFlake "lute" "x86_64-linux" lute-flake;
        ocarina = mkHostWithFlake "ocarina" "x86_64-linux" ocarina-flake;
        imbp = mkHostWithFlake "imbp" "x86_64-linux" imbp-flake;

        # Hosts managed directly from main flake
        orc = mkHost "orc" "aarch64-linux";
        nixahi = mkHost "nixahi" "aarch64-linux";
        matcha = mkHost "matcha" "x86_64-linux";
        # x200 = mkHost "x200" "x86_64-linux";
        # t430 = mkHost "t430" "x86_64-linux";
      };

      # Infrastructure topology diagrams
      # Build with: nix build .#topology.x86_64-linux.config.output
      # Output SVGs will be in ./result/
      topology.x86_64-linux = import nix-topology {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [ nix-topology.overlays.default ];
        };
        modules = [
          ./topology.nix
          { inherit (self) nixosConfigurations; }
        ];
      };

    };
}
