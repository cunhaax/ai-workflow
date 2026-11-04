# /feature — steps 2–9: Build

Part of `/feature` (`SKILL.md` beside this file, whose mode table decides when
this phase runs). Needs the approved plan text, and the plan file path if one
was saved or read. Files named below are beside this one.

## No automated test suite

Applies when `AGENTS.md` → *Commands* says the project has no automated test
suite. The plan's tagged Test Strategy entries are then scripted walkthroughs,
and they stand in for the tests:

- Step 2: skip writing tests first; after each coherent unit of work, run the
  walkthroughs it affects
- Step 3: instead of the run-all-tests command, run every tagged walkthrough
  in the plan's Test Strategy, plus every one added to the record earlier in
  this run (each re-run runs them all), and record per ID what you ran and the
  result. That record is the test summary in every later step. All must pass,
  as with tests. A walkthrough you can't run → STOP per Rule 2 and ask; a user
  waiver goes in the record
- A coverage gap `code-critic` raises is fixed by adding a walkthrough to the
  record, labelled as not in the plan
- Step 9: the **Test evidence** line gives walkthroughs run + result, naming
  any waived; the plan ID → test table gives each walkthrough and its result

## Steps

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

No suite: 1 and 2 as in *No automated test suite*.

Deviation from plan:
- Minor (implied edge case, small clarification): note it, tell the user
  briefly, continue
- Material (scope, approach, requirements): STOP → re-read `plan.md` and
  re-plan via its step 1c substantive-change path → get re-approval (then
  `plan-file.md` → *Rewrite* runs) → return here and continue step 2; 1d does
  not re-run
  - `--from-plan`: that path takes the approved plan text, labelled with its
    path, as the original prompt and sources; the file is never rewritten
    (*Rewrite* does not apply)

### 3. Test

- Run the run-all-tests command (`AGENTS.md` → *Commands*)
- All must pass before continuing
- No suite: as in *No automated test suite*

### 4. Code review

- Commit first (`scripts/review-ok.sh` records the reviewed commit SHA)
- Call `code-critic` with:
  - approved plan text
  - summary output of the latest full test run on the state being reviewed
    (step 3)
- Every `code-critic` call (including the step 6 re-reviews and step 9's
  second look): diff touches a sensitive area → model override `opus`
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
  critic will keep returning it) and goes in the PR **Review outcome**, but
  only while the code it covers is unchanged: if the critic re-raises it
  after that code changed → ask again
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

**Review guide**: before opening the PR, run the `review-guide` skill. It
returns the Tier line and the Review guide. Pass it the default branch and the
plan source: the plan file path this run last wrote (1d or `plan-file.md` →
*Rewrite*) or `--from-plan` read;
`--plan-reapproved` after a `--from-plan` step 2 material deviation; nothing
if no plan file was saved. Its paths are plain until the PR is open; then apply
its step 4 (links) with the PR URL before posting the first comment. Run it
again and replace both after any commit made once the PR is open (e.g. fixes
from the second look below), passing the PR URL.

The PR description usually becomes the merge commit message: keep it short
and commit-ready. Pipeline details go in the first PR comment.

**PR description** (about 10–15 lines):
- **What and why**: requirements + approach in a few sentences, the decisions
  that shape the change (one line each), link to the source spec if any
- **Tier**: the Tier line `review-guide` returned
- **Test evidence**: one line, test count + result of the final full run
  (no suite: as in *No automated test suite*)
- In the description only: no commit SHAs, no review/QA process narration, no
  instructions to the reviewer (the first comment has them)

**First PR comment**, posted right after opening the PR (e.g. `gh pr
comment`): the **Review guide** `review-guide` returned (addressed to the
reviewer; SHAs allowed), then *Review & traceability*. On a github.com PR with a
non-empty *Read closely* or *Skim*, a guide with neither link lines nor a
`Links: not computed` line is incomplete.
If the host can't post comments, put both under `##` headings at the end of
the description, guide first (plain paths), and tell the user to trim them at
merge. `--from-plan`: the first comment also says: run from a saved plan via
`--from-plan`, the `base-commit`, and whether a re-critique ran. No plan file
was saved (the user chose to continue) → say so in the first comment. Never
put the plan file's absolute path in the PR description or the first comment.

**Review & traceability**:
- **Plan ID → test table**: the slug once in the heading, then one row per
  `AC-n` (plan's Approval Summary) and per `EDGE-n` (plan's Edge Cases) with
  the criterion/edge case and its `[AC-<slug>-n]`/`[EDGE-<slug>-n]`-tagged
  test(s), by test class or file (method names only where needed; no suite:
  as in *No automated test suite*). Every ID has a row with at least one test
  or walkthrough
- **Review outcome**: final verdict, each `NEEDS_DECISION`, Open Question and
  user-overridden FAIL, and the user's decision
- **QA outcome**: findings + disposition (fixed / deferred with task id /
  ignored), any Blockers and the user's decision (including a partial or
  skipped QA run and why), or "skipped: no UI or API surface". Describe in
  words; no `.qa-evidence/` paths

Diff touches a sensitive area:
- Spawn a new `code-critic` (not one continued from earlier rounds) as a
  second look before merge, and apply steps 5–6 to its output

**Plan file**: after the PR opens, follow `plan-file.md` → *Mark consumed*.
