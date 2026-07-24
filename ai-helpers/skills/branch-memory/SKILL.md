---
name: branch-memory
description: Capture a durable memory note when a branch of work is complete. Use this whenever the user says they are done with a branch, wrapping up a feature, about to merge, or asks to "capture", "record", or "save" what happened on the current branch — even if they don't say the word "memory". Writes one entry per branch into a project-local markdown file, updating the existing entry in place if the branch was already captured. Records the reasoning behind the work (decisions, rejected alternatives, gotchas, open threads) — deliberately NOT a summary of the code, which the agent can always re-read.
---

# Branch Memory

Capture the *reasoning* around a completed branch of work into a project-local markdown file, so a future session (this agent or another) doesn't have to reconstruct or re-litigate what was already settled.

This skill is triggered **manually** — when the user indicates a branch is done. There is no automatic hook. Do not offer to capture unprompted mid-work; wait for the user to ask.

## Core principle: store what the code can't tell you later

The single test for what belongs in a memory note:

> **Store what a future agent cannot recover by reading the code. Skip what it can.**

The code shows *what* was built. It never shows *why*, never shows *what was rejected*, and never shows *what was deliberately left undone*. That reasoning layer is the whole value. A summary of what the code does is noise — the agent reads the code fresh next time, and reads it better than a stale summary.

Concretely:

**DO capture (all fail the "recoverable from code" test):**
- **Decisions + rationale** — "chose X because Y." The highest-value item.
- **Rejected alternatives** — "considered A, rejected it because B." Often *more* valuable than the decision, because it stops the next session from re-proposing dead paths.
- **Gotchas / hard-won operational facts** — the migration that needs manual editing, the test that needs a fixture first, the service that must restart after a change. Painful to rediscover.
- **Open threads / deferred work** — what was intentionally left unfinished and why, and what the next branch should pick up.
- **Non-obvious architecture notes** — the constraint that forced an unusual shape; the thing that looks wrong but is intentional (so the agent doesn't "fix" it).

**DO NOT capture (recoverable, or goes stale):**
- A summary of what the code does — re-read the code.
- A blow-by-blow session log — keep the conclusion, not the transcript.
- Fast-churning state (e.g. current schema shape, current dependency versions) — it's wrong within days and worse than nothing. Store *decisions about* such things, which are stable, not the state itself.

If a section has nothing worth recording, omit it. A short honest note beats a padded one.

## Where the files live

**One file per branch**, named for the branch: `docs/branch-memory/{branch-name}.md`. Create the `docs/branch-memory/` directory if absent. Sanitize the branch name for the filesystem — replace `/` with `-` (so `feat/geometry-sync` → `feat-geometry-sync.md`).

Why one file per branch rather than one shared file: a shared file grows without bound and gets dragged into context in full every time the agent consults memory, which pollutes the context window linearly as the project ages. Per-branch files keep each read scoped to the one branch being resumed, while `grep -r docs/branch-memory/` still answers cross-branch "where did I handle X" lookups. The filename *is* the key — the branch name — which is what makes update-in-place a clean overwrite.

No date in the filename: the branch name is the stable identity; git history and the `Started`/`Updated` lines inside each file carry the dates more accurately than a frozen filename prefix would. For a chronological view, use `git log docs/branch-memory/`.

If the project already has an obvious memory location that differs from this, match it rather than imposing a new one — but prefer a dedicated per-branch file over appending to `AGENTS.md`/`CLAUDE.md`, which are for instructions, not history.

The files are committed with the branch's normal work (tracked, not gitignored) so git carries them across machines. Mention this to the user the first time you create the directory in a repo, in case they want it elsewhere or gitignored.

## Procedure

### 1. Identify the branch
Run `git branch --show-current` to get the branch name. This is the **key** for the entry — it's how you find an existing entry to update. If the repo is in a detached HEAD or the branch name is ambiguous, ask the user what to key the entry on.

### 2. Gather raw material
Read, don't guess. Pull the actual work of the branch:
- `git log <base>..HEAD --oneline` (infer base as `main`/`master`/`develop`, or ask if unclear) for the commit narrative.
- `git diff <base>..HEAD --stat` for the shape of what changed.
- Skim the actual diff of the most substantive changes to ground the "why."
- **Most important:** draw on the current conversation. The decisions and rejected alternatives are usually in what the user said during the work, not in the commits. If you were part of the session that did the work, that context is your best source.

### 3. Check for an existing file
Compute the filename from the branch (sanitized, as above) and check whether `docs/branch-memory/{branch}.md` already exists.
- **If it exists:** you are **updating**. Read it, then rewrite the whole file to reflect the final state of the work. Preserve the original `Started` date from the existing file; set `Updated` to today. Do not merely append — revise every section, because a stale half-done line contradicting a done line is exactly the rot this design prevents. Since each file holds exactly one branch, updating is a clean full overwrite, not a splice.
- **If it doesn't exist:** create it, with `Started` and `Updated` both set to today.

### 4. Write the file
Use this exact structure:

```markdown
# {branch-name}
*Started: {YYYY-MM-DD} · Updated: {YYYY-MM-DD}*

**What this branch did** (one or two sentences of orientation — not a code summary)
{brief}

**Decisions**
- {decision} — because {rationale}

**Rejected**
- {alternative} — rejected because {reason}

**Gotchas**
- {hard-won fact}

**Open threads**
- {deferred work / what the next branch should pick up}

**Notes** (optional — non-obvious architecture, anything above categories miss)
- {note}
```

Omit any section that would be empty except "What this branch did," which always stays for orientation.

### 5. Show, don't auto-commit
Show the user the entry you wrote (or the diff, if updating). Do **not** run `git commit` unless the user asks — they may want to review, tweak, or bundle it with their own commit. Committing is their call.

## Cross-tool note
This skill is plain markdown + git + shell commands, so it works identically under Claude Code and OpenCode. Nothing here depends on a specific agent, an API key, a database, or an embedding model — the "summarization" is just you (the agent already in the session) writing the note. Retrieval later is the next session reading this file, plus `git log` / `grep` when the user wants history.

## Example

**User:** "ok I'm done with the geometry-sync branch, capture it"

**Good file** (`docs/branch-memory/geometry-sync.md`):
```markdown
# geometry-sync
*Started: 2026-07-04 · Updated: 2026-07-04*

**What this branch did**
Added native GEOGRAPHY handling to the Postgres→BQ load path for PostGIS columns.

**Decisions**
- Load WKT strings into BQ columns declared as GEOGRAPHY in the load-job schema — because BQ auto-converts WKT→GEOGRAPHY on load, so no view layer is needed.

**Rejected**
- Airbyte Cloud for this sync — rejected because it gives no control over BQ column-type declaration, which is exactly what the GEOGRAPHY path depends on.

**Gotchas**
- The load-job schema must declare the column type explicitly; relying on autodetect silently lands geometry as STRING.

**Open threads**
- RDS source still on the old signature; the WKT path is untested against it.
```

Note what's absent: no list of files changed, no restatement of function bodies, no current table list. Just the reasoning the code can't carry.
