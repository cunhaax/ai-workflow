---
name: feature
description: >
  Runs the full AI-assisted workflow for a non-trivial feature or change:
  plan, plan critique, user approval, tests-first implementation, code
  review, exploratory QA, and PR. Use when the user asks to build or start a
  feature, or to implement a change that needs a plan, review, and PR. Every
  planning run saves the approved plan to a file; with `--plan-only` it stops
  there, and `--from-plan <slug>` runs such a saved plan without re-planning.
license: MIT
metadata:
  author: André Cunha
---

# /feature

Pipeline: plan → critique → implement → test → code-review → QA → PR.
Run steps in order, skipping only where a step or the mode says so.
`AGENTS.md` is the source for commands, default branch, sensitive areas, and
task tracking.

`planner`, `plan-critic`, `code-critic` and `adversarial-qa` below are
sub-agents: "call" means spawn the sub-agent of that name, never load the
same-named skill into your own context (you would be reviewing your own work).

## Input

- User prompt (verbatim, including any doc/link references)
- Session branch: a feature branch, not the default branch (any branch with
  `--plan-only`)

## Phases

The steps live in files in `${CLAUDE_SKILL_DIR}/`, the directory of this
skill. Read each with `Read` when its phase starts:

- `plan.md`: step 1 (1a–1d), from prompt to saved plan
- `from-plan.md`: loads a saved plan, in place of step 1
- `build.md`: steps 2–9, from implementation to PR
- `plan-file.md`: the saved plan file (location, save, rewrite, mark
  consumed); read where a step points to it

The mode is set by the first token of the arguments; a flag anywhere else is
prompt content, passed on verbatim:

| First token | Runs |
|---|---|
| `--plan-only` | `plan.md`, stopping after 1d |
| `--from-plan` | `from-plan.md` → `build.md` |
| anything else | `plan.md` → `build.md` |

- An unexpanded `${CLAUDE_SKILL_DIR}`, or a phase file you can't read → STOP
  per `AGENTS.md` Rule 2; never work from memory of it
- Re-read the current phase file whenever it is no longer fully in your
  context (e.g. after compaction), and read a file before following a
  pointer into it
- Step numbers are the same across files: steps 1a–1d are in `plan.md`,
  steps 2–9 in `build.md`

## Output

- Open PR with the description and the first comment from step 9, and the
  plan file marked consumed (`--plan-only`: the plan file's absolute path
  instead of a PR)
- Summary of skipped steps, plan deviations, `context7` lookup failures, and why

## Rules

- Never skip `planner` for a new feature (`--from-plan` runs a plan that
  already went through it)
- Never skip `plan-critic` unless all step 1b criteria hold AND the user opted
  out (`--from-plan` re-runs it only when the base moved)
- Never leave a source the prompt references unread: read it yourself and
  pass it to the `planner` verbatim; the planner never fetches
- Never enter plan mode from a sub-agent
- Never present work to the user before `code-critic` has reviewed it
- Relay ALL `NEEDS_DECISION` items and Open Questions to the user; never
  decide them
- Sub-agents never modify the project's code; only the main agent implements
  changes (`adversarial-qa` also writes `.qa-evidence/`)

<!-- SKILL NAMING NOTE (Claude Code): the skill is named `code-critic` so it
     does NOT shadow Claude Code's bundled `code-review` skill (project
     skills shadow bundled ones). `/code-review ultra` stays reachable as an
     optional, user-launched deep pass. Do not rename back. -->
