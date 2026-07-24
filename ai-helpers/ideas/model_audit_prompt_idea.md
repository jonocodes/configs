Suggestion: build a model-audit tool — a small script that parses ~/.claude/projects/\*_/_.jsonl and prints which model each session/agent actually used. It's ~100 lines, genuinely useful (fills the visibility gap we found), and its output verifies the experiment itself: when the workflow finishes, run the tool and check the routing happened as intended.

Run it as one workflow with 4 phases, each phase deliberately hitting a different path:

1. Plan — opus agent designs the jsonl parsing approach + output format (review/plan path, intelligence ≥ 7). Label opus:plan.
2. Implement — MiniMax via the wrapper (clear-spec mechanical work): thin sonnet wrapper, effort low, runs opencode run --model="minimax-coding-plan/MiniMax-M3" "<self-contained spec from phase 1>". Label minimax:impl-parser. Tests the wrapper mechanics + schema-structured return.
3. Polish output — fable agent makes the CLI output/report nice (user-facing, taste > 7). Label fable:output-design.
4. Review — opus reviews the implementation; optionally a second independent perspective via another wrapper. Label opus:review.

What it exercises: model param per agent, both wrapper paths, label convention, phases, schema output, and pipeline vs barrier (2→3→4 is sequential, so it also shows where a workflow is overkill — good calibration data).

Then the payoff loop: run the freshly built tool against this session's transcript dir and see whether the labels/models line up with what the jsonl recorded. If the label convention or wrapper misbehaved, the tool you just built shows it.

Say go and I'll write and launch the workflow.
