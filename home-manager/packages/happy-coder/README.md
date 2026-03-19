# Happy Coder - Nix Package

Proper Nix package derivation for happy-coder using `buildNpmPackage`.

## Package Information

- **Package**: happy-coder
- **Version**: 0.13.0
- **Repository**: https://github.com/slopus/happy-cli
- **npm**: https://www.npmjs.com/package/happy-coder
- **Binaries**: `happy`, `happy-mcp`

## Building the Package

### Step 1: Get the Hashes

The package needs two hashes:
1. **Source hash** (`hash`) - Hash of the GitHub source
2. **Dependencies hash** (`npmDepsHash`) - Hash of npm dependencies

#### Method 1: Let Nix Tell You (Easiest)

```bash
# The hashes are currently set to fake values
# Run the build and Nix will tell you the correct hashes

cd /home/jono/sync/configs/home-manager

# Try to build (it will fail with the expected hash)
nix build .#happy-coder

# The error will show two hashes:
# - Expected hash for 'src' (the source code)
# - Expected hash for 'npmDeps' (the dependencies)

# Copy those hashes and update default.nix
```

#### Method 2: Get Source Hash Manually

```bash
# Get the source hash
nix-prefetch-github slopus happy-cli --rev v0.13.0
```

#### Method 3: Get npmDepsHash with prefetch-npm-deps

```bash
# Clone the repo
cd /tmp
git clone https://github.com/slopus/happy-cli.git
cd happy-cli
git checkout v0.13.0

# Use prefetch-npm-deps
nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json"
```

### Step 2: Update the Hashes

Edit `default.nix` and replace the fake hashes:

```nix
src = fetchFromGitHub {
  owner = "slopus";
  repo = "happy-cli";
  rev = "v${version}";
  hash = "sha256-REAL_HASH_HERE=";  # Replace this
};

npmDepsHash = "sha256-REAL_HASH_HERE=";  # Replace this
```

### Step 3: Build the Package

```bash
cd /home/jono/sync/configs/home-manager
nix build .#happy-coder

# Test the built package
./result/bin/happy --help
```

## Integration with Home Manager

### Option 1: Add to home-manager overlay

Create or update `home-manager/flake.nix`:

```nix
{
  outputs = { self, nixpkgs, home-manager, ... }: {

    # Define overlay
    overlays.default = final: prev: {
      happy-coder = final.callPackage ./packages/happy-coder { };
    };

    homeConfigurations.your-host = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlays.default ];
      };
      # ... rest of config
    };
  };
}
```

### Option 2: Add to home-manager packages directly

```nix
# In your home-manager config
{ pkgs, ... }:

let
  happy-coder = pkgs.callPackage ./packages/happy-coder { };
in {
  home.packages = [ happy-coder ];
}
```

### Option 3: Use in the module (Recommended)

Update `modules/happy-coder-daemon.nix`:

```nix
let
  # Define the package
  happy-coder-pkg = pkgs.callPackage ../packages/happy-coder { };

  cfg = config.services.happy-coder-daemon;
in {
  options.services.happy-coder-daemon = {
    package = mkOption {
      type = types.package;
      default = happy-coder-pkg;  # Use the real package
      # ... rest of option
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];  # Adds 'happy' to PATH
    # ... rest of config
  };
}
```

## Testing the Package

### Basic Functionality Test

```bash
# Build the package
nix build .#happy-coder

# Test the binary
./result/bin/happy --help
./result/bin/happy daemon status

# Test in a nix shell
nix shell .#happy-coder
happy --help
```

### Integration Test

```bash
# Add to your home config temporarily
home.packages = [ (pkgs.callPackage ./packages/happy-coder { }) ];

# Rebuild
home-manager switch --flake .#your-host

# Test
which happy
happy --help
happy daemon status
```

## Package Structure

```
packages/happy-coder/
├── default.nix       # The package derivation
└── README.md         # This file
```

## Updating the Package

When a new version is released:

1. Update `version` in `default.nix`
2. Update `rev` to match the new version tag
3. Clear both hashes (set to all A's)
4. Run `nix build .#happy-coder`
5. Copy the new hashes from the error
6. Update `default.nix` with new hashes
7. Test the build

```bash
# Quick update workflow
vim packages/happy-coder/default.nix  # Update version
nix build .#happy-coder               # Get new hashes
vim packages/happy-coder/default.nix  # Update hashes
nix build .#happy-coder               # Verify it builds
```

## Troubleshooting

### Build Fails with "hash mismatch"

This means the hashes are wrong. The error will show:
- **Specified**: The hash you provided
- **Got**: The actual hash

Copy the "Got" hash and update `default.nix`.

### Binary Not Found After Install

Check that the package installed correctly:
```bash
ls -la ~/.nix-profile/bin/happy
```

If missing, check the `postInstall` phase in `default.nix`.

### Import Resolution Issues

If you get "Cannot find module" errors:

1. Check `NODE_PATH` is set correctly in `postInstall`
2. Verify `node_modules` directory structure in the build output
3. May need to adjust the wrapper or add `makeWrapper`

### Permission Denied

Make sure the binaries are executable:
```bash
ls -la ./result/bin/happy
# Should show: -r-xr-xr-x
```

If not, add to `postInstall`:
```nix
postInstall = ''
  chmod +x $out/bin/*
'';
```

## Dependencies

The package has these major dependencies (from package.json):
- `ai` (^5.0.107)
- `axios` (^1.13.2)
- `fastify` (^5.6.2)
- `ink` (^6.5.1)
- `react` (^19.2.0)
- `socket.io-client` (^4.8.1)
- And many more...

All dependencies are handled automatically by `buildNpmPackage`.

## Advantages Over npm install

✅ **Reproducible**: Locked to specific versions
✅ **Declarative**: Version in your config
✅ **Cached**: Nix cache speeds up installs
✅ **No npm needed**: Pure Nix solution
✅ **Garbage collected**: Removed when not used
✅ **Multiple versions**: Can have different versions for different users

## Current Status

⚠️ **Hashes need to be filled in**

The package definition is complete but needs the actual hashes. Follow "Step 1: Get the Hashes" above to complete it.

## See Also

- [Nixpkgs JavaScript Documentation](https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/javascript.section.md)
- [buildNpmPackage Source](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/node/build-npm-package/default.nix)
- [happy-coder npm page](https://www.npmjs.com/package/happy-coder)
- [happy-cli GitHub](https://github.com/slopus/happy-cli)
