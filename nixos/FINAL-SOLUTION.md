# NixOS Per-Host Flakes

Two flake configurations: old monolithic method and new per-host method.

## Structure

```
nixos/
├── flake.nix              # OLD METHOD: Monolithic (dobro, zeeba, orc, imbp, nixahi, matcha)
├── new/
│   └── flake.nix          # NEW METHOD: Top-level with defaults (plex)
├── lib/
│   └── flake.nix          # Shared builder library
└── hosts/
    └── plex/
        └── flake.nix      # Minimal host flake
```

## How It Works

Uses `inputs.follows` to eliminate duplication - define defaults once in `new/flake.nix`:

### Top-Level (`new/flake.nix`)

```nix
{
  inputs = {
    # Define defaults ONCE
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Import builder
    lib.url = "path:../lib";
    lib.inputs.nixpkgs.follows = "nixpkgs";

    # Import host flake
    plex.url = "path:../hosts/plex";

    # Make plex use parent's inputs via inputs.follows
    plex.inputs.nixpkgs.follows = "nixpkgs";
    plex.inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
    plex.inputs.nix-flatpak.follows = "nix-flatpak";
    plex.inputs.disko.follows = "disko";
    plex.inputs.nixos-hardware.follows = "nixos-hardware";
    plex.inputs.parent.follows = "lib";
  };

  outputs = { plex, ... }: {
    nixosConfigurations.plex = plex.nixosConfigurations.plex;
  };
}
```

### Per-Host (`hosts/plex/flake.nix`)

Only hostname changes:

```nix
{
  inputs = {
    # Fallbacks (overridden by parent's inputs.follows)
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    disko.url = "github:nix-community/disko";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    parent.url = "path:../../lib";
  };

  outputs = { parent, ... }@inputs:
    parent.lib.mkHost {
      inherit inputs;
      hostName = "plex";           # ← ONLY THIS CHANGES!
      configPath = ./default.nix;
      # system = "aarch64-linux";  # ← Add for ARM hosts
    };
}
```

### Builder (`lib/flake.nix`)

```nix
{
  inputs.nixpkgs.url = "nixpkgs/nixos-25.11";

  outputs = { nixpkgs, ... }: {
    defaultInputs = {
      nixpkgs = "nixpkgs/nixos-25.11";
      nixpkgs-unstable = "nixpkgs/nixos-unstable";
      nix-flatpak = "github:gmodena/nix-flatpak";
      disko = "github:nix-community/disko";
      nixos-hardware = "github:NixOS/nixos-hardware";
    };

    defaultSystem = "x86_64-linux";

    lib.mkHost = { inputs, hostName, system ? "x86_64-linux", configPath }: {
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          pkgs-unstable = import inputs.nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules = [ configPath ];
      };
    };
  };
}
```

## Usage

**Deploy:** `nixos-rebuild switch --flake ./new#plex`

**Update defaults:** Edit `new/flake.nix`, then `cd hosts/plex && nix flake update`

**Add host:**

1. Copy `hosts/plex/` to `hosts/newhost/`
2. Change `hostName = "newhost"` in flake
3. Add to `new/flake.nix` inputs with `.follows`

## Migration

- **Old method**: dobro, zeeba, orc, imbp, nixahi, matcha (shared `flake.lock`)
- **New method**: plex (independent `flake.lock`)
