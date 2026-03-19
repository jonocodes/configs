

# Happy Coder Package - Integration Guide

Complete guide for integrating the proper Nix package into your setup.

## Overview

You have two options for using happy-coder:

1. **Current (Wrapper)**: Uses system-installed `happy` via npm
2. **Proper Package (This Guide)**: Fully Nix-managed package

## Migration Path

### Phase 1: Current State ✅
- Module uses wrapper for system-installed happy
- Works with `npm install -g happy-coder`
- Already deployed on zeeba

### Phase 2: Build the Package (This Guide)
- Create proper Nix package
- Test it builds and works
- Keep using wrapper in production

### Phase 3: Switch to Package
- Update module to use proper package
- Redeploy to hosts
- Remove npm dependency

## Building the Package

### Step 1: Get the Hashes

Use the interactive helper script:

```bash
cd /home/jono/sync/configs/home-manager/packages/happy-coder
./build-helper.sh
# Choose option 1: Get hashes for current version
```

Or manually:

```bash
# Try to build (will fail with expected hashes)
cd /home/jono/sync/configs/home-manager
nix build .#happy-coder

# The error will show:
# - specified: sha256-AAAA... (your fake hash)
# - got: sha256-XXXX... (the real hash)

# Copy the "got" hashes to default.nix
```

### Step 2: Update default.nix

Edit `packages/happy-coder/default.nix`:

```nix
src = fetchFromGitHub {
  owner = "slopus";
  repo = "happy-cli";
  rev = "v${version}";
  hash = "sha256-REAL_SOURCE_HASH_HERE=";  # Replace
};

npmDepsHash = "sha256-REAL_NPM_DEPS_HASH_HERE=";  # Replace
```

### Step 3: Build and Test

```bash
# Build the package
cd /home/jono/sync/configs/home-manager
nix build .#happy-coder

# Test the binary
./result/bin/happy --help
./result/bin/happy daemon status

# Test in a shell
nix shell .#happy-coder
happy --help
```

### Step 4: Verify Package Structure

```bash
# Check what got installed
ls -la ./result/bin/
ls -la ./result/lib/node_modules/happy-coder/

# Test the binaries
./result/bin/happy --version
./result/bin/happy-mcp --help
```

## Integration Options

### Option A: Direct Override (Quick Test)

Test the package in one host without changing the module:

```nix
# In home-manager/hosts/zeeba.nix
{ pkgs, ... }:

{
  services.happy-coder-daemon = {
    enable = true;
    # Override package to use the proper one
    package = pkgs.callPackage ../../packages/happy-coder { };
  };
}
```

### Option B: Update Module Default (Recommended)

Update the module to use the proper package by default:

```nix
# In modules/happy-coder-daemon.nix

let
  # Use the proper package
  happy-coder-pkg = pkgs.callPackage ../packages/happy-coder { };

  cfg = config.services.happy-coder-daemon;
in {
  options.services.happy-coder-daemon = {
    package = mkOption {
      type = types.package;
      default = happy-coder-pkg;  # Changed from happy-wrapper
      # ...
    };
  };
}
```

### Option C: Via Overlay (Most Flexible)

Add to home-manager flake:

```nix
# In home-manager/flake.nix
{
  outputs = { self, nixpkgs, home-manager, ... }: {

    # Define overlay
    overlays.default = final: prev: {
      happy-coder = final.callPackage ./packages/happy-coder { };
    };

    homeConfigurations = {
      zeeba = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [ self.overlays.default ];
        };
        modules = [ ./hosts/zeeba.nix ];
      };
    };
  };
}
```

Then use in module:

```nix
let
  cfg = config.services.happy-coder-daemon;
in {
  options.services.happy-coder-daemon = {
    package = mkOption {
      default = pkgs.happy-coder;  # From overlay
      # ...
    };
  };
}
```

## Testing the Integration

### Test 1: Package Builds

```bash
cd /home/jono/sync/configs/home-manager
nix build .#happy-coder
./result/bin/happy --help
```

### Test 2: Module Uses Package

```bash
# Update your config to use the package
# Then build home-manager
home-manager build --flake .#zeeba

# Check what package it would install
ls -la ./result/home-path/bin/happy

# Actually deploy
home-manager switch --flake .#zeeba
```

### Test 3: Service Works

```bash
# After deploying
ssh zeeba

# Check service
systemctl --user status happy-coder-daemon

# Check CLI
which happy
happy --version
happy daemon status
```

### Test 4: Same Version

```bash
# Verify CLI and daemon use same package
which happy
readlink -f $(which happy)

# Should point to /nix/store/.../happy-coder-0.13.0/bin/happy
```

## Updating the Package

When a new version is released:

```bash
cd /home/jono/sync/configs/home-manager/packages/happy-coder

# Option 1: Use helper script
./build-helper.sh
# Choose option 2: Update to new version

# Option 2: Manual
# 1. Update version in default.nix
vim default.nix  # Change version = "0.13.0" to "0.14.0"

# 2. Get new hashes
./build-helper.sh  # Option 1
# Or: nix build ../../#happy-coder

# 3. Update hashes in default.nix
vim default.nix

# 4. Test build
nix build ../../#happy-coder

# 5. Deploy
home-manager switch --flake ../../#zeeba
```

## Rollback Plan

If the package doesn't work, you can easily roll back:

### Quick Rollback: Use Wrapper

```nix
# In your host config
services.happy-coder-daemon = {
  enable = true;
  # Override to use wrapper instead
  package = pkgs.writeShellScriptBin "happy" ''
    exec happy "$@"  # Uses system happy
  '';
};
```

### Full Rollback: Home Manager Generations

```bash
# List generations
home-manager generations

# Rollback
home-manager switch --switch-generation <number>
```

## Comparison: Wrapper vs Package

| Aspect | Wrapper (Current) | Package (Proper) |
|--------|-------------------|------------------|
| Installation | npm install | Nix build |
| Reproducible | No | Yes |
| Cached | No | Yes (Nix cache) |
| Version control | No | Yes (in flake.lock) |
| Declarative | Partial | Fully |
| CLI & daemon same | Yes | Yes |
| Works now | ✅ | ⚠️ (needs hashes) |

## Current Status

```
┌─────────────────────────────────────────────────────────────┐
│  Package Status                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ✅ Package derivation created                             │
│  ✅ Helper script created                                  │
│  ✅ Documentation complete                                 │
│  ⚠️  Hashes need to be filled in                           │
│  ⬜ Package not yet built                                  │
│  ⬜ Integration not tested                                 │
│  ⬜ Module not updated to use package                      │
│                                                             │
│  Current: Using wrapper (works with npm install)           │
│  Next: Fill in hashes and build package                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Next Steps

1. **Get the hashes** (required before anything else):
   ```bash
   cd ~/sync/configs/home-manager/packages/happy-coder
   ./build-helper.sh  # Option 1
   ```

2. **Update default.nix** with real hashes

3. **Test build**:
   ```bash
   cd ~/sync/configs/home-manager
   nix build .#happy-coder
   ./result/bin/happy --help
   ```

4. **Test in one host** (Option A above)

5. **Update module** to use package by default (Option B above)

6. **Deploy** to all hosts

## Files

```
home-manager/
├── packages/
│   └── happy-coder/
│       ├── default.nix           # Package derivation
│       ├── README.md             # Package docs
│       ├── build-helper.sh       # Helper script
│       └── INTEGRATION-GUIDE.md  # This file
│
├── modules/
│   ├── happy-coder-daemon.nix    # Current (uses wrapper)
│   └── happy-coder-daemon-v2.nix # Future (with package option)
│
└── hosts/
    └── zeeba.nix                 # Uses the module
```

## Advantages of Proper Package

✅ **Fully declarative** - Version in flake.lock
✅ **Reproducible** - Same build everywhere
✅ **Cached** - Nix binary cache
✅ **No npm needed** - Pure Nix
✅ **Garbage collected** - Automatic cleanup
✅ **Multiple versions** - Can coexist
✅ **Better security** - Nix verifies hashes
✅ **Rollback** - Easy with generations

## See Also

- [packages/happy-coder/README.md](./README.md) - Package documentation
- [../../modules/happy-coder-daemon.nix](../../modules/happy-coder-daemon.nix) - Current module
- [../../modules/HAPPY-CODER-SETUP.md](../../modules/HAPPY-CODER-SETUP.md) - Module setup guide
- [Nixpkgs JavaScript Docs](https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/javascript.section.md)
