
I often use flox and direnv when developing on projects. If you are having trouble figuring out the environment try to 'flox activate' first.

Browser screenshots/automation on this NixOS machine: Playwright's own downloaded chromium fails (missing system libs). Drive it with `playwright-core` and set `executablePath` to the nix-store build — find it via `ls -d /nix/store/*-playwright-chromium/*/chrome` (the hash changes, so don't hardcode). `steam-run` wraps prebuilt binaries in an FHS env as a fallback. For web apps, prefer screenshotting a dev/built client through a backend-free path (e.g. a demo/fixture mode) over standing up the whole stack.

This file is home-manager-managed: it's the source for the read-only `~/.claude/CLAUDE.md` symlink into the nix store. Edits here only take effect after a home-manager rebuild.

I use fish shell, so look there for commonly used aliases and env vars.

I often use Justfile for most common commands. And docker with compose for a reference on how to run things (including env vars) - even if you dont do it using docker.

Keep the Readme up to date when relevant code changes occur since I want that to be the source of truth for information gathering.

I use a bunch of different LLM models and agents so I dont rely on skills etc. and this file should be kept to a minimum.
