# Local screenshot host — R&D notes

Status: proof-of-concept validated on Paseo (2026-07-21). OpenCode web tested same day — **no inline image path**, but **clickable URL links** work over Tailscale (bare URL + markdown link forms). Inline image rendering blocked on upstream #21227.
Scope: **web and desktop agent UIs only** (see Out of scope below).

This is the research / development log for the `shotput` convention. For the concise agent-ingestion contract, see `~/shots/SKILL.md`.

| In scope | Out of scope |
|----------|----------------|
| Paseo desktop / web | OpenCode **TUI** / CLI |
| T3 Code web (and desktop if used) | Terminal graphics (Sixel/Kitty/chafa) |
| OpenCode **web** (`opencode web`) | Cloud-only chat UIs (Claude.ai, ChatGPT web, Gemini web) |
| LibreChat / Open WebUI (self-hosted) | |

Next validation passes: T3 Code web, LibreChat, Open WebUI (see "Other clients worth testing" below). The matrix is **not** filled for these yet.

---

## Problem

Several LLM coding agents run on one machine (Paseo desktop/web, T3 Code web, etc.). Agents can *capture* screenshots (Playwright, browser tools, Read on PNG), but **showing them inline in chat** is inconsistent:

- Some UIs only turn tool image blocks into tiles.
- Some treat `http://…` as a clickable link, not an `<img>`.
- Remote/mobile clients cannot load the host's `127.0.0.1`.
- Dumping base64 into the timeline blows message size caps (Paseo has open work here).

We want one local convention: **write a PNG somewhere stable, emit markdown the UI will actually render**.

## PoC (what we ran)

```sh
mkdir -p ~/shots
# copy any PNG into ~/shots/
npx --yes serve ~/shots -l tcp://127.0.0.1:9191 --no-clipboard
```

Example file:

| Role | Path |
|------|------|
| On-disk | `/home/jono/shots/deckd-firefox.png` |
| HTTP | `http://127.0.0.1:9191/deckd-firefox.png` |
| Workspace copy | `<workspace>/.shots/deckd-firefox.png` |

## Rendering matrix (this machine)

### Per-client results

Fill cells: `inline` | `link` | `broken` | `?`

| Form | Paseo local (2026-07-21) | T3 Code web | OpenCode web |
|------|--------------------------|-------------|--------------|
| **B** `.shots/NAME.png` | inline | ? | broken |
| **C** `/abs/…/NAME.png` | inline | ? | broken |
| **A** `file:///abs/…/NAME.png` | inline | ? | broken |
| **H** `http://127.0.0.1:9191/NAME.png` | link | ? | broken |
| **L1** bare URL `http://host:9191/NAME.png` | n/a | ? | clickable (lute:9191 via Tailscale) |
| **L2** markdown link `[H](http://host:9191/NAME.png)` | n/a | ? | clickable (lute:9191 via Tailscale) |
| **I** raw `<img src=http://…>` | broken | ? | broken |
| data-URI (optional) | broken / unreliable | ? | broken (assumed — not retested) |

| Client | Status | Preferred emit order (after test) | Notes / deltas |
|--------|--------|-------------------------------------|----------------|
| **Paseo desktop / web (local)** | tested 2026-07-21 | `B ≈ A ≈ C` then H as link-only fallback | HTTP never inlined |
| **Paseo remote / mobile** | untested | ? (guess: B only) | `127.0.0.1` will not work on phone |
| **T3 Code web** | **to test** | ? | |
| **OpenCode web** | tested 2026-07-21 | none — no inline image rendering; bare/markdown URL link works | All chat markdown image forms (B/C/A/H/I) broken. `Read` on a PNG emits an "Attached media from tool result" *text* line but **no visible tile** (glm-5.2 rejects the image block, but display is independent of model — nothing rendered). However: **bare URL** and **markdown link** (non-image) are clickable — `http://lute:9191/…` tested from phone over Tailscale works. UI has no inline image surface for tool-result attachments — upstream **#21227** tracks this, assigned jlongster, fix scoped to `packages/ui/message-part.tsx`. Separate V2 capability-filter bug we hit with `glm-5.2` was **#38144** (closed). `shotput` cannot inline OpenCode web until #21227 lands; for this client emit bare/markdown URL only. |
| LibreChat (self-hosted) | **to test** | ? | MCP + tool-result support exists; image rendering unverified |
| Open WebUI (self-hosted) | **to test** | ? | Same caveat |
| Claude-oriented UIs | n/a | tool image blocks > path md | outside shotput core |

Paseo's own provider path (Claude/Codex tool images) materializes bytes under a temp dir like `/tmp/paseo-attachments-*/<sha256>.png` and emits `![…](file://…)`. Our PoC A/C mimic that without going through the provider image pipeline.

### Per-client upstream reference

Quick lookup for "is this client's display blocked on something upstream?":

| Client | Inline display upstream tracker |
|--------|--------------------------------|
| Paseo desktop/web (local) | Working (provider image materialization path) |
| OpenCode web | **#21227** — UI never renders tool-result attachments (assigned jlongster; fix in `packages/ui/message-part.tsx`) |
| T3 Code web | Unknown — needs test |
| LibreChat | Unknown — needs test |
| Open WebUI | Unknown — needs test |

## URL discovery (tailnet / LAN host)

The HTTP hostname should be **discovered at runtime**, not hardcoded. The system hostname matches the Tailscale `HostName` on this machine (`lute`), so:

```sh
TS_HOST=$(tailscale status --json 2>/dev/null | jq -r '.Self.HostName // empty' \
       || hostname 2>/dev/null) ; \
TS_HOST=${TS_HOST:-127.0.0.1}
# Use http://$TS_HOST:9191/ for tailnet/LAN-reachable URLs; 127.0.0.1:9191 for loopback-only
```

MagicDNS FQDN is also available: `tailscale status --json | jq -r '.Self.DNSName'` → `lute.wolf-typhon.ts.net.` (trailing dot — strip before use). Stick with the bare HostName for shorter URLs inside the tailnet.

### Bind exposure policy

The static `serve` instance was originally bound to `127.0.0.1` only. For phone/remote via Tailscale it must bind an interface reachable from the tailnet:

- `tcp://0.0.0.0:9191` — works on this machine because:
  - The host's only routable exposure is via its Tailscale interface (`100.98.199.48`).
  - LAN side (if any) is firewalled or trusted.
  - Tailscale ACLs gate tailnet access.
- **Do not** use `0.0.0.0` on a host with a public NIC unless an auth layer is added.
- Alternative: `tcp://100.98.199.48:9191` (binds the Tailscale interface only).

Recommend binding to the Tailscale IP explicitly when feasible. For now `0.0.0.0` on `lute` is acceptable because of the single-interface topology.

## OpenCode web — upstream issue map

Inline image display in OpenCode web is a **known unimplemented feature**, not a user-space config gap. `shotput` cannot fix this client until upstream lands.

| Issue | State | What it is |
|-------|-------|------------|
| **#21227** `display image attachments from tool results in chat UI` | OPEN, assigned jlongster | The core gap we hit. Tool-result images (e.g. `Read` on PNG, `webfetch` on image URL, MCP `ImageContent`) land in `part.state.attachments` and are correctly forwarded to the model, but `ToolPartDisplay` in `packages/ui` never renders them. Proposed fix is scoped to `message-part.tsx` — no backend changes. |
| **#38144** `v2 image bytes from read tool sent to non-vision models` | CLOSED | The error we triggered with `glm-5.2`. V2 dropped V1's capability filtering at `SessionRunnerModel.resolve`; text-only models were unconditionally sent `image_url` blocks. Fixed upstream. |
| **#20802** `custom OpenAI-compatible providers: image file attachments do not reach vision-capable models correctly` | OPEN | Adjacent — even with a vision model, custom providers may drop image attachments. Affects any `shotput`-via-tool path using OpenAI-compatible gateways. |
| **#35879** `webfetch inline base64 images break Workers AI (Kimi)` | CLOSED | Pipeline breaks on inline base64. Reinforces "never paste base64 into chat". |
| **#36630** `支持在对话中直接显示图片` (display images directly in chat) | OPEN | Duplicate-ish feature request for the same surface. |
| **#31791** `drag-and-drop / paste of images in the question tool UI` | OPEN | User-side input path, not display — listed for completeness. |

Practical takeaway for `shotput`:
- OpenCode web display → blocked on **#21227**. Cannot work around it from user space.
- The `Read`-on-PNG → model error path is already fixed upstream (**#38144**) — upgrade if you hit it.
- Even after #21227 lands, check **#20802** for custom-provider caveats.

## Recommended design

### 1. Spool directory

```
~/shots/           # machine-global spool (any agent)
<workspace>/.shots/  # optional copy for workspace-scoped UIs + remote Paseo
```

- Content-addressed names: `<sha256-16>.png` (or full hash) to avoid collisions and allow reuse.
- Mode `0600` files, `0700` dir.
- TTL sweeper (e.g. delete files older than 24–72h).

### 2. Optional HTTP host (still useful)

Keep a **loopback-only** static server on a fixed port (e.g. `127.0.0.1:9191`):

- Handy for T3 Code web, browser tabs, debugging (`curl`, DevTools).
- **Not** sufficient alone for Paseo inline chat.
- Do **not** bind `0.0.0.0` unless intentionally exposing via Tailscale/auth.

For phone/remote: either Tailscale Serve/Funnel with auth, or skip HTTP and rely on workspace files the daemon already syncs/serves.

### 3. Agent emission contract

After writing `NAME.png`, the agent should print **both** (clients pick what works):

```markdown
![short label](.shots/NAME.png)
![short label](file:///home/jono/shots/NAME.png)
http://127.0.0.1:9191/NAME.png
```

Rules of thumb:

1. If the session has a workspace → always copy/write under `<workspace>/.shots/` and emit **relative** `.shots/…` first (best cross-client + remote).
2. Also keep a copy (or symlink) in `~/shots/` for a stable machine-wide URL and non-workspace tools.
3. Emit `file://` absolute for Paseo-local parity with provider materialization.
4. Emit HTTP last as a human-clickable / T3-friendly fallback.
5. Never paste large base64 into chat text.

### 4. Tiny CLI (later — not PoC)

```text
shotput capture.png
  → cp/hash to ~/shots/<id>.png
  → if $PWD is a git/workspace root, also copy to .shots/<id>.png
  → print the markdown block above
```

Optional: `shotput --post` to a small upload API that returns the same paths/URLs.

### 5. Skills / rules (later — not in this PoC)

One shared snippet in agent rules (Paseo, T3, Claude) pointing at `shotput` + the emission contract. See `~/shots/SKILL.md` for the draft.

## Other clients worth testing

Ranked by likely relevance to a local-agent workflow:

| Priority | Client | Why | Test status |
|---------|--------|-----|-------------|
| High | **T3 Code web** | Already in matrix; biggest gap to fill | to test |
| Medium | **LibreChat** (self-hosted) | MCP + tool-result support; image rendering unverified | to test |
| Medium | **Open WebUI** (self-hosted) | Same as LibreChat; very common local setup | to test |
| Low | **LobeChat** | Newer; image handling varies by version | to test |
| Low | **AnythingLLM** | Has a web UX; agent output rendering is bespoke | to test |
| Note | **Continue.dev / Roo Code / Cline** | IDE extensions (desktop, not browser), but VS Code's markdown renderer applies the same rules — worth a sanity test if your real surface is IDE | to test |

Not in scope: Claude.ai, ChatGPT.com, Gemini web — cloud UIs cannot reach `127.0.0.1:9191` usefully, and they're not "agent UIs on this machine".

## Suggested test checklist (copy-paste per client)

For each untested client, with `~/shots` + `.shots/` populated and HTTP on `:9191`:

- [ ] `![t](.shots/NAME.png)`
- [ ] `![t](/home/…/shots/NAME.png)`
- [ ] `![t](file:///home/…/shots/NAME.png)`
- [ ] `![t](http://127.0.0.1:9191/NAME.png)`
- [ ] raw `<img src="http://127.0.0.1:9191/NAME.png">` (expect fail on many UIs)
- [ ] `Read` on the PNG (tool image block path)

Record: **inline tile** | **clickable link only** | **broken/empty**. That freezes the `shotput` print template for that client.

## What we are *not* doing

- Replacing Paseo's provider image materialization (that path stays best for Claude/Codex tool surfaces).
- Relying on HTML injection in chat.
- Depending on OpenCode TUI / Sixel / Kitty graphics.
- Shipping a public unauthenticated image CDN.
- Trying to fix OpenCode web inline display before upstream #21227 lands.

## Open questions

1. **T3 Code web** — same five forms: B relative, C absolute, A `file://`, HTTP, optional HTML/data-URI. Mark each inline / link / broken. Then test `Read`-on-PNG (tool image block) path.
2. **OpenCode web** — confirmed no markdown-form path and no tool-image-block path renders. Watch upstream **#21227** for the unlock.
3. **LibreChat / Open WebUI** — does MCP `ImageContent` render inline? Does `![]()` work? Same matrix.
4. **Paseo remote** — does `.shots/` under the workspace load on mobile without extra work?
5. **Git hygiene** — add `.shots/` to global or per-repo gitignore.
6. **Service management** — one-liner `serve` vs systemd user unit / flox service with TTL cleanup.
7. **Security** — workspace copies are readable by anything with project access; keep secrets out of screenshots; loopback-only HTTP.
8. **Custom OpenAI providers** — does #20802 break the tool-image-block path even after #21227 lands?

## Quick reference

```sh
# start host
mkdir -p ~/shots
npx --yes serve ~/shots -l tcp://127.0.0.1:9191 --no-clipboard

# publish a capture into spool + current workspace
id=$(sha256sum capture.png | cut -c1-16)
cp capture.png ~/shots/$id.png
mkdir -p .shots && cp capture.png .shots/$id.png

# paste into agent reply (Paseo-proven first two)
# ![capture](.shots/$id.png)
# ![capture](file://$HOME/shots/$id.png)
# http://127.0.0.1:9191/$id.png
```

## Related upstream (Paseo)

- Closed: tool_result image inline rendering (#1118 / #1119 / #1717).
- Open: Codex toolSurface screenshot materialization (#2237), image-heavy timeline size (#2220).
- Open: Codex GUI attachment → vision (#1215).

This writeup is about a **user-space bridge** that works even when the provider does not emit image blocks — not a substitute for those fixes.

## Related upstream (OpenCode)

See "OpenCode web — upstream issue map" above. Headline: **#21227** is the gating issue for OpenCode web inline display.