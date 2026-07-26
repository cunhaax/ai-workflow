---
name: init-workflow
description: >
  Bootstraps and validates the AI workflow in a project that has this
  plugin installed: scaffolds project-owned files on first run, detects the
  project's commands, fills AGENTS.md, points it at review/planning
  guidance (seeding docs/agent-rules/ or reusing an existing doc), and
  verifies the review gate. Re-run any time as a doctor — it reports what
  is missing or drifted. (Named init-workflow so it does not collide with
  Claude Code's built-in /init command, which generates a CLAUDE.md.)
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
  scaffold, one for commands, one for AGENTS.md sections, one for review
  and planning guidance) instead of asking one question at a time — Step 4's
  own "do you already have docs?" question is a separate, necessarily-first
  round of its own, since it decides what the rest of that step even asks.
  Never invent facts about the project; where the user defers, leave an
  explicit `[TODO: …]` rather than a guess.
- **Keep `AGENTS.md` lean.** You are filling a map, not writing the
  territory — one line per command, one line per module, one bullet per
  sensitive area. Depth belongs in `docs/`.

---

## Step 1 — Scaffold if needed, then assess the current state

If `AGENTS.md` does not exist, this is a brand-new project: propose
scaffolding every file under `${CLAUDE_SKILL_DIR}/templates/` to its
project-relative destination (this is the plugin's canonical enumeration —
see the file tree in the plugin's own documentation, kept in sync with this
directory by rule) — **except**
`docs/agent-rules/code-critic.md` and `docs/agent-rules/plan-critic.md`,
which Step 4 creates (or doesn't, if the project already has equivalent
docs) once it knows the answer; writing them here too would leave an
orphaned stub if Step 4 points elsewhere instead. For everything else:
strip the `.template` suffix from `AGENTS.md.template`, `CLAUDE.md.template`,
and `settings.json.template` (the last one lands at `.claude/settings.json`
— **never drop the suffix on the source copy in `templates/` itself**,
only on the destination: Claude Code auto-loads `AGENTS.md`/`CLAUDE.md` by
that exact name, so an un-suffixed copy left inside `templates/` would be
picked up as this project's live guidance the next time anyone edits that
directory), preserve the executable bit on `githooks/pre-push` and
`scripts/review-ok.sh`, and copy every other file (the rest of the `docs/`
tree, `.github/workflows/ci.yml.example`) to the same relative path it has
under `templates/`. Also append `.review-passed`, `.qa-evidence/`, and
`.workflow-log/` to `.gitignore` if not already present (create the file if
it doesn't exist) — these are what the workflow writes locally and Step 5
checks for. Present the full file list in one block — the same
confirm-then-write pattern as every other step here — before writing
anything. Once written, continue below as first-run mode.

Read `AGENTS.md`. If it has a **Review & Planning Guidance** section, read
the files it names; otherwise check `docs/agent-rules/code-critic.md` and
`docs/agent-rules/plan-critic.md` directly. Classify each placeholder /
`[TODO: …]` as filled or open.

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

## Step 4 — Seed review and planning guidance

First ask: does this project already have docs for code review standards
and/or planning risk areas — a style guide, `CONTRIBUTING.md`, an
engineering handbook, anything like that? Handle each of the two
(code review guidance, planning guidance) independently based on the
answer:

- **Doesn't have one** → interview briefly, draft a new file at the default
  path, and point `AGENTS.md`'s `Review & Planning Guidance` section at it:
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
- **Already has one** → point `AGENTS.md`'s section at that existing file
  instead of drafting a new one. Still ask the privacy/compliance question
  above for code review guidance specifically — `code-critic` binds its
  privacy rules to whatever PRIVACY anchors it finds in the named file
  (see that skill), so if the existing doc doesn't have them, they need a
  home. Offer to append a `## AI Agent Privacy Anchors` section to the
  *end* of the existing file (clearly delineated, so it reads as an
  addition rather than rewriting the user's own doc) — on the user's
  explicit confirmation, since this edits a file they own that this plugin
  didn't create. If they decline, say so plainly in the Step 6 report:
  privacy anchors are not captured, and why. The hard-constraints and
  high-risk-area questions are framed as "anything not already covered by
  your existing doc" rather than a full draft, and only produce output if
  the user has something to add.

Then present the drafted content (whichever combination of new files,
appended sections, and `AGENTS.md` pointer updates applies) in one block
for confirmation before writing — the same confirm-then-write pattern as
Steps 2 and 3; an answered question is input to the draft, not approval of
it. It is fine for newly drafted files to start thin — they are designed to
accrete (see *Evolving the System* in the AI Workflow plugin's own
documentation). Record only what the user confirms; keep the guidance
comments in newly drafted files for future additions.

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
8. `AGENTS.md` has a `Review & Planning Guidance` section, and every file
   it names actually exists. A missing section or a dangling entry means
   `code-critic`/`plan-critic` are silently falling back to the default
   paths (or running on base standards alone if those are also absent) —
   surface this rather than letting it stay invisible.

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
