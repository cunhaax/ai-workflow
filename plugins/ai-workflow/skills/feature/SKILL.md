---
name: feature
description: >
  Runs the full feature workflow: plan, critique, implement, review, QA. Use
  this when starting a new feature. Guides you through each phase with explicit
  gates between steps.
---

# /feature

Pipeline: plan → critique → implement → test → code-review → QA → PR.
Run every step in order. `AGENTS.md` is the source for commands, default
branch, sensitive areas, and task tracking.

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
- Present plan and critique separately, in this order:
  1. plan's **Approval Summary**
  2. critique's **Confidence** verdict + top findings
  3. full plan
  4. full critique
- Do not proceed without approval
- Substantive change (new scope, different approach, reworked requirements):
  re-enter plan mode → call `planner` again (never re-plan yourself) → re-run
  `plan-critic` → re-present with a **delta** section first
- Approval conditional on critique amendments: fold them into the plan text
  yourself. Sub-agents only see plan text, so conversation-only amendments
  are invisible to them
- Keep the approved plan text for steps 4 and 7

### 2. Implement

1. Write end-to-end tests from the plan's Test Strategy first (at minimum
   the `[AC-<slug>-n]` ones)
   - Never weaken or rewrite them to pass; a wrong test is a plan deviation
2. Implement in small steps until green; run the suite after each coherent
   unit of work
3. Before using an external library/framework API that may have changed,
   look it up with `context7` (resolve library ID → query docs). Skip for
   stdlib/language core. On lookup failure: note it in the summary, continue

Deviation from plan:
- Minor (implied edge case, small clarification): note it, tell the user
  briefly, continue
- Material (scope, approach, requirements): STOP → re-enter plan mode →
  update plan → get re-approval

### 3. Test

- Run the run-all-tests command (`AGENTS.md` → *Commands*)
- All must pass before continuing

### 4. Code review

- Commit first (`scripts/review-ok.sh` records the reviewed commit SHA)
- Call `code-critic` with:
  - approved plan text
  - summary output of the latest full test run (step 3); the critic must
    not run the suite itself
- Diff touches a sensitive area → call it with model override `opus`
- Returns: per-item PASS / FAIL / NEEDS_DECISION

### 5. NEEDS_DECISION

- Any present → STOP, present ALL to the user, wait for answers
- Never decide them yourself

### 6. FAIL

- Any FAIL → fix, commit, re-call `code-critic`; repeat until none
- Re-run `code-critic` after any later change (including step 8 fixes)
- On a pass with no FAIL on the committed HEAD → run `scripts/review-ok.sh`
  - Any later commit makes the record stale: re-review, re-run the script
  - Never run it without a passing review of the current HEAD
- No push or PR before this

### 7. QA

Run only if the diff touches a UI or API surface: templates/views, static
assets, a controller path rendering a view/fragment/client-driven response,
or a network-callable endpoint. Otherwise skip and state in the summary that
QA was skipped and why. When in doubt, run it.

1. Get open deferred QA findings (an empty result is still passed as
   "none open"):
   - `AGENTS.md` → *Task Tracking* → *List open deferred QA findings* holds a
     real command/tool call → run it
   - holds `[TODO:]` or `none` → `gh issue list --label known-issue --state open`
   - holds a real command you cannot run → STOP per Rule 2; never fall back
     to `gh`
2. Call `adversarial-qa` with: approved plan text (context, not a checklist)
   and the open findings list
3. Returns: findings

### 8. QA findings

- Any findings → present to the user, wait for a decision on each:
  fix now / defer / ignore
- Defer → file a task tagged `known-issue`:
  - `AGENTS.md` → *Task Tracking* → *File a deferred QA finding* holds a real
    command/tool call → use it
  - holds `[TODO:]` or `none` → `gh issue create --label known-issue …`
  - holds a real command you cannot run → STOP per Rule 2; never fall back
    to `gh`
  - Body must stand alone (`.qa-evidence/` is gitignored): behaviour,
    location, the QA pass that found it, repro steps, what the evidence
    showed in words, model attribution
- Ignore → no task

### 9. PR

Only after: code review passed, every QA finding dispositioned (or QA
skipped).

PR body:
- **Plan summary**: requirements + approach in a few sentences, link to
  source spec if any
- **Acceptance criteria → test table**: one row per `AC-<slug>-n` from the
  plan's Approval Summary, with its `[AC-<slug>-n]`-tagged test(s). No row
  without a test
- **Review outcome**: final verdict, each `NEEDS_DECISION` and the user's
  decision
- **QA outcome**: findings + disposition (fixed / deferred with task id /
  ignored), or "skipped: no UI or API surface". Describe in words; no
  `.qa-evidence/` paths
- **Test evidence**: one line, test count + result of the final full run

Diff touches a sensitive area:
- State it in the PR body
- Re-run `code-critic` in a fresh context as a second look before merge

## Output

- Open PR with the body above
- Summary of skipped steps, plan deviations, and why

## Rules

- Never skip `planner` for a new feature
- Never skip `plan-critic` unless all step 1b criteria hold AND the user opted out
- Never fetch external links/docs directly
- Never enter plan mode from a sub-agent
- Never present work to the user before `code-critic` has reviewed it
- Relay ALL `NEEDS_DECISION` items to the user; never decide them
- Sub-agents are read-only; only the main agent implements changes

<!-- SKILL NAMING NOTE (Claude Code): the skill is named `code-critic` so it
     does NOT shadow Claude Code's bundled `code-review` skill (project
     skills shadow bundled ones). `/code-review ultra` stays reachable as an
     optional, user-launched deep pass. Do not rename back. -->
