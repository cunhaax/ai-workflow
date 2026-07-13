# [PROJECT_NAME]

Guidance for AI coding agents working in this repository. This file
(`AGENTS.md`) is the canonical copy; `CLAUDE.md` imports it via `@AGENTS.md` so
Claude Code (and its sub-agents) load it, while other tools that read
`AGENTS.md` directly still see one source of truth. Keep it lean — as the
instruction count grows, instruction-following quality degrades across *all*
instructions. Deep detail belongs in `docs/` (including `docs/adr/`) and the
code — this file is the map, not the territory.

## Rules — non-negotiable

These apply to **every** agent — the main agent and every sub-agent (planner,
plan-critic, code-critic, adversarial-qa). Nothing enforces them automatically; following
them is your responsibility.

1. **Use the project's canonical commands.** Build, run, stop, and test only
   through the documented commands (see *Commands*). If a wrapper exists
   (`make`/`just`/an npm script/…), do not invoke the underlying build tool
   directly — the wrapper may add serialisation, environment setup, or safety
   the raw tool skips. If a needed capability has no command, STOP and report
   the gap (Rule 2) rather than substituting raw shell.

2. **If a command or tool fails — or succeeds without doing what it should —
   STOP and report it; never silently work around it.** Give the user the exact
   step (command or tool call) and its full output, then wait. Do **not** retry
   with different flags/ports/tools or skip the step. Surfacing the problem is
   expected, not a failure on your part.

3. **Stay on the branch you were started on.** Commit directly onto the current
   branch. Never create, switch, or check out branches, and never
   `git worktree add` (restoring a file with `git checkout -- <path>` is fine).
   If you believe the branch must change, STOP and ask first.

4. **Get reviewed before pushing.** Never `git push` or open a PR until the
   `code-critic` sub-agent has passed with no FAIL items. After a pass, record
   it with `scripts/review-ok.sh` — the committed pre-push hook
   (`githooks/pre-push`) blocks any push whose commit does not match the
   recorded review. Any commit made after the review requires a re-review.
   (Enable once per clone: `git config core.hooksPath githooks`.)

5. <!-- [TODO: project-specific hygiene rule, if any] e.g. "Leave the database
   clean: run [DB_DOWN_CMD] before ending a session." Delete this rule if none. -->

6. **One clean command per step — use the right tool.** Use the `Read` tool for
   file contents (never `cat`/`head`/`tail`/`sed`); search with a single plain
   `grep`/`rg`/`find`. This applies to every command, reading or acting: no
   leading `cd` (pass a path instead), and no `;`/`&&` chaining, `for`-loops, or
   `$(…)` glue. Need several things? Issue separate (parallel) tool calls, not
   one compound command. It keeps the transcript readable and sidesteps the
   permission prompts that compound and `cd`-prefixed commands trigger.

## Project Overview

<!-- [TODO: one paragraph — what this project is, its purpose, and how it fits
the broader system. Name the stack: language/framework versions, key
dependencies, infrastructure.] -->

**Before building features, read the product docs** in `docs/product-context/`
(vision, strategy, requirements). Architecture decision records are in `docs/adr/`.
Sub-agent definitions and the coding-standard skills are in `.claude/agents/`
and `.claude/skills/`.

## Commands

<!-- Replace with YOUR project's canonical commands. Keep them behind a wrapper
     (make/just/npm script/…) if one adds serialisation or environment setup. -->

- `[BUILD_CMD]` — build
- `[TEST_CMD]` — run all tests
- `[CHECK_CMD]` — all checks incl. tests
- `[RUN_CMD]` — dev server
- `[STOP_CMD]` — stop the dev server
- single test: `[SINGLE_TEST_EXAMPLE]`

## Architecture

<!-- [TODO: package/module layout and the load-bearing design constraints. A
reader should learn where each kind of code lives and the rules that must not be
broken. Keep it to the map — link docs/ and docs/adr/ for depth.] -->

```
[TODO: directory tree with a one-line purpose per top-level module]
```

## Testing

<!-- [TODO: test framework, conventions, where tests live, how to run one.] -->

## Sensitive Areas — the security surface

The canonical list of files/areas where mistakes are expensive. The `/feature`
workflow consults it at three points: the plan-critic skip criteria (Step 1b),
reviewer model escalation (Step 4), and the PR security flag (Step 9). Keep
the list short and concrete; if the rationale for an entry needs more than a
line, link a page under `docs/` for the depth rather than expanding here.

<!-- [TODO: one bullet per area — e.g. security config, auth/token/session
handling, route definitions, sensitive data fields and their rendering paths,
payment flows, schema migrations. Name concrete files/packages so an agent
can match a diff against them.] -->

- [TODO: sensitive area 1 — concrete file/package/pattern]
- [TODO: sensitive area 2]

## Workflow for New Features

Use the `/feature` slash command for non-trivial work: plan → critique →
implement → test → code-review → QA → PR, with explicit gates. Full definition
in the `/feature` skill (`.claude/skills/feature/SKILL.md`); full guide in
`docs/AI-workflow.md`.
