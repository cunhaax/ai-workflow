---
name: init-workflow
description: >
  Bootstraps and validates the AI workflow in a project that has this
  plugin installed: scaffolds project-owned files on first run, detects the
  project's commands, fills AGENTS.md, seeds docs/agent-rules/, and verifies
  the review gate. Re-run any time as a doctor — it reports what is missing
  or drifted. (Named init-workflow so it does not collide with Claude Code's
  built-in /init command, which generates a CLAUDE.md.)
---

# /init-workflow — Bootstrap and Validate the Workflow

Run this skill inside a project once this plugin is installed. On a brand
new project it scaffolds the project-owned files from this skill's bundled
templates, then fills them with *this* project's facts, interactively, and
verifies the setup end to end. It is idempotent — re-run it after a plugin
update or whenever setup drift is suspected, and it acts as a doctor,
reporting what is missing rather than redoing what is already filled.

**Division of labor:** this skill scaffolds, adapts, and validates
project-owned files. It never edits the plugin's own mechanism — the
skills, sub-agents, and the plugin's own documentation are off limits;
updates to those come from updating the plugin itself, not from this skill.

**Ground rules:**

- **Propose, then write.** Every value you detect is a proposal until the
  user confirms it. Batch the confirmations (one round for the initial
  scaffold, one for commands, one for AGENTS.md sections, one for
  agent-rules) instead of asking one question at a time. Never invent facts
  about the project; where the user defers, leave an explicit `[TODO: …]`
  rather than a guess.
- **Keep `AGENTS.md` lean.** You are filling a map, not writing the
  territory — one line per command, one line per module, one bullet per
  sensitive area. Depth belongs in `docs/`.

---

## Step 1 — Scaffold if needed, then assess the current state

If `AGENTS.md` does not exist, this is a brand-new project: propose
scaffolding every file under `${CLAUDE_SKILL_DIR}/templates/` to its
project-relative destination (this is the plugin's canonical enumeration —
see the file tree in the plugin's own documentation, kept in sync with this
directory by rule) — stripping the `.template` suffix from
`AGENTS.md.template`, `CLAUDE.md.template`, and `settings.json.template`
(the last one lands at `.claude/settings.json`), preserving the executable
bit on `githooks/pre-push` and `scripts/review-ok.sh`, and copying every
other file (the `docs/` tree, `.github/workflows/ci.yml.example`) to the
same relative path it has under `templates/`. Also append `.review-passed`,
`.qa-evidence/`, and `.workflow-log/` to `.gitignore` if not already present
(create the file if it doesn't exist) — these are what the workflow writes
locally and Step 5 checks for. Present the full file list in one block —
the same confirm-then-write pattern as every other step here — before
writing anything. Once written, continue below as first-run mode.

Read `AGENTS.md`, `docs/agent-rules/code-critic.md`, and
`docs/agent-rules/plan-critic.md`. Classify each placeholder / `[TODO: …]`
as filled or open.

- Mostly open → **first-run mode**: continue with Steps 2–4, then validate.
- Mostly filled → **doctor mode**: skip to Step 5, then report only what is
  open or drifted.

## Step 2 — Detect the commands, propose, confirm

Inspect the project's build configuration — whichever exist:
`package.json` scripts, `Makefile`, `justfile`, `build.gradle(.kts)`,
`pom.xml`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`,
`docker-compose.yml`. From them, propose values for every entry in
`AGENTS.md` → *Commands*:

- build / run-all-tests / all-checks / dev server / stop / single-test
  example. Prefer wrapper commands (`make …`, npm scripts, `just …`) over
  raw tools — the wrapper may add environment setup the raw tool skips.
- app URL: from the dev-server config (port, host) if discoverable.
- default branch: `git symbolic-ref refs/remotes/origin/HEAD` (fall back to
  asking).

Present the full proposed Commands list in one block for the user to
confirm or correct. Flag any entry you could not derive — a missing stop
command or check command is common and worth an explicit decision (the
adversarial-qa and feature skills depend on them). After confirmation,
write the section, replacing the placeholders.

## Step 3 — Fill the remaining AGENTS.md sections

For each still-open section, draft from evidence and confirm before writing:

- **Project Overview**: draft one paragraph from the project's README and
  manifest (purpose, stack, key dependencies). Replace `[PROJECT_NAME]`
  in the title.
- **Architecture**: generate the top-level directory tree (source dirs
  only — skip vendored/build output) with a one-line purpose per module,
  inferred from its contents. Ask the user to correct wrong inferences —
  a wrong map is worse than no map.
- **Testing**: name the framework(s) found, where tests live, and how to
  run one (mirrors the single-test command).
- **Sensitive Areas**: propose candidates by scanning for the usual
  expensive-mistake surfaces — auth/session/token code, security config,
  route definitions, payment or billing flows, schema migrations, personal
  data fields and their rendering paths, secret/config loading. One bullet
  per confirmed area, naming a concrete file/package/pattern. This list
  gates three workflow decisions (critic-skip, reviewer model escalation,
  PR security flag) — an empty list disables those protections, so if the
  user has no time now, leave the TODO in place and say so in the report.
- **Rule 5** (project hygiene rule): ask whether one applies (e.g. reset a
  dev database at session end); fill it or delete the placeholder.

## Step 4 — Seed docs/agent-rules/

Interview briefly — a few questions, not a form:

- Does the app hold personal data? Which categories are sensitive, and is
  there a compliance doc? Which surfaces are public/unauthenticated? Any
  identifiers public by design? Do any of the three privacy fitness tests
  already exist?
  → draft the *Privacy anchors* section of `docs/agent-rules/code-critic.md`.
- Any hard constraints the team already knows agents get wrong (framework
  conventions, forbidden APIs, required registrations)?
  → draft them as rules with severities, mirrored in the *Checklist* section.
- What are this product's highest-risk areas — the places where a generic
  plan would miss something that matters here?
  → draft 4–7 lenses for `docs/agent-rules/plan-critic.md`.

Then present the drafted content of both files in one block for
confirmation before writing them — the same confirm-then-write pattern as
Steps 2 and 3; an answered question is input to the draft, not approval of
it. It is fine for these files to start thin — they are designed to accrete
(see *Evolving the System* in the AI Workflow plugin's own documentation).
Record only what the user confirms; keep the guidance comments in the files
for future additions.

## Step 5 — Validate the setup (doctor checklist)

Check each item and collect the results — fix only with the user's
confirmation, report what you cannot fix:

1. `githooks/pre-push` and `scripts/review-ok.sh` exist and are executable.
2. The pre-push review gate is active: resolve `git config core.hooksPath`
   (absolute as-is, relative against repo toplevel) and check for an
   executable `pre-push` there — don't compare the raw config value to the
   literal string `githooks` (a worktree can inherit an absolute
   `core.hooksPath` from the main checkout's shared config that resolves
   correctly but never equals that literal; see `scripts/review-ok.sh` for
   the resolution logic to mirror — replicate it, don't run that script for
   this check, since executing it has the side effect of recording a review
   pass). If no executable `pre-push` resolves, offer to run
   `git config core.hooksPath githooks` (per clone; each teammate needs it).
3. `CLAUDE.md` exists and contains `@AGENTS.md`.
4. `.gitignore` covers `.review-passed`, `.qa-evidence/`, and
   `.workflow-log/`.
5. `.claude/settings.json` has the `ask` rules for `scripts/review-ok.sh`
   and the `deny` rules for the push-bypass flags.
6. CI: `.github/workflows/ci.yml` exists — or only the `.example` does,
   in which case remind that renaming and filling it is still open (CI is
   the workflow's independent test evidence).
7. No unfilled placeholder remains in `AGENTS.md` → *Commands* (other
   sections may legitimately keep TODOs the user deferred).

## Step 6 — Report

End with a short summary: what was written (file by file), what was
deliberately deferred (the open TODOs and what they disable), the doctor
checklist results, and the suggested next action — typically committing the
setup changes, then starting the first feature on a fresh branch with
`/feature`. For each item still open — including deferrals found in doctor
mode — offer to run the relevant step (2–4) for just that item now, so
deferred TODOs are re-offered on every run rather than silently carried
forward. Do not commit or push yourself unless the user asks — setup
changes deserve the user's own review. (If asked to push, Rule 4 in
`AGENTS.md` applies as always: code-critic pass, then `scripts/review-ok.sh`.)
