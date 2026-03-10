# Home Manager Per-Host Flakes

Some hosts use their own flake with an independent lock file, allowing each host to pin different versions of nixpkgs and other inputs. This mirrors the pattern used in the NixOS configs.

## How it works

- Hosts using `mkHome` share the top-level `flake.lock`
- Hosts using `mkHomeWithFlake` have their own `flake.nix` + `flake.lock` in `hosts/<hostname>/`
- The per-host flake just declares inputs and exposes them — the top-level flake handles all home-manager logic

## Migrating a host

1. Create the host directory and flake:

```
mkdir hosts/<hostname>
```

Create `hosts/<hostname>/flake.nix`:

```nix
{
  description = "<hostname> host inputs (independent lock file)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-master = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: {
    inherit inputs;
  };
}
```

Add or remove inputs as needed for the host (e.g. flox, sops-nix).

2. Move the host config from a file to a directory:

```
mv hosts/<hostname>.nix hosts/<hostname>/default.nix
```

Update the import path in `default.nix` from `../modules/` to `../../modules/`.

3. Update the top-level `flake.nix`:

- Add the input: `<hostname>-flake.url = "path:./hosts/<hostname>";`
- Add it to the outputs parameter list
- Change the host entry from `mkHome` to `mkHomeWithFlake`:

```nix
"jono@<hostname>" = mkHomeWithFlake "<hostname>" "<system>" <hostname>-flake;
```

4. Generate the per-host lock file and update the top-level lock:

```
cd hosts/<hostname> && nix flake lock
cd ../.. && nix flake lock --update-input <hostname>-flake
```

5. Test the build:

```
nh home switch . --dry-run
```

## Current status

| Host    | Type             |
|---------|------------------|
| matcha  | per-host flake   |
| dobro   | shared flake     |
| zeeba   | shared flake     |
| orc     | shared flake     |
| imbp    | shared flake     |
| nixahi  | shared flake     |
| plex    | shared flake     |
| lute    | shared flake     |
| ocarina | shared flake     |
