# Multi-task execution — reference for `/feature`

Sibling reference file for `plugins/ai-workflow/skills/feature/SKILL.md`,
covering everything after an approved, ticketed breakdown: scheduling,
launching, relaying, staleness/conflict handling, closure, and
cancellation. Read `feature/decomposition.md` first for how the breakdown
itself got here.

## Preconditions promoted to hard stops

`feature/SKILL.md`'s multi-task precondition table lists P2 (`worktree.baseRef`
resolves to `"head"`), P6 (`.claude/worktrees/` gitignored), and P7 (`.env`/
`.worktreeinclude` advisory) as warnings during planning — they don't block
producing a breakdown or filing tickets. Before launching the **first**
task, re-check all preconditions and treat **P2 and P6 as hard STOPs**: a
task launched without `"head"` resolution would silently branch from the
wrong ref (the project's default branch, not the feature-integration
branch), defeating the entire dependency model without any visible error.
P7 stays a warning even here — a missing `.worktreeinclude` degrades a
task's local dev environment, it doesn't corrupt the dependency model.

## Launching a task

```
Agent(subagent_type="task-runner", name="task-<id>", isolation="worktree", prompt=<brief>)
```

Both `name` and call-level `isolation` are required, for opposing reasons:
`name` makes the task addressable by `SendMessage` for the relay below;
call-level `isolation` (not frontmatter alone) is what keeps a named
sub-agent from launching as a "teammate" instead under
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` — a teammate drops the `skills:`
preload and returns no output you can read. **Unverified in this repo**
(requires that flag, which isn't set here): pass `isolation` on every
launch call regardless, per the documented mitigation.

The brief carries: the task's scope description, `BASE_BRANCH: <the
feature-integration branch>`, its `depends-on` list and the PRs that
satisfied them, its collision flags, the tracker item reference and its
exact status-update command, and `task-lifecycle`'s result-block contract.

The orchestrator **never** runs `git worktree`, `git branch`, or
`git checkout <branch>` — the harness creates and names the worktree
branch. Set the tracker status to the configured in-progress value at
launch.

## Readiness

A task is ready when every `depends-on` prerequisite has merged into the
feature-integration branch. Before launching any task whose readiness
depends on a sibling's merge, in this exact order — **four separate tool
calls, never chained with `&&` or `$( )`, never a loop** (Rule 6 in
`AGENTS.md`; this is also what worktree isolation can trace):

1. `gh pr view <n> --json state,mergedAt,mergeCommit,baseRefName` for each
   prerequisite.
2. `git fetch origin <integration-branch>`.
3. `git merge --ff-only origin/<integration-branch>` — advances your own
   HEAD. A fast-forward on the branch you are already on, never a branch
   switch, so no Rule 3 exception is needed.
4. `git merge-base --is-ancestor <task-branch> HEAD` — confirms the work
   actually landed on *this* branch (this is exactly the check a squash
   merge breaks — see *Merge strategy and its precondition* below).

If step 3 fails (`--ff-only` refuses because your local branch has
diverged — a human committed to it directly, or force-pushed), STOP and
report. Never `git merge` (an unasked-for merge commit) and never
`git reset --hard`.

**Out-of-order merges.** If the human merges a dependent task's PR before
its prerequisite's — step 1's ancestry check can only confirm what
actually happened, not enforce an order — the dependent's own readiness
check still passes (its own PR merged), but do not treat the *prerequisite*
as satisfied merely because a task that depends on it is now merged.
Report the out-of-order merge on the next status update, with its impact,
and continue verifying the prerequisite's own readiness independently.

## Merge strategy and its precondition

Task PRs merge into the feature-integration branch with `gh pr merge <n>
--merge` — never squash. A squash rewrites the task branch's commits into
a new commit on the integration branch, so step 4 above returns false even
though the work landed, and a later sibling branched off the pre-squash
tip would still carry the original commits, re-introducing the diff.
`feature/SKILL.md`'s precondition **P8** checks this is actually possible
before any ticket is filed: `gh api repos/{owner}/{repo}` → `allow_merge_commit`,
and — checked only *after* P3 confirms the integration branch exists on
the remote, since a 404 before that point is ambiguous — `gh api
repos/{owner}/{repo}/branches/<integration>/protection` → `required_linear_history`
is not set (404 once the branch exists = unprotected, fine; 403 = unknown,
treat as not fine). Default-branch protection (required reviews/checks) is
not checked by P8 and can still affect the final PR at Step 8 below.

**If a squash slips through anyway** (protection changed mid-run, or a
human used the wrong button): the mismatch between `gh`'s `mergedAt` and
step 4's ancestry check is the detection. Recovery, not just detection:
send `RESOLVE-CONFLICT` (below) to every still-open sibling so they
rebase onto the real tip; for the rest of *this run only*, fall back to a
squash-tolerant readiness check (`gh pr view --json state` equal to
`MERGED` with the right `baseRefName`, dropping the ancestry check for
that run) and say so on the next status update — a squash-tolerant
readiness check must never be the default. One human slip should not kill
the whole feature.

The final feature-integration → default-branch PR (Step 8) may use
`--squash` — nothing branches off it afterwards, so the ancestry concern
doesn't apply there.

## Message grammars (orchestrator → task, via `SendMessage`)

Five messages, each with the exact fields the receiving `task-runner`
expects (see `task-lifecycle`'s *Delegated mode* section for the
receiver side of each):

```
=== RESUME <task-id> ===
PAUSE_ID: <the id from the pause block being answered — echoed exactly>
ANSWERS: <the human's decision, in the shape the PAUSE_KIND calls for:
          APPROVED | AMEND: <text> | RE-PLAN: <text> for PLAN_APPROVAL;
          one line per item for NEEDS_DECISION / QA_FINDINGS
          (fix / defer / ignore, per finding) / MATERIAL_DEVIATION>
CONTEXT: <ripple info, if any — e.g. what a sibling's deviation changed>
CONTINUE_FROM: <the step named in the pause's RESUME_AT>
```

```
=== HOLD <task-id> ===
SIBLING: <the deviating task's id>
REASON: <why this task is affected — a depends-on edge or a
         collision-scan path overlap>
ACTION: finish your current tool call, make no further edits, commits, or
        pushes, and reply immediately with a TASK-RESULT HELD block,
        setting HOLD_REF to this message's SIBLING value.
```

```
=== RELEASE <task-id> ===
```

No other fields — a `HELD` task accepts this unconditionally, since it
carries no `PAUSE_ID` to match against (see the `HELD`/`PAUSE_ID` note
above).

```
=== RESOLVE-CONFLICT <task-id> ===
SIBLING: <the merged sibling's task-id and PR url>
PATHS: <the conflicting paths, from gh's mergeStateStatus/mergeable data>
ACTION: merge the feature-integration branch into your own branch in your
        own worktree, resolve, re-run the project's test command, re-run
        code-critic, re-run scripts/review-ok.sh, and report COMPLETE
        again with the new REVIEWED_SHA. Raise NEEDS_DECISION instead of
        deciding if resolution changes behaviour beyond mechanical
        reconciliation.
```

```
=== WIND-DOWN <task-id> ===
REASON: cancelled | re-scoped
ACTION: commit or clearly report uncommitted work, push nothing further,
        and reply with TASK-RESULT BLOCKED / BLOCKED_KIND: WOUND_DOWN,
        naming what is done versus not.
```

## Relay protocol

On a `TASK-RESULT` with `STATUS: PAUSED`: present `ASK:` verbatim to the
human, labelled with the task id and its scope. Wait. Then `SendMessage` a
`RESUME` — echoing the exact `PAUSE_ID` from the pause — to that task by
name, and only that task. Never answer on the human's behalf, never batch
two tasks' distinct questions into one answer.

**A `TASK-RESULT` that doesn't parse — unknown status, a missing required
field, an out-of-enum value — is treated as `BLOCKED` / `DEAD`, the raw
text shown to the human, never interpreted charitably.** Use the same
two-tier distinction the ripple handling below defines: a task that has
produced no result block for 15 minutes but still shows tool activity is
reported as *in a long-running step — last activity `<T>`*, not as a
problem; only a task with no result block **and** no tool activity at all
for the full 15 minutes is escalated, and if that persists to 30 minutes
with still no activity, it is marked `BLOCKED` / `DEAD` and its
branch/worktree reported. Never wait forever, never kill a task yourself.

**If `SendMessage` itself is unavailable or fails when resuming a task**
(confirmed working in this repo, but flagged as a harness behavior that
could differ elsewhere): STOP and report it, then offer the human an
explicit, degraded fallback rather than silently giving up or silently
restarting — re-launch the task as a **fresh** `task-runner`, re-briefed
with: the original task scope, the human's answers to whatever it was
paused on (verbatim), and a note that a previous attempt reached a named
step with branch `<x>` and last commit `<sha>`. This loses conversational
context; it does not lose committed work, since the branch and its
commits are untouched. Never choose this path without telling the human
first.

**A pause arriving from a task the human already asked to wind down or
cancel:** acknowledge it, but do not present it to the human as a live
question awaiting an answer — the task's fate is already decided.
Instead fold it into the cancellation report (below): note what the task
was asking when it was told to stop, alongside its final state.

## Ripple handling (material deviation)

On `PAUSE_KIND: MATERIAL_DEVIATION`, before presenting anything to the
human:

1. Compute the impact set: tasks declaring `depends-on` the deviating
   task; tasks whose collision-scan path set intersects the paths the
   deviation names; already-merged tasks the deviation calls into
   question.
2. `SendMessage` `HOLD` to every **running** task in the set; do not
   launch any **pending** task in the set.
3. **Wait for a `HELD` acknowledgement from each**, up to 15 minutes (the
   same liveness tier used above — a `HOLD` sent mid-way through a long
   nested pass like `code-critic` on `opus` or a full test suite routinely
   takes several minutes to acknowledge, since `SendMessage` queues to the
   task's next turn boundary rather than interrupting it). **Use the same
   two-tier label as above — do not collapse it to one:** a task with no
   activity signal yet within the window is listed as *"in a long-running
   step — last activity `<T>`"*, not as unresponsive; only a task that has
   also gone quiet for the full liveness window (no tool activity at all,
   not just no `HELD`) is named *unresponsive — may still be committing*,
   with its last known commit. Collapsing these to one label is exactly
   the failure mode this design exists to avoid: a `HOLD` sent during a
   normal long step would otherwise read as the *same* alarm as a task
   that has actually gone silent, training the human to ignore the
   signal. The screen is presented at the timeout regardless, not
   deferred indefinitely. This wait is what makes "every affected sibling
   is already held" a checked fact rather than a hope.
4. Present one combined screen: the deviation, the impact set with a
   reason and a state (`held` / `in a long-running step` / `unresponsive`)
   per entry, and the
   options — accept and re-scope the affected tasks, reject, or
   re-decompose the remainder.
5. Only then `SendMessage` `RESUME` (for a paused task) or `RELEASE` (for
   a held-but-not-otherwise-paused task) to each, carrying the decision.

## Staleness and conflict

After each merge into the feature-integration branch, re-check every
still-open task PR: `gh pr view <n> --json mergeable,mergeStateStatus`. On
`CONFLICTING`/`DIRTY`, do **not** resolve it yourself: `SendMessage`
`RESOLVE-CONFLICT` to that task's still-resumable sub-agent (see its own
handling in `task-lifecycle`'s *Delegated mode*). Surface the resolution
to the human like a material deviation — what conflicted, how it was
resolved, the new `REVIEWED_SHA` — before that PR is treated as mergeable.
If the sub-agent is no longer resumable (worktree swept, session limits),
STOP and hand the human the branch name, the conflicting paths, and what
still needs re-review. Never resolve a conflict in your own checkout.

**`REVIEWED_SHA` cross-check, repeated, not cached.** Before treating any
`COMPLETE` as done — including a re-`COMPLETE` after `RESOLVE-CONFLICT` —
run `gh pr view <n> --json headRefOid` and compare to the reported
`REVIEWED_SHA`. Run it again immediately before telling the human a PR is
ready to merge, not just once: `headRefOid` can change out of band after a
validated `COMPLETE` (a human clicks GitHub's "Update branch," or pushes a
fixup directly), and a single check would miss that window. A mismatch
means commits landed after the recorded review — the task is not done;
relay the mismatch and request a re-review if the task is still
resumable. This is the one place you can cheaply verify Rule 4 actually
held inside a worktree you otherwise can't see.

## Closure

Once every task has merged:

1. Fast-forward your local HEAD to the feature-integration branch's tip.
2. Run the project's run-all-tests command (`AGENTS.md` → *Commands*).
   Failure: STOP and report; do not open the final PR.
3. Invoke `code-critic` once, model `opus`, over
   `<default-branch>...<integration-branch>`, passing the approved
   breakdown plus every task's Approval Summary. This counts as the
   security-surface second review this repo's Step 9 otherwise requires —
   every constituent task diff was already reviewed once at task level,
   so a further pass on top of one covering the full merged content would
   be reviewing the same work a third time for no new signal.
4. If the feature has a UI/API surface, invoke `adversarial-qa` once on
   the integration branch, narrowed explicitly to the seams between
   tasks — each task already got its own adversarial pass.
5. Relay any `NEEDS_DECISION`/findings; fix or defer per the existing
   dispositions; re-run `code-critic` after any change.
6. `scripts/review-ok.sh` on the integration branch's HEAD — this is what
   makes the final `gh pr create` legal under Rule 4.
7. `gh pr create --base <default-branch> --head <integration-branch>`
   with a body carrying: the breakdown, one row per task (task → its PR →
   its AC → test table), the closure verdict, every deferred
   `known-issue`, and the test evidence line.
8. Close the tracker parent per its configured command (or note the
   tracker has no parent concept).
9. **Rollup** to the human: what shipped, every task's PR, every
   deferred/known issue, the closure verdict, anything left on disk from
   a cancelled task — and the `worktree.baseRef` exit reminder below.

**`worktree.baseRef` exit reminder.** State plainly, every time closure
runs: *"`worktree.baseRef: head` is still set, in `<the file it came
from>`. This affects every worktree-isolated agent in this project, not
just `/feature`'s tasks. To remove it, delete the `worktree` key from that
file."* A setting turned on for one feature should not silently outlive
it unremarked.

## Cancellation and mid-flight re-scope

- **Running task:** `SendMessage` `WIND-DOWN` first; expect
  `BLOCKED`/`WOUND_DOWN` carrying `LAST_COMMIT`/`WORKTREE`/`BRANCH`. Only
  if it does not respond does the human hard-stop it (Esc / the
  session's own task controls) — never hard-kill a task you could still
  have resumed; a hard-killed sub-agent cannot be resumed by `SendMessage`
  afterward.
- **Pending task:** just edit the breakdown and re-present the changed
  rows as a delta screen.
- **Afterwards:** set the tracker item to the configured blocked/cancelled
  status with a comment naming the branch. Never delete a branch or
  worktree yourself (Rule 3; the harness's own sweep also skips worktrees
  holding work). Report to the human: branch name, last commit SHA,
  worktree path, what is done versus not, and the `git worktree remove`
  command they *may* run — for them to run, never for you to run.
