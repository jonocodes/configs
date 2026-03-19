# Thunderbird Home Manager Findings

Date: 2026-03-19
Host investigated: `lute`

## Summary

The Thunderbird problem is not a Nix build or Home Manager evaluation failure.
It is a Home Manager activation conflict on `~/.thunderbird`.

Home Manager still expects `~/.thunderbird` to be the managed external symlink
declared in the host config, but the live filesystem path is currently a normal
directory. Because of that mismatch, `home-manager switch` aborts to avoid
clobbering data.

I did not find evidence that this ownership requirement was introduced recently.
The available upstream evidence shows Home Manager was already managing
Thunderbird profile state by October 14, 2023.

## Local configuration involved

### Host-level external Thunderbird link

File: [home-manager/hosts/lute.nix](/home/jono/sync/configs/home-manager/hosts/lute.nix#L9)

```nix
home.file.".thunderbird".source =
  config.lib.file.mkOutOfStoreSymlink /dpool/thunderbird_data;
```

This says Home Manager should own `~/.thunderbird` and make it a symlink to
`/dpool/thunderbird_data`.

### Thunderbird declarative config

File: [home-manager/modules/email.nix](/home/jono/sync/configs/home-manager/modules/email.nix#L62)

This module enables `programs.thunderbird` and declaratively defines:

- Thunderbird profiles
- generated profile settings
- email accounts via `accounts.email.*.thunderbird.enable = true`

## Reproduction

### Build result

This succeeded:

```bash
nix build .#homeConfigurations."jono@lute".activationPackage --show-trace
```

That means the failure is not in evaluation or derivation building.

### Activation result

Dry-run activation failed with:

```text
Activating checkLinkTargets
cmp: /nix/store/...-home-manager-files/.thunderbird: Is a directory
Existing file '/home/jono/.thunderbird' would be clobbered
```

This is the actual failure mode.

## Filesystem state at time of investigation

### Live path

`/home/jono/.thunderbird` was a real directory:

```text
directory '/home/jono/.thunderbird'
```

Listing showed:

```text
/home/jono/.thunderbird/
└── p5gk3v2u.default
```

### External target

`/dpool/thunderbird_data` existed and contained the full Thunderbird data set,
including:

- `profiles.ini`
- `installs.ini`
- `p5gk3v2u.default`
- `2yxi6v07.arlene`

### Generated Home Manager target

The newly built Home Manager generation still resolved:

```text
.thunderbird -> /dpool/thunderbird_data
```

So Home Manager is still trying to preserve the external link.

## Historical local evidence

I checked recent Home Manager generations on `lute`.

Generation history included:

- `2026-03-18 19:04 : id 26`
- `2026-03-18 20:01 : id 27`

The important part is that the previous generation already contained:

```text
/nix/store/...-home-manager-generation/home-files/.thunderbird -> /dpool/thunderbird_data
```

That means:

1. Home Manager was already managing `.thunderbird` as the external symlink in
   the immediately previous generation.
2. The new generation wants the same thing.
3. The current failure comes from the live path having drifted away from that
   managed symlink and becoming a normal directory.

## Conclusion from local evidence

The immediate cause is not a recent config change in this repo and not a new
build-time Thunderbird requirement.

The concrete problem is:

- expected by Home Manager: `~/.thunderbird` is a symlink to
  `/dpool/thunderbird_data`
- actual live state: `~/.thunderbird` is a directory

That mismatch makes `home-manager switch` abort.

## Upstream evidence about whether this is recent

### Current pinned Home Manager revision

Your current flake pin for Home Manager is:

- `0759e0e137305bc9d0c52c204c6d8dffe6f601a6`

Current module reference:

- <https://github.com/nix-community/home-manager/blob/0759e0e137305bc9d0c52c204c6d8dffe6f601a6/modules/programs/thunderbird.nix>

This module clearly manages Thunderbird profiles, generated profile state, and
related files declaratively.

### Older public evidence

This Discourse thread from October 14, 2023 references an older Home Manager
Thunderbird module commit and explicitly notes that the module converts account
configuration into a Thunderbird profile:

- <https://discourse.nixos.org/t/cannot-setup-email-password-declaratively/34168>

That thread links to this older Home Manager commit:

- `a4a72ffd76f2c974601e7adff356e5c277e08077`

This is strong evidence that Home Manager’s Thunderbird profile management
behavior was already in place by 2023-10-14.

### Ruled-out recent refactor

I also checked the obvious 2024 browser refactor PR:

- <https://github.com/nix-community/home-manager/pull/5128>

That PR was Firefox-only. It is not the Thunderbird change that would explain
this behavior.

## Best-supported conclusion

I do not have evidence that a recent Thunderbird or Home Manager package update
introduced a new requirement that `~/.thunderbird` be fully owned.

The strongest supported conclusion is:

- Home Manager has had Thunderbird profile management behavior for a long time,
  at least since October 14, 2023.
- Your host config has been explicitly telling Home Manager to own
  `~/.thunderbird` as an external symlink.
- The current break happened because the live path no longer matches that
  managed symlink.

## What I was not able to prove

I was not able to identify the exact first upstream commit that introduced the
Thunderbird ownership/profile behavior.

What I *was* able to prove:

- current build succeeds
- activation fails on `~/.thunderbird` collision
- previous local Home Manager generation already expected the same external
  symlink
- the behavior is older than 2024 and was publicly visible by 2023-10-14

## Likely next actions

If the symlink really broke, the safest recovery path is:

1. Verify whether the live directory content is already duplicated in
   `/dpool/thunderbird_data`.
2. If it is the same data, move `/home/jono/.thunderbird` aside and let Home
   Manager recreate the symlink.
3. Re-run `home-manager switch` and confirm `~/.thunderbird` is again a symlink
   to `/dpool/thunderbird_data`.

Practical outline:

```bash
mv ~/.thunderbird ~/.thunderbird.broken-$(date +%F-%H%M%S)
home-manager switch
readlink -f ~/.thunderbird
```

Expected final state:

```text
~/.thunderbird -> /dpool/thunderbird_data
```

If the moved-aside directory contains anything that is newer or not present in
`/dpool/thunderbird_data`, merge that data back carefully before deleting the
backup copy.

If you want extra safety, compare the two trees before moving anything:

```bash
find ~/.thunderbird /dpool/thunderbird_data -maxdepth 2 | sort
```

or, more usefully:

```bash
diff -rq ~/.thunderbird /dpool/thunderbird_data
```

Working assumption from the local evidence:

- the external target `/dpool/thunderbird_data` still exists and looks like the
  canonical Thunderbird data store
- the live `~/.thunderbird` directory is likely the result of the symlink being
  replaced or recreated as a plain directory

## Additional comparison findings

I compared:

- `/home/jono/.thunderbird`
- `/dpool/thunderbird_data`

### Structural result

The live `~/.thunderbird` path is not a full replacement for the external
Thunderbird store.

It contains only:

- one profile directory: `p5gk3v2u.default`
- a small subset of runtime files inside that profile

By contrast, `/dpool/thunderbird_data` contains the full Thunderbird dataset,
including:

- `profiles.ini`
- `installs.ini`
- `p5gk3v2u.default`
- `2yxi6v07.arlene`
- `Mail`
- `ImapMail`
- address books
- extensions
- caches
- crash reports

### Practical interpretation

This strongly suggests:

- `/dpool/thunderbird_data` is still the canonical Thunderbird home
- `/home/jono/.thunderbird` is a partial local directory that Thunderbird
  recreated or wrote into after the symlink stopped being in place

### Notable newer local files

There is evidence of newer runtime state in the broken local directory.

For example:

- local `prefs.js` timestamp:
  `2026-03-19 04:59:31 -0700`
- external `prefs.js` timestamp:
  `2026-03-18 19:58:35 -0700`

There is also at least one telemetry archive file present only in the broken
local tree:

- `/home/jono/.thunderbird/p5gk3v2u.default/datareporting/archived/2026-03/1773903600752.1d56da72-02ac-4e4b-940e-930740d470e2.main.jsonlz4`

This means the local broken directory is not entirely disposable without
inspection, but the unique delta appears to be small and dominated by runtime
state rather than core mail storage.

## Safety snapshot taken

Before any repair, I created this ZFS snapshot:

- `dpool/thunderbird_data@pre-thunderbird-symlink-recovery-2026-03-19`

Verified with:

```text
dpool/thunderbird_data@pre-thunderbird-symlink-recovery-2026-03-19
```
