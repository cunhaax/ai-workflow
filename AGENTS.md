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

5. **Keep `templates/` in sync with what describes it — and never strip a
   `.template` suffix on the source copy itself.**
   `plugins/ai-workflow/skills/init-workflow/templates/` is the canonical
   enumeration of what a scaffolded project receives — `/init-workflow`
   reads it directly. The file tree and `.template` → destination mapping in
   `docs/AI-workflow.md`, and the `init-workflow/templates/` enumeration
   paragraph in `README.md`, are human-readable mirrors of it, not a second
   source; adding, removing, or renaming a file under `templates/` must be
   reflected in all three. The suffix on `AGENTS.md.template`/
   `CLAUDE.md.template` is what stops Claude Code from auto-loading them as
   *this repo's own* live guidance — renaming either to drop the suffix
   inside `templates/` (as opposed to on a scaffolded project's destination
   copy, where dropping it is correct) would have that placeholder-riddled
   file silently take over the next time anyone works in `templates/`.

6. **One clean command per step — use the right tool.** Use the `Read` tool for
   file contents (never `cat`/`head`/`tail`/`sed`); search with a single plain
   `grep`/`rg`/`find`. This applies to every command, reading or acting: no
   leading `cd` (pass a path instead), and no `;`/`&&` chaining, `for`-loops, or
   `$(…)` glue. Need several things? Issue separate (parallel) tool calls, not
   one compound command. It keeps the transcript readable and sidesteps the
   permission prompts that compound and `cd`-prefixed commands trigger.

## Project Overview

This repo **is** the AI-Assisted Development Workflow plugin's source — a
Claude Code plugin providing the skills and sub-agents (planner, plan-critic,
code-critic, adversarial-qa) that structure AI-assisted development as
plan → critique → implement → test → review → QA → PR, with a deterministic
pre-push review gate below the LLM layer. `docs/AI-workflow.md` is the full
design rationale; `README.md` is the quick-start for installing it into
another project. There is no separate product-context/ADR set for this repo
itself — `docs/AI-workflow.md` fills that role, and the placeholder versions
of those directories live only in
`plugins/ai-workflow/skills/init-workflow/templates/` (what a scaffolded
project receives), not at this repo's own root.

This repo has no project-local skills or sub-agents of its own —
`.claude/skills/`/`.claude/agents/` don't exist here. `plugins/ai-workflow/`
is the one real source; if you want `/feature` etc. available while working
on this repo, install the plugin the same way any consumer would (see
*Installing into a project* in `README.md`), rather than relying on
special-cased project-local copies. That's deliberate, not an oversight:
project-local symlinks back into `plugins/ai-workflow/` were considered and
rejected, because with the plugin also installed globally, Claude Code
would show both bare `/feature` (project-local) and `/ai-workflow:feature`
(the installed plugin) at once — two command surfaces for the same thing,
with no way to know if they'd drifted.

A GitHub-form install (`/plugin marketplace add cunhaax/ai-workflow-template`)
sources from the published repo's default branch, not this working tree or
whatever feature branch you're on — so it doesn't dogfood in-progress
changes. To actually review working-tree edits to the plugin itself, use
the local-path form instead (see *Installing into a project* in
`README.md`).

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
└── settings.json                     # Symlink into plugins/ai-workflow/skills/init-workflow/templates/settings.json.template
.claude-plugin/
└── marketplace.json                  # Lists this repo's one plugin (self-referential: ai-workflow@ai-workflow)
plugins/ai-workflow/
├── .claude-plugin/plugin.json        # Plugin metadata (name, version, author, homepage, repository, license)
├── agents/                           # Sub-agent definitions (planner, plan-critic, code-critic, adversarial-qa)
└── skills/                           # Reusable knowledge: feature, plan-draft, plan-critic, code-critic,
    │                                  #   adversarial-qa, init-workflow, workflow-retro, workflow-inspect
    └── init-workflow/templates/      # THE scaffold source a fresh project's /init-workflow reads
docs/
├── agent-rules/                      # This repo's own real review rules + risk lenses
└── AI-workflow.md                    # Full design rationale and file-by-file guide
githooks/pre-push                     # Symlink into plugins/ai-workflow/skills/init-workflow/templates/githooks/pre-push
scripts/review-ok.sh                  # Symlink into plugins/ai-workflow/skills/init-workflow/templates/scripts/review-ok.sh
LICENSE                               # MIT
README.md                             # Quick-start for installing the plugin into another project
```

`.claude/settings.json`, `githooks/pre-push`, and `scripts/review-ok.sh` are
symlinks, not copies — they must never differ from what a scaffolded
project receives, so there is exactly one copy of their content, inside
`templates/`. This assumes a clone where git materializes them as real
symlinks; exact failure behavior on a checkout where it doesn't is
platform-dependent and not verified here. `/init-workflow`'s doctor
checklist is the safety net regardless of platform: items 1 and 2 check
that `githooks/pre-push` and `scripts/review-ok.sh` exist and are
executable, and item 5 checks that `.claude/settings.json` actually
contains its `ask`/`deny` rules rather than merely existing — so a degraded
materialization of any of the three surfaces on the next `/init-workflow`
run.

## Testing

No automated tests. Verification is manual: install the plugin (see
*Installing into a project* in `README.md`) and dogfood this repo's own
workflow on changes to itself (`/feature`, `/code-critic`, `/plan-critic`),
and — for changes to `plugins/ai-workflow/skills/init-workflow/templates/`
specifically — a manual walkthrough confirming a freshly scaffolded project
ends up correct (see `docs/AI-workflow.md`, *Evolving the System*).

## Sensitive Areas — the security surface

- `plugins/ai-workflow/skills/init-workflow/templates/` — this is what
  every scaffolded project's enforcement mechanism and starting rules are
  built from; an error here propagates silently to every downstream
  project.
- `githooks/pre-push` / `scripts/review-ok.sh` (via their symlink target in
  `templates/`) — the actual review-gate enforcement; a bug here is a
  silent bypass everywhere the template is used.
- `plugins/ai-workflow/skills/init-workflow/SKILL.md` — the scaffold logic
  itself; it writes files into a project on the user's behalf.
- `.claude-plugin/marketplace.json` /
  `plugins/ai-workflow/.claude-plugin/plugin.json` — a broken manifest
  breaks installation for everyone.

## Review & Planning Guidance

- Code review guidance: `docs/agent-rules/code-critic.md`
- Planning guidance: `docs/agent-rules/plan-critic.md`
