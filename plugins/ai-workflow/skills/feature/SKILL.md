---
name: feature
description: >
  Runs the full AI-assisted workflow for a non-trivial feature or change:
  plan, plan critique, user approval, tests-first implementation, code
  review, exploratory QA, and PR. Use when the user asks to build or start a
  feature, or to implement a change that needs a plan, review, and PR.
license: MIT
metadata:
  author: André Cunha
---

# /feature

Pipeline: plan → critique → implement → test → code-review → QA → PR.
Run steps in order, skipping only where a step says so. `AGENTS.md` is the
source for commands, default branch, sensitive areas, and task tracking.

## Input

- User prompt (verbatim, including any doc/link references)
- Session branch: a feature branch, not the default branch

## Steps

### 1. Plan

Preconditions:
- On the default branch → STOP, ask the user to create a feature branch
  (never create/switch branches yourself, `AGENTS.md` Rule 3)

Enter plan mode. Stay in it through 1a–1c; exit only in 1c on approval.

**1a. Draft**
- Call `planner` with the user prompt verbatim
- Never fetch links/docs or use tools yourself; the planner does it
- Returns: plan (markdown)

**1b. Critique**
- Call `plan-critic` with the plan
- Returns: critique (markdown)
- Skip only if ALL hold:
  - diff plausibly under ~50 lines of non-test code
  - no sensitive area touched
  - no new public endpoint, persisted field, or external dependency
  - user explicitly said "skip the critic" this session
- Never infer "trivial" yourself; when in doubt, run it

**1c. Approve**
- Before presenting, check the plan: it has a `**Slug:**`, numbered
  `AC-<slug>-n` criteria, and every `AC-<slug>-n` and `EDGE-<slug>-n` has a
  tagged Test Strategy entry. Anything missing → call `planner` again with
  the original prompt, the plan and the gap (never fix it yourself), then
  re-run `plan-critic` on the revised plan (unless 1b was skipped); don't
  present until it passes. Still failing after 2 attempts → STOP per Rule 2
  and show the user the gap
- Present plan and critique separately, in this order, using the harness's
  mechanism for exiting plan mode (not chat):
  1. plan's **Approval Summary**
  2. critique's **Confidence** verdict + top findings
  3. full plan
  4. full critique
- Do not proceed without approval
- Substantive change (new scope, different approach, reworked requirements):
  re-enter plan mode → call `planner` again with the original prompt, the
  previous plan and the requested changes (never re-plan yourself) → re-run
  `plan-critic` → re-present with a **delta** section first (what changed vs.
  the previously presented version)
- Approval conditional on critique amendments, or edits the user makes at
  approval (including renaming the `**Slug:**`): fold them into the plan
  text yourself (transcription, not re-planning). Sub-agents only see plan
  text, so conversation-only amendments are invisible to them
- Keep the approved plan text for steps 4 and 7

### 2. Implement

1. Write the plan's Test Strategy tests first (at minimum the
   `[AC-<slug>-n]` and `[EDGE-<slug>-n]` ones), at the level the Test
   Strategy states (end-to-end for user-visible behaviour)
   - Tag each test with the plan ID it proves, exactly as in the plan
     (`[AC-<slug>-n]` / `[EDGE-<slug>-n]`)
   - Never weaken or rewrite them to pass; a wrong test is a plan deviation
2. Implement in small steps until green; run the suite after each coherent
   unit of work
3. Before using an external library/framework API that may have changed,
   look it up with `context7` (resolve library ID → query docs). Skip for
   stdlib/language core. On lookup failure: note it in the summary, continue

Deviation from plan:
- Minor (implied edge case, small clarification): note it, tell the user
  briefly, continue
- Material (scope, approach, requirements): STOP → re-plan via the step 1c
  substantive-change path → get re-approval

### 3. Test

- Run the run-all-tests command (`AGENTS.md` → *Commands*)
- All must pass before continuing

### 4. Code review

- Commit first (`scripts/review-ok.sh` records the reviewed commit SHA)
- Call `code-critic` with:
  - approved plan text
  - summary output of the latest full test run on the state being reviewed
    (step 3)
- Every `code-critic` call (including the re-reviews in steps 6 and 8): diff
  touches a sensitive area → model override `opus`
- Returns: per-item PASS / FAIL / NEEDS_DECISION, plus Open Questions

### 5. NEEDS_DECISION and Open Questions

- Any present → STOP, present ALL to the user, wait for direction on each
- Never decide them yourself
- An item the user already answered earlier this session, re-raised by the
  critic about code unchanged since that answer → don't ask again; carry the
  earlier answer forward and say so. Code changed since → ask again

### 6. FAIL

- Any FAIL → fix, re-run step 3, commit, re-call `code-critic` with the new
  test summary; repeat until none
- Same FAIL after a fix, or you disagree with a FAIL → present it to the
  user like a NEEDS_DECISION (step 5); never loop on it or bend correct code
  to satisfy it. A FAIL the user explicitly overrides counts as resolved (the
  critic will keep returning it) and goes in the PR **Review outcome**
- After any later change (including step 8 fixes): re-run step 3, commit,
  re-call `code-critic` with the new summary
- After each re-review, apply step 5 to anything new before continuing
- Record only when the committed HEAD has no unresolved FAIL and every
  step 5 item is answered → run `scripts/review-ok.sh`
  - Any later commit makes the record stale: re-review, re-run the script
  - Never run it without a passing review of the current HEAD
- No push or PR until a passing review of HEAD is recorded

### 7. QA

Run only if the diff touches a UI or API surface: templates/views, static
assets, a controller path rendering a view/fragment/client-driven response,
or a network-callable endpoint. Otherwise skip and state in the summary that
QA was skipped and why. When in doubt, run it.

1. Get open deferred QA findings (an empty result is still passed as
   "none open"):
   - `AGENTS.md` → *Task Tracking* → *List open deferred QA findings* holds a
     real command/tool call → run it
   - section/bullet absent, `[TODO:]`, or `none` →
     `gh issue list --label known-issue --state open`
   - holds a real command you cannot run → STOP per Rule 2; never fall back
     to `gh`
2. Call `adversarial-qa` with: approved plan text (context, not a checklist)
   and the open findings list
3. Returns: Findings / Known issues / Blockers

### 8. QA findings

- Any Blockers (QA could not fully run) → STOP per Rule 2: report them to
  the user as-is and wait. Never treat them as "no findings". The user
  chooses: resolve and re-run step 7, or proceed without (full or partial)
  QA, which the PR records
- Any findings → present to the user, wait for a decision on each:
  fix now / defer / ignore
- Defer → file a task tagged `known-issue`:
  - `AGENTS.md` → *Task Tracking* → *File a deferred QA finding* holds a real
    command/tool call → use it
  - section/bullet absent, `[TODO:]`, or `none` →
    `gh issue create --label known-issue …`
  - holds a real command you cannot run → STOP per Rule 2; never fall back
    to `gh`
  - Body must stand alone (`.qa-evidence/` is gitignored): behaviour,
    location, the QA pass that found it, repro steps, what the evidence
    showed in words, model attribution
- Ignore → no task

### 9. PR

Only after: code review passed, every QA finding dispositioned and every
Blocker decided (or QA skipped).

PR body:
- **Plan summary**: requirements + approach in a few sentences, link to
  source spec if any
- **Plan ID → test table**: one row per `AC-<slug>-n` (plan's Approval
  Summary) and per `EDGE-<slug>-n` (plan's Edge Cases): the ID, the
  criterion/edge case, and its `[AC-<slug>-n]`/`[EDGE-<slug>-n]`-tagged
  test(s). Every ID has a row with at least one test
- **Review outcome**: final verdict, each `NEEDS_DECISION`, Open Question and
  user-overridden FAIL, and the user's decision
- **QA outcome**: findings + disposition (fixed / deferred with task id /
  ignored), any Blockers and the user's decision (including a partial or
  skipped QA run and why), or "skipped: no UI or API surface". Describe in
  words; no `.qa-evidence/` paths
- **Test evidence**: one line, test count + result of the final full run

Diff touches a sensitive area:
- State it in the PR body
- Re-run `code-critic` in a fresh context as a second look before merge

## Output

- Open PR with the body above
- Summary of skipped steps, plan deviations, `context7` lookup failures, and why

## Rules

- Never skip `planner` for a new feature
- Never skip `plan-critic` unless all step 1b criteria hold AND the user opted out
- Never fetch external links/docs from the prompt directly (the `planner`
  does); `context7` lookups in step 2 are allowed
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
