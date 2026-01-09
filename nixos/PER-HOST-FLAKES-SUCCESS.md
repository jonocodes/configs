# Per-Host Flakes - SUCCESS! 🎉

## The Solution

We found a way to have **independent lock files per host** while keeping shared configuration modules!

## How It Works

### The Key Insight

Instead of having subdirectory flakes manage the entire configuration (which breaks path resolution), we split responsibilities:

1. **Subdirectory flake** (e.g., `hosts/plex/flake.nix`) - Manages **inputs only**
2. **Top-level flake** (`flake.nix`) - Imports subdirectory flake, uses its inputs, but handles **configuration assembly**

This avoids the path resolution issues because the top-level flake (at repo root) can access `./hosts/plex/default.nix` and `./modules/` with relative paths.

### Structure

```
nixos/
├── flake.nix                    # Top-level aggregator
├── flake.lock                   # Lock for non-plex hosts
├── hosts/
│   ├── plex/
│   │   ├── flake.nix           # Plex inputs only
│   │   ├── flake.lock          # Independent plex lock! ✅
│   │   ├── default.nix         # Plex config (unchanged)
│   │   └── router.nix
│   ├── dobro/
│   │   └── default.nix         # Uses main flake.lock
│   └── zeeba/
│       └── default.nix         # Uses main flake.lock
└── modules/
    └── common-nixos.nix        # Shared by all hosts
```

### Code Example

**`hosts/plex/flake.nix`** (minimal, just inputs):
```nix
{
  description = "Plex host inputs (independent lock file)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = inputs: {
    # Just expose the inputs for the parent flake to use
    inherit inputs;
  };
}
```

**Top-level `flake.nix`** (imports plex flake, builds config):
```nix
{
  inputs = {
    # Standard inputs for non-plex hosts
    nixpkgs.url = "nixpkgs/nixos-25.11";
    # ... other inputs ...

    # Per-host flake
    plex-flake.url = "path:./hosts/plex";
  };

  outputs = { self, nixpkgs, plex-flake, ... }@inputs: {
    nixosConfigurations = {
      # Standard hosts use main flake inputs
      dobro = mkHost "dobro" "x86_64-linux";
      
      # Plex uses its own flake's inputs
      plex = mkHostWithFlake "plex" "x86_64-linux" plex-flake;
    };
  };
}
```

The `mkHostWithFlake` function:
1. Takes the plex-flake as input
2. Extracts its inputs (nixpkgs, disko, etc.)
3. Builds the nixosSystem using those inputs
4. Still calls `./hosts/plex` for configuration (path resolution works!)

## Benefits

✅ **Independent lock files** - Plex has `hosts/plex/flake.lock`
✅ **Shared modules work** - Top-level flake handles config assembly
✅ **No absolute paths** - Everything is portable
✅ **Simple to understand** - Clear separation of concerns
✅ **No path resolution issues** - Top-level flake is at repo root

## Usage

### Deploy Plex (uses its own lock)
```bash
cd ~/sync/configs/nixos
sudo nixos-rebuild switch --flake .#plex
```

### Deploy Other Hosts (use main lock)
```bash
cd ~/sync/configs/nixos
sudo nixos-rebuild switch --flake .#dobro
```

### Update Plex Independently
```bash
cd ~/sync/configs/nixos/hosts/plex
nix flake update                # Updates only plex lock
cd ../..
sudo nixos-rebuild switch --flake .#plex
```

### Update All Other Hosts
```bash
cd ~/sync/configs/nixos
nix flake update                # Updates main lock
sudo nixos-rebuild switch --flake .#dobro
sudo nixos-rebuild switch --flake .#zeeba
# etc.
```

### Check Versions
```bash
# Main flake nixpkgs version
cd ~/sync/configs/nixos
nix flake metadata --json | jq -r '.locks.nodes.nixpkgs.locked.rev'

# Plex flake nixpkgs version
cd ~/sync/configs/nixos/hosts/plex
nix flake metadata --json | jq -r '.locks.nodes.nixpkgs.locked.rev'
```

## Why This Works (Technical Details)

### The Path Resolution Problem (Why Previous Attempts Failed)

When Nix evaluates a flake in a subdirectory:
1. Flake is copied to `/nix/store/xxx-source/`
2. Only files within the flake directory are included
3. Imports like `../../modules/common-nixos.nix` fail (points outside flake)

### Our Solution

1. **Subdirectory flake** only declares inputs, nothing else
2. **Top-level flake** (at repo root):
   - Imports subdirectory flake as an input: `plex-flake.url = "path:./hosts/plex"`
   - Accesses subdirectory flake's inputs: `plex-flake.inputs.nixpkgs`
   - Builds config from top-level using relative paths: `./hosts/plex/default.nix`
   - Can import shared modules: `./modules/common-nixos.nix`

Since the top-level flake is at the repo root, all relative paths work!

## Comparison with Previous Approaches

| Approach | Lock Files | Shared Modules | Portable | Result |
|----------|-----------|----------------|----------|--------|
| Monolithic | Single shared | ✅ Yes | ✅ Yes | ✅ Works |
| Subdirectory flakes | ✅ Independent | ❌ Path errors | ✅ Yes | ❌ Failed |
| Absolute paths | ✅ Independent | ✅ Yes | ❌ No | ❌ Unacceptable |
| **Input-only flakes** | ✅ **Independent** | ✅ **Yes** | ✅ **Yes** | ✅ **SUCCESS!** |

## Adding More Hosts

To give another host its own lock file:

1. Create `hosts/{hostname}/flake.nix` (copy from plex)
2. Run `cd hosts/{hostname} && nix flake update`
3. Update top-level flake:
   ```nix
   inputs = {
     # ...
     othername-flake.url = "path:./hosts/othername";
   };
   
   outputs = { self, othername-flake, ... }@inputs: {
     nixosConfigurations = {
       othername = mkHostWithFlake "othername" "x86_64-linux" othername-flake;
     };
   };
   ```

## Migration Path

You can migrate hosts gradually:
- Hosts without subdirectory flakes use main `flake.lock`
- Hosts with subdirectory flakes use their own lock
- Both types coexist peacefully

## Limitations

- Requires `nix flake update` in subdirectory for per-host updates
- Two commands needed to update everything (main + per-host flakes)
- Slightly more complex than monolithic (but worth it!)

## Credits

This approach was inspired by exploring the limitations documented in `PER-HOST-FLAKES-EXPLORATION.md` and finding a creative workaround by splitting the flake's responsibilities.

**Key realization:** Flakes don't need to do everything. Input management and configuration building can be separate concerns!



