# Per-Host Flakes Exploration

## The Goal

Have separate `flake.lock` files per NixOS host to:
- Update packages independently per host
- Test updates on one host before deploying to others
- Avoid forced synchronized updates across all hosts

## Current State

**Status:** Back to original monolithic approach

**Working Setup:**
- Single `flake.nix` at repo root
- Single `flake.lock` shared across all hosts
- All hosts: dobro, zeeba, plex, orc, imbp, nixahi, matcha
- Deploy: `sudo nixos-rebuild switch --flake .#hostname`

## What We Tried

### 1. Per-Host Flakes in Subdirectories

**Structure:**
```
nixos/
├── flake.nix (old hosts)
├── hosts/
│   └── plex/
│       ├── flake.nix
│       ├── flake.lock
│       └── default.nix
```

**Problem:** When flake is evaluated, it's copied to `/nix/store`. Relative imports like `../../modules/common-nixos.nix` break because they point outside the flake directory.

**Result:** ❌ Failed - path resolution issues

---

### 2. Top-Level Aggregator with inputs.follows

**Structure:**
```
nixos/
├── new/flake.nix (aggregator with defaults)
├── lib/flake.nix (shared builder)
├── hosts/plex/flake.nix (minimal)
```

**Concept:**
- `new/flake.nix` defines all input URLs once
- Uses `inputs.follows` to make host flakes inherit parent's inputs
- Shared builder in `lib/flake.nix` to reduce duplication

**Example:**
```nix
# new/flake.nix
inputs = {
  nixpkgs.url = "nixpkgs/nixos-25.11";
  plex.url = "path:../hosts/plex";
  plex.inputs.nixpkgs.follows = "nixpkgs";  # Inherit!
};
```

**Problem:** Same as #1 - subdirectory flakes can't reference `../` when evaluated in `/nix/store`.

**Result:** ❌ Failed - required absolute paths, too complex

---

### 3. Absolute Paths Everywhere

**Concept:** Use absolute paths to work around Nix's evaluation model

**Example:**
```nix
parent.url = "path:/home/jono/sync/configs/nixos/lib";
sharedModulesPath = /home/jono/sync/configs/nixos/modules;
```

**Problem:** 
- Not portable - breaks if repo moves
- Too complex - multiple flakes with absolute paths
- Maintenance burden

**Result:** ❌ Works but unacceptable - not portable

---

### 4. Separate Flake File (flake-plex.nix)

**Concept:** Keep flake at repo root but in separate file

**Structure:**
```
nixos/
├── flake.nix (old hosts)
├── flake-plex.nix (plex with independent lock)
```

**Problem:** Nix flakes **must be directories**, not files

**Result:** ❌ Failed - Nix limitation

---

## Key Learnings

### Nix Flake Limitations

1. **Flakes must be directories**
   - Can't use `flake-plex.nix`
   - Must be `flake.nix` inside a directory

2. **Pure evaluation model**
   - Flakes copied to `/nix/store` during evaluation
   - Relative paths outside flake directory (`../../`) don't work
   - Only paths within the flake directory are accessible

3. **Subdirectory flakes are problematic**
   - Path resolution from parent directories fails
   - Requires absolute paths or complex workarounds

4. **No good solution for shared code**
   - Can't easily share modules between independent flakes
   - Options: duplicate code, absolute paths, or monolithic flake

### What Works

✅ **Monolithic Flake (Current Approach)**
- Single `flake.nix` at repo root
- Shared `flake.lock` across hosts
- Simple, maintainable, all imports work
- Trade-off: can't update hosts independently

✅ **Flake Inputs**
- Standard inputs pattern works well
- `inputs.follows` works for dependency management
- `specialArgs` passes custom arguments to modules

### What Doesn't Work

❌ **Independent per-host locks with shared modules**
- Nix flake architecture fundamentally doesn't support this pattern
- Every workaround has major drawbacks

❌ **Relative paths from subdirectories**
- `path:../lib` doesn't work when flake is in `/nix/store`
- `../../modules` imports fail from subdirectory flakes

## Recommendations

### For Now: Monolithic Flake

**Pros:**
- Simple, well-understood
- All imports work correctly
- Portable (no absolute paths)
- Easy to maintain

**Cons:**
- Shared lock file
- Must update all hosts together (or use copy-lock workaround)

**Workflow:**
1. Test updates: `nix flake update` in a branch
2. Deploy to test host: `sudo nixos-rebuild switch --flake .#plex`
3. If stable, deploy to other hosts

### Future Possibilities

**If Nix Adds Better Support:**
- Watch for Nix features supporting subdirectory flakes with parent imports
- Or: directory-level lock files within a flake

**Workaround (Complex):**
- Copy `flake.lock` to host-specific names (`flake-plex.lock`)
- Use different flake references per host
- Too much manual management

**Alternative: NixOps or deploy-rs**
- Tools designed for multi-host deployments
- Can manage per-host state separately
- Adds complexity but might suit multi-host scenarios

## Files Created/Deleted During Exploration

**Deleted:**
- `new/flake.nix` (aggregator)
- `lib/flake.nix` (shared builder)
- `hosts/plex/flake.nix` (per-host flake)
- `flake-plex.nix` (file-based flake)
- Various documentation files

**Kept:**
- `flake.nix` (original monolithic)
- `flake.lock` (shared lock)
- `README.md` (updated with learnings)
- This exploration doc

## Conclusion

Per-host flake locks with shared modules is **theoretically desirable** but **practically infeasible** with current Nix flakes due to:

1. Pure evaluation copying flakes to `/nix/store`
2. No support for relative paths to parent directories
3. Flakes must be directories, not files

The **monolithic flake** remains the best approach for managing multiple hosts with shared configuration modules.

**Bottom line:** Sometimes the straightforward solution is the right solution.

## Future Exploration

If you revisit this:

1. **Check Nix release notes** - Path handling may improve
2. **Consider flake-parts** - Module system for flakes that might help
3. **Look into flake-utils-plus** - Advanced flake patterns
4. **Explore NixOps/deploy-rs** - If multi-host deployment becomes primary use case

## Quick Reference

**Current Deploy:**
```bash
cd ~/sync/configs/nixos
sudo nixos-rebuild switch --flake .#hostname
```

**Update All:**
```bash
nix flake update
```

**Test on One Host:**
```bash
git checkout -b test-update
nix flake update
sudo nixos-rebuild switch --flake .#plex  # Test first
# If good, deploy to others
```

