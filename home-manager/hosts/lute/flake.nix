{
  description = "Lute host inputs (independent lock file)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-master = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    flox.url = "github:flox/flox/v1.10.0";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = { self, ... }@inputs: {
    inherit inputs;

    # Overlay that replaces pkgs.t3code (currently 0.0.24, an Electron
    # desktop wrapper) with our local fork at v0.0.28 (server-only,
    # suitable for headless systemd deployment).
    #
    # See /home/jono/sync/configs/nixos/packages/t3code-fork.nix and
    # /home/jono/sync/configs/nixos/packages/t3code-fork.HANDOFF.md for
    # derivation history and maintenance notes.
    overlays.default = final: prev: {
      t3code = import
        ../../packages/t3code-fork.nix
        final;
    };
  };
}
