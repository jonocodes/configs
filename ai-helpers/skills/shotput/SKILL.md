# shotput — agent screenshot emission contract

**Purpose:** when an agent captures a screenshot on this machine and wants the user to see it inline in chat, it publishes the PNG once and emits a small, ordered markdown block. Clients that render images pick the form they support; the rest degrade to a clickable link. Full R&D / per-client matrix / upstream blockers: `~/shots/RESEARCH.md`.

This file is the concise spec for agent ingestion (paste into rules/skills). It does **not** require the `shotput` CLI to exist yet — agents can follow this contract by hand.

## Paths

| Role | Path | Mode |
|------|------|------|
| Machine-global spool | `~/shots/<id>.png` | `0600` file, `0700` dir |
| Workspace copy (if `$PWD` is a workspace root) | `<workspace>/.shots/<id>.png` | `0600` file, `0700` dir |
| Loopback HTTP (optional, host-run) | `http://127.0.0.1:9191/<id>.png` | server binds `127.0.0.1` only |

- `<id>` = first 16 hex chars of `sha256sum` of the PNG (content-addressed; reuse-safe).
- Always write to `~/shots/`. Also write to `<workspace>/.shots/` if a workspace is in scope.
- Never bind HTTP on `0.0.0.0`.

## URL discovery (tailnet / LAN host)

The HTTP hostname should be **discovered at runtime**, not hardcoded — the agent may be running on a different host next time.

```sh
TS_HOST=$(tailscale status --json 2>/dev/null | jq -r '.Self.HostName // empty' \
       || hostname 2>/dev/null) ; \
TS_HOST=${TS_HOST:-127.0.0.1}
SHOTS_URL="http://$TS_HOST:9191"
```

`tailscale` not installed → falls back to `hostname` → then `127.0.0.1`. On `lute` this resolves to `http://lute:9191`, reachable from any device on the same tailnet (including phones via Tailscale).

## Emission — two variants by client capability

### Variant A: clients that inline images (Paseo local)

Print all three lines, in this order:

```markdown
![label](.shots/<id>.png)
![label](file://$HOME/shots/<id>.png)
http://$TS_HOST:9191/<id>.png
```

Substitute the real absolute home path — never leave `…` or `$HOME` unresolved.

Why this order:
1. **workspace-relative** (`B`) — best cross-client + survives remote Paseo.
2. **file:// absolute** (`A`) — matches Paseo's provider materialization path.
3. **HTTP tailnet** (`H`) — human-clickable / browser-style client fallback.

### Variant B: clients that don't inline images (OpenCode web)

Skip the `![]()` forms entirely — they render broken. Print only:

```markdown
[label](http://$TS_HOST:9191/<id>.png)
http://$TS_HOST:9191/<id>.png
```

Both render as clickable links. Verified working from phone over Tailscale.

See "**How to know which variant**" below.

## Per-client quick lookup

| Client | Variant | What works |
|--------|---------|------------|
| Paseo desktop/web (local) | A | `B`, `A`, `C` (absolute path without scheme) all inline. `H` = link only. |
| Paseo remote/mobile | A | Guess: `B` only. Use discovered tailnet hostname for the HTTP fallback. |
| OpenCode web | **B** | **No inline rendering** (markdown or tool image blocks). Blocked on upstream **#21227**. Use clickable link forms only — `http://$TS_HOST:9191/<id>.png` (tested from phone over Tailscale). |
| T3 Code web | ? | Unknown — to test. Start with Variant A. |
| LibreChat / Open WebUI / LobeChat / AnythingLLM | ? | Unknown — to test. |

When in doubt, emit Variant A. Worst case the user clicks the HTTP link.

### How to know which variant

- If you're running inside OpenCode (any version pre-#21227), use Variant B.
- Default to Variant A for everything else.
- A future `shotput` CLI can take a `--client` flag or auto-detect (e.g. `OPENER_CLIENT=opencode-web` env var).

## Don'ts

- Don't paste base64 / data-URI image payloads into chat text (blows message caps; breaks some pipelines — see OpenCode #35879).
- Don't rely on raw `<img src=…>` HTML — virtually every agent markdown renderer strips it.
- Don't bind the HTTP host on `0.0.0.0` unless you've added auth + Tailscale.
- Don't emit OpenCode TUI / Sixel / Kitty image protocols — out of scope.
- Don't put screenshots containing secrets in the spool dir.

## Publishing a capture (without `shotput` CLI)

```sh
id=$(sha256sum capture.png | cut -c1-16)
mkdir -p ~/shots .shots
cp capture.png ~/shots/$id.png
cp capture.png .shots/$id.png
# Optional HTTP host (start once in background):
#   npx --yes serve ~/shots -l tcp://127.0.0.1:9191 --no-clipboard \
#     >/tmp/shots-serve.log 2>&1 &
```

Then emit the three-line markdown block above.

## For agent-rules/skills authors

The contract above is the whole skill. Avoid wrapping it in heavy tooling until the matrix in `RESEARCH.md` is filled for the clients you actually use — emission order may shift (e.g. OpenCode web may switch to tool-image-blocks once #21227 lands). Keep this file as the source of truth and link agents here.