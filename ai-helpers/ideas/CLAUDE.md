# Personal Preferences

- When reporting information to me, be extremely concise and sacrifice grammar for the sake of concision
- Always strive for concise, simple solutions.
- If a problem can be solved in a simpler way, propose it.
- If asked to do too much work at once, stop and state that clearly.

## Python

- When adding import to python, prefer the top of the file instead of doing it locally in a function.

## TypeScript

- Never use 'any' unless 100% necessary or specifically instructed.

## Commands

- I use flox in my local development for most projects. So you may need to prefix command with a 'flox activate'.
- direnv is used to load env vars and setup in different subdirectories. For the most part this should be setup to work automatically.
- Don't run build commands unless specifically told to.
- Focus on checking commands like 'just lint', etc.

## Exhausting tokens

- If you are about to run out of tokens and need to wait for hours to be used again, dump a handoff document so I can pass that to another LLM to take over.

## Picking the right models for workflows and subagents

Rankings, higher is better. Intelligence is how hard a problem you can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

| model     | cost | intelligence | taste |
| --------- | ---- | ------------ | ----- |
| MiniMax-3 | 9    | 5            | 5     |
| sonnet    | 5    | 6            | 7     |
| opus      | 4    | 7            | 8     |
| fable     | 2    | 9            | 9     |

These are defaults, not limits. You have standing permission to override them: if a change to a model's output doesn't meet the bar, rerun or redo the work with a smarter model without asking.

- Don't let cost prevent you from using the right model for the job. Instead, take advantage of cheaper options to get more information and try things before moving the work to a more expensive option.
- Bulk/mechanical work (clear-spec implementation, data analysis, migrations): minimax — it's effectively free.
- Anything user-facing (UI, copy, API design) needs taste > 7.
- Reviews of plans/implementations needs intelligence >= 7, optionally use others as an extra independent perspective.
- Label subagents with the real worker model as a prefix, e.g. {label: 'opus:judge-auth'} — the UI doesn't show per-agent models, so labels are the audit trail. Especially important for wrapped non-Claude workers.
- Claude models run via the Agent/Workflow model parameter (values: sonnet, opus, fable).
- MiniMax is reachable via opencode cli. Example call:
  opencode run --model="minimax-coding-plan/MiniMax-M3" "make this class more DRY"
- Inside agents/workflows, non-Claude models run via a thin Claude wrapper (model: sonnet or haiku, effort: low) whose prompt says: write a self-contained prompt for the worker, run it via Bash, return the report. Use schema on the wrapper for structured output.
  - MiniMax: wrapper runs `opencode run --model="minimax-coding-plan/MiniMax-M3" "<prompt>"`
