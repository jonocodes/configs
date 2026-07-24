adapted on 7/9/26 from https://www.youtube.com/watch?v=8GRmLR__OGQ&t=870s

> opencode run --model="minimax-coding-plan/MiniMax-M3" "whats cool?"

# Personal Preferences

- Picking the right models for workflows and subagents.
- When reporting information to me, be extremely concise and sacrifice grammar for the sake of concision

<!--
## Python

- Use type hints.
- When adding import to python, prefer the top of the file instead of doing it locally in a function.

## TypeScript

- Never use 'any' unless 100% necessary or specifically instructed.
- Use pnpm if the project already uses it, otherwise use bun.
- Never use ape or yarn

## Tech Stack Preferences

When uncertain, prefer: Tailwind, TypeScript, Bun, React. -->

## Commands

<!-- - Don't run dev server commands (e.g., 'bun run dev) - assume its already running. -->

- I use flox in my local development for most projects. So you may need to prefix command with a 'flox activate'.
- direnv is used to load env vars and setup in different subdirectories. For the most part this should be setup to work automatically.
- Don't run build commands unless specifically told to.
- Focus on checking commands like 'just lint', etc.

## Code Style

- Always strive for concise, simple solutions.
- If a problem can be solved in a simpler way, propose it.

## General preferences

- If asked to do too much work at once, stop and state that clearly.
- If computer use is helpful for completing or verifying work, shell out to gpt-5.5 with Codex for it

## Exhausting tokens

- If you are about to run out of tokens and need to wait for hours to be used again, dump a handoff document so I can pass that to another LLM to take over.

## Picking the right models for workflows and subagents

Rankings, higher. m better. Cost reflects mil. I actually pay (OpenAI is near-free for me due to a deal), not list price. Intelligence is how hard a problem you can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

I model I cost I intelligence I taste |
——————————————————-
| minimax-2.7 | 9 | 5 | 5 |
| gpt-5.5 | 5 | 5| 7 |
| sonnet-5 | 5 | 6 | 7 |
| opus-4.8 | 4 | 7 | 8 |
| fable-5 | | 2 | 9 | 9 |

These are defaults, not limits. You have standing permission to override them: if a change to a model's output doesn't meet the bar, rerun or redo the work with a smarter model without asking. Judge the output, not the price tag. Escalating costs less than shipping mediocre work.

- Don't let cost prevent you from using the right model for the job. Instead, take advantage of cheaper options to get more information and try things before moving the work to a more expensive option.
  -Bulk/mechanical work (clear-spec implementation, data analysis, migrations): gpt 5.5 — it's
  effectively free.
- Anything user-facing (UI, copy, API design) needs taste > 7.
- Reviews of plans/implementations: fable-5 or opus-4.8, optionally gpt-5.5 as an extra independent perspective.
- Never use Haiku.
- Mechanics: gpt-5.5 is only reachable through the Codex CLI -— ‘codex exec’ / ‘codex review (my ~/.codex/config.toml defaults to gpt-5.5). Use the codex—implementation, codex-review, and codex-computer-use skills; for work they don't cover (investigation, data analysis), run “codex exec -s read-only’ directly with a self-contained prompt.

- Claude models (sonnet-5, opus-4.8, fable-5) run via the Agent/Workflow model parameter.

Using gpt-5.5 inside workflows and subagents (the model parameter only takes Claude mode so use a wrapper):

- Spawn a thin Claude wrapper agent with 'model: 'sonnet', effort: 'low" whose prompt instructs it to write a self contained codex prompt, run 'codex exec' via Bash, and return the report (use 'schema' on the wrapper to get structured output back).
  — Always label these agents with a 'gpt-5.5:' prefix, e.g. '{label: 'gpt-5.5:review—auth'}' the workflow UI shows the wrapper's Claude model, so the label is the only indication the real worker is gpt-5.5.
  — Codex runs can exceed Bash's 10—minute timeout: pass an explicit timeout, or run in the background and poll for the report file.
  — Parallel gpt-5.5 implementation agents must use 'isolation: 'worktree" so codex edits don't collide in the shared checkout.
  — Workflow token budgets only count Claude tokens; codex work is free and invisible to 'budget.spent()'.
