# Hard-Coded User and Home Path Cleanup Plan

## Goal

Remove hard-coded local user and home-directory assumptions from active Nix and Home Manager configuration so the repo is easier to reuse across hosts and users.

This plan is specifically about values like:

- `jono`
- `/home/jono`
- paths derived from that home directory such as `/home/jono/sync`

It is not a blanket plan to remove every occurrence of `jono` from the repo. Identity-specific values such as email addresses, mailbox names, SSH key comments, and machine names should be treated separately.

## Current State

The main active hard-coding is in Home Manager:

- `home-manager/modules/common.nix` sets:
  - `home.username = "jono";`
  - `home.homeDirectory = "/home/jono";`

There is already a partial abstraction point:

- `home-manager/hosts/vars.nix`
- `nixos/hosts/vars.nix`

Both currently expose only:

```nix
{
  jonoHome = "/home/jono";
}
```

That is not enough yet because active modules still use inline values directly.

Additional active path assumptions exist in:

- `home-manager/hosts/nixahi.nix`
- `nixos/modules/syncthing.nix`
- `nixos/hosts/matcha/default.nix`
- `nixos/hosts/nixahi/default.nix`
- some host-specific mount and service definitions under `nixos/hosts/*`

## Scope

### In scope

- Active NixOS modules
- Active Home Manager modules
- Active host definitions
- Flake wiring where usernames are baked into output names or module inputs

### Out of scope for the first pass

- Historical files such as `configuration-orig.nix`
- Lock backups
- READMEs and exploration docs
- Identity-specific strings that are intentionally personal rather than environment-derived

## Proposed Design

Create one small shared attrset for user-specific machine context and derive paths from that instead of repeating string literals.

The shared context should include at least:

```nix
{
  username = "jono";
  homeDirectory = "/home/jono";
  syncRoot = "/home/jono/sync";
}
```

Derived values should be computed from the base fields where possible:

```nix
{
  username = "jono";
  homeDirectory = "/home/jono";
  syncRoot = "${homeDirectory}/sync";
  configsRoot = "${syncRoot}/configs";
}
```

This can live in a shared vars file, or be passed through `extraSpecialArgs`, or both.

## Implementation Phases

### Phase 1: Establish a source of truth

Replace the current `jonoHome`-only pattern with a broader attrset that describes the active local user context.

Tasks:

- Expand `home-manager/hosts/vars.nix`
- Expand `nixos/hosts/vars.nix`
- Decide whether a single shared vars file should back both trees
- Standardize field names:
  - `username`
  - `homeDirectory`
  - `syncRoot`
  - optional derived paths such as `configsRoot`

Decision point:

- If Home Manager and NixOS always share the same local-user assumptions, use one shared vars file.
- If they may diverge by host or bootstrap stage, keep separate files with the same schema.

### Phase 2: Refactor active Home Manager modules

Wire Home Manager to consume the shared user context and remove direct `jono` and `/home/jono` assignments from active modules.

Primary targets:

- `home-manager/modules/common.nix`
- `home-manager/hosts/nixahi.nix`

Tasks:

- Replace direct `home.username` assignment with the shared `username`
- Replace direct `home.homeDirectory` assignment with the shared `homeDirectory`
- Replace any path literals built from `/home/jono` with derived values

Expected outcome:

- Home Manager becomes portable across users without editing `common.nix`

### Phase 3: Decide how flake output names should work

`home-manager/flake.nix` currently publishes outputs like:

- `jono@dobro`
- `jono@zeeba`

There are two reasonable options:

1. Keep the current output names for compatibility.
2. Generate output names from the configured `username`.

Tradeoff:

- Keeping `jono@host` avoids breaking existing commands and muscle memory.
- Deriving the output names makes the flake itself portable.

Recommended approach:

- Keep compatibility first unless there is an active need to run this repo as another user immediately.
- If portability matters now, add generated names and optionally keep the old names as aliases during transition.

### Phase 4: Refactor active NixOS modules and hosts

After Home Manager is wired cleanly, apply the same pattern to NixOS modules and hosts that depend on local-user paths.

Primary targets:

- `nixos/modules/syncthing.nix`
- `nixos/hosts/matcha/default.nix`
- `nixos/hosts/nixahi/default.nix`
- active host files with mounts or service commands referencing `/home/jono`

Tasks:

- Replace inline home-directory paths with derived paths from shared user context
- Remove duplicated assumptions in service commands, bind mounts, and host mount targets
- Keep genuine host-specific values host-specific

Expected outcome:

- Services and mounts derive from the configured user context instead of being tied to one username

### Phase 5: Second-pass cleanup for docs and templates

Once the active configuration evaluates correctly, do a lower-risk cleanup of supporting material.

Targets:

- READMEs
- templates
- bootstrap examples
- comments that still teach `/home/jono` as the only path

This pass should be selective. Some docs should stay personalized if they are intentionally for your own use.

## Verification Plan

After each phase, verify by evaluating at least one Home Manager host and one NixOS host that consume the refactored values.

Suggested checks:

- Evaluate a representative Home Manager host
- Evaluate a representative NixOS host
- Confirm that generated service paths point to the expected derived directories
- Confirm that no active modules still depend on `"/home/jono"` or `"jono"` where those should now be configurable

Useful repo-level searches:

```bash
rg -n '/home/jono|home\.username = "jono"|home\.homeDirectory = "/home/jono"|users\.users\.jono'
```

The search results should be reviewed, not blindly driven to zero. Some remaining matches will be valid identity-specific data or historical files.

## Risks

### Over-generalizing identity-specific values

Some `jono` strings are not configuration bugs. Examples:

- git email
- mailbox/account names
- SSH key comments
- personal host references

These should not be folded into the same abstraction unless there is a specific portability requirement.

### Breaking CLI entrypoints

Changing flake output names from `jono@host` to derived names can break existing commands and scripts.

Mitigation:

- keep compatibility aliases during migration

### Mixing host-specific and user-specific concerns

Not every absolute path should come from one global vars file. Some service paths are truly host-specific and should stay local to that host.

Mitigation:

- only abstract values that are clearly derived from local user context

## Recommended Order

1. Expand the vars schema.
2. Refactor Home Manager active modules.
3. Decide on flake output naming.
4. Refactor active NixOS modules and hosts.
5. Run validation.
6. Do the optional documentation/template cleanup pass.

## Success Criteria

This cleanup is successful when:

- active Home Manager config no longer hard-codes `jono` and `/home/jono`
- active NixOS modules use shared or derived user context where appropriate
- flake entrypoints are either portable or intentionally compatibility-pinned
- remaining `jono` references are clearly personal data, historical files, comments, or deliberate host-specific choices
