# NixOS Configuration

Single `flake.nix` managing all hosts with shared `flake.lock`.

**Deploy:** `sudo nixos-rebuild switch --flake .#hostname`


or somethign like

nix --extra-experimental-features "nix-command flakes" build .#nixosConfigurations.hostname.config.system.build.toplevel


**Update:** `nix flake update` (updates all hosts)

## Hosts

- dobro, zeeba, plex, orc, imbp, nixahi, matcha

## Per-Host Independent Locks

Due to Nix flake limitations (paths, directory requirements), achieving truly independent per-host lock files requires trade-offs:

1. **Subdirectory flakes** - Path issues with `../../modules` imports
2. **Absolute paths** - Not portable
3. **Duplicate modules** - Maintenance overhead

**Conclusion:** Shared lock file is the simplest working solution. Update hosts individually by testing on one host first, then rolling out to others.
