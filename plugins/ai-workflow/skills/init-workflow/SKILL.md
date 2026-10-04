---
name: init-workflow
description: >
  Sets up and checks the AI workflow in a project that has this plugin
  installed: scaffolds missing AGENTS.md, CLAUDE.md, hooks, settings and
  docs; detects project commands; seeds review/planning guidance; verifies
  the review gate. Use when adopting the plugin in a project, or re-run as a
  doctor when the setup may be missing or drifted.
license: MIT
metadata:
  author: André Cunha
---

# /init-workflow

Scaffold the project-owned files missing from `${CLAUDE_SKILL_DIR}/templates/`
(each independently: a project may already have its own `AGENTS.md`,
`CLAUDE.md`, or neither), fill them with this project's facts, and verify
the setup. Idempotent: re-run after a plugin update or suspected drift; it
acts as a doctor, reporting what is missing instead of redoing what is filled.

Scope: project-owned files only. Never edit the plugin's own mechanism
(skills, sub-agents, plugin docs); those change by updating the plugin.

## Input

- The project (repo root as working directory), with this plugin installed
- User answers to the confirmation rounds below

## Ground rules

- **Propose, then write.** Every detected value is a proposal until the user
  confirms it
  - Batch confirmations: one round each for the initial scaffold, commands,
    AGENTS.md sections, review/planning guidance (Step 4's "already have
    docs?" question is a separate, first round, since it decides what the
    rest of that step asks)
  - Never invent project facts; where the user defers, leave an explicit
    `[TODO: …]`
- **Keep `AGENTS.md` lean**: one line per command, one per module, one bullet
  per sensitive area. Depth belongs in `docs/`

## Steps

### Step 1 — Scaffold if needed, then assess the current state

Every file under `${CLAUDE_SKILL_DIR}/templates/` maps to a project-relative
destination (the plugin's canonical enumeration), **except**
`docs/agent-rules/code-critic.md` and `docs/agent-rules/plan-critic.md`:
Step 4 creates those (or not, if the project has equivalent docs); writing
them here would leave orphaned stubs. Check each other destination on its
**own** trigger; one file's presence never gates another's.

- **Destination missing → scaffold it**
  - Strip `.template` from `AGENTS.md.template`, `CLAUDE.md.template` (→
    `AGENTS.md`, `CLAUDE.md`) and `settings.json.template` (→
    `.claude/settings.json`, not project root), on the destination copy only.
    Never strip it on the source inside `templates/` (an un-suffixed
    `AGENTS.md`/`CLAUDE.md` there would be auto-loaded as live guidance)
  - Copy every other file to the same relative path it has under `templates/`
- **Destination exists as plain content** (`AGENTS.md`, `docs/adr/*`,
  `docs/product-context/*`) → leave untouched; list as "already present" in
  Step 6. Never overwrite a file the project owns
- **Destination exists, special handling** (below): `CLAUDE.md`,
  `.claude/settings.json`, `githooks/pre-push`, `scripts/review-ok.sh`,
  `scripts/check-hook-status.sh`

**`CLAUDE.md`**
- Exists and lacks `@AGENTS.md` → offer to append the import line. Never
  overwrite with the template; never append if the import is already there
- Declined → Step 6 gap: `CLAUDE.md` won't load `AGENTS.md` into Claude Code

**`.claude/settings.json`** (a merge target; already existing is common, since
a project-scope plugin install can create it first)
- Exists → read it; propose adding whichever of
  `${CLAUDE_SKILL_DIR}/templates/settings.json.template`'s
  `permissions.ask`/`permissions.deny` entries are missing, preserving
  everything else. Never a flat overwrite
- Missing → scaffold from the template
- Doesn't parse as JSON, root isn't an object, or `permissions` /
  `permissions.ask` / `permissions.deny` exist but aren't an object and two
  arrays → no merge, no guessed fix. Flag as an unresolved item in this
  step's proposal (like a hook conflict) and continue; a malformed file on
  this security-relevant path needs the user's own eyes

**`githooks/pre-push`, `scripts/review-ok.sh`, `scripts/check-hook-status.sh`**
Two questions. Q1 is decided here and written in the same single
confirmation round below, never before the user confirms. Q2 runs only
after that write (or its decline), as the first thing after the proposal is
confirmed and written, since its verdict is meaningful only against settled
state.

*Q1. Is each existing file actually this gate's own?* Check each
independently:
- `githooks/pre-push`, `scripts/review-ok.sh`: ours if the content references
  `.review-passed`
- `scripts/check-hook-status.sh`: ours if the content references
  `DEST_FOREIGN` (unique to that script; `.review-passed` and
  `READY_TO_CONFIGURE` also appear in `review-ok.sh`)
- Known gap, accepted: `check-hook-status.sh` necessarily contains
  `.review-passed` too, so its content placed at `githooks/pre-push` would
  misidentify as ours

Then:
- Missing → scaffold from the template, preserving the executable bit
- Exists, not ours → a real conflict, not "already present". Surface it and
  ask: replace with the template's version, or decline
  - For `githooks/pre-push`, never offer to chain the template's check into
    the existing script: a pre-push hook reads its ref list from stdin once,
    and a chained script can consume it before the gate's `while read` loop,
    giving a hook that exits 0 on every push with no error
  - A declined conflict is an open gap Step 6 must name
- Exists and ours → leave as is (Step 5 item 1 checks it's executable)

*Q2. Is the gate actually wired up?* Run
`${CLAUDE_SKILL_DIR}/templates/scripts/check-hook-status.sh` from the project
root (the plugin's read-only copy; safe even if Q1 was declined or not yet
scaffolded) and act on its one-line verdict:
- `ACTIVE` / `NEEDS_CHMOD` → already wired (the latter needs `chmod +x`,
  safe since the marker identifies it as this gate's file). Nothing else
- `READY_TO_CONFIGURE` → `githooks/pre-push` ready, `core.hooksPath` isn't
  wired to it. Ordinary state right after Q1's scaffold: offer
  `git config core.hooksPath githooks`
- `DEST_NEEDS_CHMOD` → `githooks/pre-push` exists, is ours, isn't
  executable: offer `chmod +x`
- `UNCONFIGURED` / `DEST_FOREIGN`:
  - Q1's proposal for `githooks/pre-push` was declined → same gap, already
    in Step 6; don't report twice
  - Q1 was confirmed and written → unexpected, the write didn't take effect:
    report it (Rule 2), don't act on it
- `FOREIGN` → another hook manager, or `core.hooksPath` pointing outside this
  project's `githooks/`. Never offer to change `core.hooksPath` or replace
  anything; report exactly what the script printed and leave reconciling to
  the human (coexisting would need their hook to invoke `githooks/pre-push`
  with correct stdin handling; not drafted here)
- Known limitation, accepted: the marker check is presence, not version, so
  a stale copy from before a plugin update still reads `ACTIVE`

**`.gitignore`**: append `.review-passed`, `.qa-evidence/`,
`.playwright-mcp/`, `.workflow-log/` if missing (create the file if needed);
Step 5 checks for them.

Known limitation: no memory of a prior decline. A file the user chose not to
scaffold (e.g. a deleted `docs/product-context/README.md`) is proposed again
next run; answering "no" each time is the workaround.

**Confirm, then write**
- Present the full proposal in one block: files to scaffold, the
  `.claude/settings.json` merge diff, the `CLAUDE.md` append, any hook or
  settings conflict, and what's already present and left alone
- Write only after confirmation, then run Q2 and act on its verdict

**Assess `AGENTS.md`** (just scaffolded or pre-existing)
- Has a **Review & Planning Guidance** section → read the files it names. A
  named file that doesn't exist yet is not a Rule 2 stop here: it's expected
  input to Step 4 (a scaffolded `AGENTS.md` defaults to
  `docs/agent-rules/code-critic.md` / `plan-critic.md`, which Step 4 hasn't
  created yet; a pre-existing one may name or default to files that don't
  exist either). Step 5 item 7 decides separately whether a still-missing
  file is reported
- No such section → check `docs/agent-rules/code-critic.md` and
  `docs/agent-rules/plan-critic.md` directly
- Classify each placeholder / `[TODO: …]` as filled or open, **except** those
  under `## Task Tracking` (optional; never counts toward the mode)
- Mostly open → **first-run mode**: Steps 2–4, then validate
- Mostly filled → **doctor mode**: skip to Step 5, then report only what is
  open or drifted (plus Step 5 item 8's two informational Task Tracking
  notes, which are neither, by design)

### Step 2 — Detect the commands, propose, confirm

- Inspect whichever exist: `package.json` scripts, `Makefile`, `justfile`,
  `build.gradle(.kts)`, `pom.xml`, `pyproject.toml`, `Cargo.toml`, `go.mod`,
  `Gemfile`, `docker-compose.yml`
- Propose a value for every entry in `AGENTS.md` → *Commands*:
  - build / run-all-tests / all-checks / dev server / stop / single-test
    example; prefer wrappers (`make …`, npm scripts, `just …`) over raw tools
    (a wrapper may add environment setup)
  - app URL: from the dev-server config (port, host) if discoverable
  - default branch: `git symbolic-ref refs/remotes/origin/HEAD`; fall back to
    asking
- Present the full Commands list in one block to confirm or correct
- Flag every entry you couldn't derive; a missing stop or check command is
  common and needs an explicit decision (`adversarial-qa` and `feature`
  depend on them)
- After confirmation, write the section, replacing the placeholders

### Step 3 — Fill the remaining AGENTS.md sections

For each still-open section, draft from evidence and confirm before writing:

- **Project Overview**: one paragraph from the README and manifest (purpose,
  stack, key dependencies). Replace `[PROJECT_NAME]` in the title
- **Architecture**: top-level directory tree (source dirs only; skip
  vendored/build output), one-line purpose per module inferred from its
  contents. Ask the user to correct wrong inferences; a wrong map is worse
  than none
- **Testing**: framework(s) found, where tests live, how to run one
  (mirrors the single-test command)
- **Sensitive Areas**: propose candidates by scanning for expensive-mistake
  surfaces: auth/session/token code, security config, route definitions,
  payment/billing flows, schema migrations, personal data fields and their
  rendering paths, secret/config loading
  - One bullet per confirmed area, naming a concrete file/package/pattern
  - This list gates three workflow decisions (critic-skip, reviewer model
    escalation, PR security flag); empty = those protections off. If the user
    has no time, leave the TODO and say so in the report
- **Rule 5** (project hygiene rule): ask whether one applies (e.g. reset a
  dev database at session end); fill it or delete the placeholder
- **Task Tracking** (optional): ask whether the project uses an issue tracker
  (GitHub issues, Jira, Trello, …) agents should file and update tickets in
  - Yes → fill every bullet, with the exact command/tool call where asked,
    or `none` where the tracker lacks the concept; confirm before writing
    - Only the two QA-finding bullets treat `[TODO:]` or `none` as "fall
      back to `gh`". A project can use its own tracker for tasks and still
      fall back to `gh` for deferred QA findings by leaving just those two
      as `none`
  - No → delete the whole section. That is the only way to say "no tracker
    at all"; the two QA-finding bullets then fall back to `gh`, the rest
    don't apply. Not a gap to report

### Step 4 — Seed review and planning guidance

`AGENTS.md`'s `Review & Planning Guidance` section takes exactly two entries,
labeled precisely `Code review guidance` and `Planning guidance` (Step 5 and
both critic skills key on these literal labels; never paraphrase).

First ask: does the project already have docs for code review standards
and/or planning risk areas (style guide, `CONTRIBUTING.md`, engineering
handbook, …)? Handle code review guidance and planning guidance
independently:

- **Doesn't have one** → copy
  `${CLAUDE_SKILL_DIR}/templates/docs/agent-rules/code-critic.md` (or
  `plan-critic.md`) to the default path as the starting point (it carries the
  Rules/Checklist structure, the build-enforced-rules doctrine, and guidance
  comments; never draft from scratch). Interview briefly, then point
  `AGENTS.md`'s section at it:
  - Personal data? Which categories are sensitive, is there a compliance
    doc, which surfaces are public/unauthenticated, any identifiers public by
    design, do any of the three privacy fitness tests already exist?
    → fill *Privacy anchors* in `docs/agent-rules/code-critic.md`
  - Hard constraints the team knows agents get wrong (framework conventions,
    forbidden APIs, required registrations)?
    → add as rules with severities, mirrored in the *Checklist* section
  - The product's highest-risk areas, where a generic plan would miss
    something that matters here?
    → fill 4–7 lenses in `docs/agent-rules/plan-critic.md`
- **Already has one** → point `AGENTS.md`'s section at that file instead of
  copying the template
  - Still ask the privacy/compliance question for code review guidance:
    `code-critic` binds its privacy rules to the `## Privacy anchors` section
    of the named file, so if absent it needs a home
  - Offer to append `## Privacy anchors` (same heading as the template) at
    the *end* of the existing file, delineated as an addition, not a rewrite;
    only on explicit confirmation (the user owns the file). Declined → say
    so plainly in Step 6: privacy anchors not captured, and why
  - Frame the hard-constraints and high-risk-area questions as "anything not
    already covered by your existing doc"; they produce output only if the
    user has something to add

Then present the drafted content (copied/filled files, appended sections,
`AGENTS.md` pointer updates) in one block and confirm before writing; an
answered question is input to the draft, not approval of it. Newly filled
files may stay thin beyond what the interview produced (they accrete; see
*Evolving the System* in the plugin's own documentation). Record only what
the user confirms; keep the guidance comments for future additions.

### Step 5 — Validate the setup (doctor checklist)

Check each item and collect results. Fix only with the user's confirmation;
report what you can't fix.

1. `githooks/pre-push` and `scripts/review-ok.sh` exist, are executable, and
   reference `.review-passed`; `scripts/check-hook-status.sh` exists, is
   executable, and references `DEST_FOREIGN` (the same three identity
   markers as Step 1). Existence alone isn't enough: a foreign file at any
   of the three paths would pass an existence check while enforcing nothing
2. The pre-push gate is active. Run `scripts/check-hook-status.sh` (the
   project's own copy, confirmed genuine by item 1; the same script Step 1
   and `scripts/review-ok.sh` use) and map the verdict:
   - `ACTIVE` → pass
   - `NEEDS_CHMOD` → offer `chmod +x` on the path the script printed
   - `READY_TO_CONFIGURE` → offer `git config core.hooksPath githooks`
   - `UNCONFIGURED` / `DEST_FOREIGN` / `DEST_NEEDS_CHMOD` → item 1 should
     already have caught this; if it didn't, that's the gap to report. Don't
     act on the verdict directly
   - `FOREIGN` → never offer to change `core.hooksPath` or replace anything;
     report exactly what the script printed; leave reconciling to the human
     (see Step 1 on why chaining isn't offered)
3. `CLAUDE.md` exists and contains `@AGENTS.md`
4. `.gitignore` covers `.review-passed`, `.qa-evidence/`, `.playwright-mcp/`,
   `.workflow-log/`
5. `.claude/settings.json` has the `ask` rules for `scripts/review-ok.sh` and
   the `deny` rules for the push-bypass flags
6. `AGENTS.md` → *Commands* exists and has no unfilled placeholder
   - `/feature`, `code-critic`, and `adversarial-qa` read it by role and fail
     at runtime without it, so a missing section counts as unfilled (a
     hand-written `AGENTS.md` that never had one has nothing "unfilled" to
     flag, but still fails this check)
   - Other sections may legitimately keep deferred TODOs
7. `AGENTS.md` has a `Review & Planning Guidance` section with entries
   labeled exactly `Code review guidance` and `Planning guidance`
   - A renamed/paraphrased label is invisible to both skills and silently
     falls back to the default `docs/agent-rules/` paths with no warning
   - Every file an entry names must exist
     - Missing section (or missing entry) → falls back to the default path if
       present
     - Entry naming a nonexistent file → that skill runs on base
       standards/lenses alone (no further fallback to the default path)
     - Surface either gap; never leave it to fail silently on the next review
8. **Task Tracking**: informational only, never a validation failure (an
   absent section is a legitimate choice)
   - No `## Task Tracking` section **and Step 3 didn't already ask about it
     this run** → note it's available and offer Step 3's interview now (same
     confirm-then-write). The guard stops re-asking a question the user just
     answered "no" to; without it a doctor-mode project that never saw the
     question and a first-run project that just declined it look identical
   - Section exists → validate like any other: no remaining `[TODO:]` =
     configured; open TODOs are a deferral to report, **except** on the two
     QA-finding bullets, where `[TODO:]` is an intentional skip (per the
     template comment): treat as `none`, the documented `gh` fallback, and
     note it informationally, not as a deferral (Steps 1 and 6 carry this
     exception too)
   - Known limitation (as in Step 1): no memory of a prior decline across
     runs, so a deliberately deleted section is re-offered every run

### Step 6 — Report

End with a short summary:
- Written, file by file (incl. any `.claude/settings.json` merge or
  `CLAUDE.md` import append)
- Already existing and left untouched (plain-content skips, pre-existing gate
  scripts correctly identified as this gate's)
- Declined appends and unresolved hook/settings conflicts (Step 1, Step 5
  item 2)
- Deliberately deferred: open TODOs and what they disable (excluding Step 5
  item 8's QA-finding-bullet fallback note, not a deferral)
- Doctor checklist results
- Suggested next action: commit the setup changes, then start the first
  feature on a fresh branch with `/feature`

For each item still open (incl. deferrals found in doctor mode, **excluding**
Step 5 item 8's two informational notes: its absent-section offer, already
made and, if accepted, acted on inside Step 5; and its QA-finding-bullet
fallback note), offer to run the relevant step (2–4) for just that item now,
so deferred TODOs are re-offered every run, not silently carried forward.

Do not commit or push unless the user asks (setup changes deserve their own
review). If asked to push, `AGENTS.md` Rule 4 applies: `code-critic` pass,
then `scripts/review-ok.sh`.

## Output

- Project-owned files scaffolded/filled as confirmed
- The Step 6 report
