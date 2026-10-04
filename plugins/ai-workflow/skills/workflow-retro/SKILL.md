---
name: workflow-retro
description: >
  Records a feature's workflow outcome (steps run or skipped, review rounds,
  what each critic caught, short judgment) as a fixed-schema file in
  .workflow-log/. Use at the end of a /feature session, after the PR is
  opened or the feature is abandoned.
license: MIT
metadata:
  author: André Cunha
---

# /workflow-retro

Record what the workflow did for this feature: which steps ran, what each
caught, what that changed. Run at the end of a feature session (after the PR
is opened, Step 9 of `/feature`) or when the feature is abandoned.

This is the **outcome half** of the record. The **cost half** is appended
later by `/workflow-inspect`; until then (or if it isn't installed), the Cost
section stays `pending`.

## Input

- This session's artifacts: PR description and comments, `git log`, plan / critique / review / QA
  outputs
- Current branch

## Ground rules

- **Facts come from artifacts**, not memory alone, when an artifact exists.
  Anything not established → `unknown`, never a guess
- **The log is local evaluation data.** `.workflow-log/` is gitignored; never
  commit it or move it into repo history
- **One file per feature branch.** File exists for the current branch (a
  previous retro, or a multi-session feature) → update it (fill gaps, correct
  facts, append the new session ID), no duplicate. Never overwrite a `## Cost`
  section that `/workflow-inspect` already filled: the Step 3 template's
  `pending` text is for new records only
  - Appending a session ID to a record whose Cost is already filled → keep
    the numbers and add `pending re-inspection — sessions added since the
    last inspect` as the first line of the section, so `/workflow-inspect`
    picks the record up again
  - Exception: the file evidently records a *different* feature that reused
    the branch name (its PR is already merged, or its dates are far from this
    session's) → ask the user: replace it, or pick another filename. Never
    merge two features into one record
- The only mutation is writing the log file (and creating its directory)
- Assumes a `/feature` session. Partial workflow (ad-hoc `/plan-draft`,
  review-only pass) → record what applies, mark the rest `n/a`

## Steps

### Step 1 — Locate the log target

- Path: `.workflow-log/<branch>.md` under the repository's **main worktree**
  (feature worktrees get deleted after merge; the log must outlive them)
- Resolve with a single `git rev-parse --path-format=absolute --git-common-dir`:
  the **parent** of the printed shared `.git` dir is the main worktree root
  (in a plain clone, the repo root)
- Sanity check: the resolved parent path still contains a `.git` segment
  (e.g. a submodule, whose common dir is under the outer repo's
  `.git/modules/`) → unusual layout; ask the user where the log should live
  instead of writing there
- `<branch>` = branch name with `/` replaced by `-` (`feat/login-form` →
  `.workflow-log/feat-login-form.md`)
- Create the directory if missing. File exists → this run updates it

### Step 2 — Capture the session pointers

Record the pointer now: `/workflow-inspect` runs in a later session that
can't know which transcript was the feature session. Transcripts are pruned
after Claude Code's `cleanupPeriodDays` (~30 days by default); the join must
happen within it.

Get the current session ID, in order:
1. `printenv CLAUDE_CODE_SESSION_ID` (single command). Its value is the
   session ID; the transcript is `<session-id>.jsonl` somewhere under
   `~/.claude/projects/`
2. Unset → heuristic: the most recently modified `.jsonl` anywhere under
   `~/.claude/projects/` (a single `find`), searched globally since
   transcripts are filed under the session's *launch* directory, not
   necessarily the current worktree's
   - More than one transcript modified in the last few minutes (concurrent
     sessions) → ask the user which one; never pick silently
3. Neither works (variable unset, directory missing or ambiguous) → record
   `Sessions: unknown`. Both the variable and the on-disk layout are
   undocumented Claude Code behavior; a wrong-but-plausible ID silently
   corrupts the later cost-join, an honest `unknown` merely skips it

Also:
- Feature spanned earlier sessions → record their IDs too (ask the user if
  they can identify them, e.g. by date); otherwise `earlier sessions: unknown`
- Record the **current worktree's absolute path** (`Project path` field). The
  session ID is the load-bearing pointer: `/workflow-inspect` finds
  transcripts by global search for `<session-id>.jsonl`, never by deriving a
  directory from this path

### Step 3 — Fill the record

Draft the file with exactly this structure (fixed schema; later tooling
aggregates across files, so keep headings and field labels verbatim):

```markdown
# Workflow retro — <branch>

- Date: <YYYY-MM-DD of this retro>
- Branch: <branch>
- PR: <url | not opened | abandoned>
- Plugin version: <installed workflow plugin version, if discoverable | unknown>
- Sessions: <session ID(s), oldest first | unknown>
- Project path: <absolute path(s) of the worktree(s) the sessions ran in | unknown>

## Steps

| Step | Ran? | Notes |
|------|------|-------|
| 1a planner | yes / skipped / n/a | <why skipped, if skipped> |
| 1b plan-critic | yes / skipped / n/a | <why skipped, if skipped> |
| 1c approval | yes / n/a | plan revisions before approval: <N> |
| 2 implement | yes / n/a | deviations: <N> minor, <N> material |
| 3 tests | yes / n/a | final full run: <N> tests, <pass/fail> |
| 4–6 code review | yes / n/a | rounds: <N>; FAIL items: <N>; NEEDS_DECISION: <N>; Open Questions: <N> |
| 7–8 QA | yes / skipped / n/a | <why skipped>; findings: <N>; blockers: <N> |
| 9 PR | yes / n/a | |

## Findings

- plan-critic: <N> findings; adopted into plan: <N>; discarded: <N>
- code-critic FAIL items, one line each: <what, and the fix or the user's override>
- NEEDS_DECISION items, one line each: <what, and the user's decision>
- Open Questions, one line each: <what, and the user's decision>
- QA findings, one line each: <what, and its disposition (fixed / deferred
  <task id> / ignored)>
- QA blockers, one line each: <what, and the user's decision>

## Judgment

- Did the planner's plan contain anything the implementer would not have
  found alone? <answer>
- Which plan-critic findings changed the plan? <answer | none>
- Did implementation re-read files the planner had already read?
  (best-effort — /workflow-inspect computes this exactly) <answer>
- Did any step produce nothing of value this feature? <answer | none>

## Cost

pending — run /workflow-inspect before the session transcripts are pruned
```

- Steps and Findings: factual, from the artifacts
- Judgment: the implementer's honest assessment from what happened this
  session, one sentence each; `unknown` is acceptable

### Step 4 — Confirm and write

- Present the drafted record in one block for the user to confirm or correct
  (the Judgment answers are theirs to override)
- Write the file; report its path
- Do not commit anything

## Output

- `.workflow-log/<branch>.md` (new or updated); Cost left as it is (marked
  `pending re-inspection` if sessions were added), or `pending` if the
  record is new
