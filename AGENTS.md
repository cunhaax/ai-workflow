# AI Workflow Template

Guidance for AI coding agents working in this repository. This file
(`AGENTS.md`) is the canonical copy; `CLAUDE.md` imports it via `@AGENTS.md` so
Claude Code (and its sub-agents) load it, while other tools that read
`AGENTS.md` directly still see one source of truth. Keep it lean — as the
instruction count grows, instruction-following quality degrades across *all*
instructions. Deep detail belongs in `docs/` and the code — this file is the
map, not the territory.

## Rules — non-negotiable

These apply to **every** agent — the main agent and any sub-agents it
invokes. Nothing enforces them automatically; following them is your
responsibility.

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
   If you believe the branch must change, STOP and ask first. Feature work
   assumes the **human** starts the session on a fresh feature branch — the
   code review diffs against the default branch and the PR targets it, neither
   of which works from the default branch itself. If you start on the default
   branch, STOP and ask before planning.

4. **Get reviewed before pushing.** Never `git push` or open a PR without a
   recorded passing review of the current commit — no unresolved critical
   issues. Record it with `scripts/review-ok.sh` — the committed pre-push hook
   (`githooks/pre-push`) blocks any push whose commit does not match the
   recorded review. Any commit made after the review requires a re-review.
   (Enable once per clone: `git config core.hooksPath githooks`.) See
   `docs/AI-workflow.md` for how this project obtains that review.

5. **Keep `templates/` and `docs/AI-workflow.md`'s file tree in sync.**
   `.claude/skills/init-workflow/templates/` is the canonical enumeration of
   what a scaffolded project receives — `/init-workflow` reads it directly.
   The file tree in `docs/AI-workflow.md` is a human-readable mirror of it,
   not a second source; adding, removing, or renaming a file under
   `templates/` must be reflected there too.

6. **One clean command per step — use the right tool.** Use the `Read` tool for
   file contents (never `cat`/`head`/`tail`/`sed`); search with a single plain
   `grep`/`rg`/`find`. This applies to every command, reading or acting: no
   leading `cd` (pass a path instead), and no `;`/`&&` chaining, `for`-loops, or
   `$(…)` glue. Need several things? Issue separate (parallel) tool calls, not
   one compound command. It keeps the transcript readable and sidesteps the
   permission prompts that compound and `cd`-prefixed commands trigger.

## Project Overview

This repo **is** the AI-Assisted Development Workflow template — a Claude
Code plugin providing the skills and sub-agents (planner, plan-critic,
code-critic, adversarial-qa) that structure AI-assisted development as
plan → critique → implement → test → review → QA → PR, with a deterministic
pre-push review gate below the LLM layer. `docs/AI-workflow.md` is the full
design rationale; `README.md` is the quick-start for installing it into
another project. There is no separate product-context/ADR set for this repo
itself — `docs/AI-workflow.md` fills that role, and the placeholder versions
of those directories live only in `.claude/skills/init-workflow/templates/`
(what a scaffolded project receives), not at this repo's own root.

## Commands

No build step — this is a documentation/skills/scripts repo, nothing to
compile and no app to run or stop. There is no automated test suite either:
skill and sub-agent bodies are agent-interpreted prose, not executable code.
The shell scripts under `githooks/` and `scripts/` are plain POSIX `sh`,
kept small and reviewed by hand.

- default branch: `master` — reviews diff against it; PRs target it

## Architecture

```
.claude/
├── settings.json                 # Symlink into .claude/skills/init-workflow/templates/settings.json.template
├── agents/                       # Sub-agent definitions (planner, plan-critic, code-critic, adversarial-qa)
└── skills/                       # Reusable knowledge: feature, plan-draft, plan-critic, code-critic,
    │                              #   adversarial-qa, init-workflow, workflow-retro, workflow-inspect
    └── init-workflow/templates/  # THE scaffold source a fresh project's /init-workflow reads
docs/
├── agent-rules/                  # This repo's own real review rules + risk lenses
└── AI-workflow.md                # Full design rationale and file-by-file guide
githooks/pre-push                 # Symlink into .claude/skills/init-workflow/templates/githooks/pre-push
scripts/review-ok.sh              # Symlink into .claude/skills/init-workflow/templates/scripts/review-ok.sh
README.md                         # Quick-start for installing the plugin into another project
```

`.claude/settings.json`, `githooks/pre-push`, and `scripts/review-ok.sh` are
symlinks, not copies — they must never differ from what a scaffolded
project receives, so there is exactly one copy of their content, inside
`templates/`. This assumes a POSIX clone (`core.symlinks` enabled): on a
checkout where git materializes symlinks as plain text files, `pre-push`
and `review-ok.sh` fail loudly (not executable, won't run) but a degraded
`.claude/settings.json` fails silently — it stops being valid JSON, so its
`deny` rules on the push-bypass flags quietly disappear rather than erroring.
`/init-workflow`'s doctor checklist (item 5) catches this on a re-run by
checking the file actually contains those rules, not just that it exists.

## Testing

No automated tests. Verification is manual: dogfooding this repo's own
workflow on changes to itself (`/feature`, `/code-critic`, `/plan-critic`),
and — for changes to `.claude/skills/init-workflow/templates/` specifically —
a manual walkthrough confirming a freshly scaffolded project ends up correct
(see `docs/AI-workflow.md`, *Evolving the System*).

## Sensitive Areas — the security surface

- `.claude/skills/init-workflow/templates/` — this is what every scaffolded
  project's enforcement mechanism and starting rules are built from; an
  error here propagates silently to every downstream project.
- `githooks/pre-push` / `scripts/review-ok.sh` (via their symlink target in
  `templates/`) — the actual review-gate enforcement; a bug here is a
  silent bypass everywhere the template is used.
- `.claude/skills/init-workflow/SKILL.md` — the scaffold logic itself; it
  writes files into a project on the user's behalf.
