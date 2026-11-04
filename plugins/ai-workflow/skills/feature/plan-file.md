# /feature — the saved plan file

Part of `/feature` (`SKILL.md` beside this file). Step 1d (*Save*), a
re-approval (*Rewrite*), `--from-plan` (*Location*) and step 9 (*Mark
consumed*) point here.

## Location

`.workflow-plans/<slug>.md` under the **main worktree**: the parent of the
`.git` dir printed by `git rev-parse --path-format=absolute --git-common-dir`.
That parent still contains a `.git` segment (e.g. a submodule), or the dir's
name is not `.git` (a bare repo) → ask the user where to write (for
`--from-plan`, where to read).

## Save (step 1d)

- Write the plan to the *Location* path. Ensure the directory exists and has
  a `.gitignore` containing `*`, so plans are never committed. The slug must
  match `a-z0-9-`, max 30 characters (a rename that doesn't → ask again).
  File exists → ask: overwrite or rename the slug (fold the new slug into the
  plan text: `**Slug:**` and every `AC-`/`EDGE-` ID and tag, as at 1c); never
  overwrite silently. The critique the user approved against is saved with
  the plan, verbatim, with each suggested amendment marked folded or not
  applied; omit the section if 1b was skipped
  ```
  ---
  slug: <slug>
  base-commit: <recorded SHA>
  depends-on: [<slug>, ...]
  tier: <0|1|2>
  ---

  <approved plan text, amendments folded in>

  # Plan-critic review

  <critique: Confidence, findings, suggested amendments (folded / not applied)>
  ```
  `tier` is the number on the approved plan text's `**Tier:**` line, taken
  after approval edits are folded in. `depends-on` is as in `plan.md` 1a
  (`--plan-only`), and `[]` in any other run
- Remember the absolute path written. A write that fails (resolve, mkdir,
  write) → STOP per Rule 2

## Rewrite (after a re-approval)

- Plan re-approved through the 1c substantive-change path after this write:
  before rewriting, check the file still has the `slug`, `base-commit` and
  exact content this run last wrote to it (content no longer available, e.g.
  after context compaction → can't verify → ask), else treat it as a
  foreign file and ask as in *Save*. Then
  rewrite the same file, no collision question: the re-approved text, the new
  critique, `tier` re-copied, `base-commit` and `depends-on` kept. A renamed
  slug → write the new path (collision rule applies), then remove the old file
  this run wrote, only if it still passes the same check. A minor deviation at
  step 2 does not rewrite

## Mark consumed (step 9)

After the PR opens, check the file (saved at 1d, or read by `--from-plan`)
still has the `slug`, `base-commit` and content this run last wrote at 1d or
*Rewrite* (or read, for `--from-plan`), then set the frontmatter's `consumed: <PR URL>` line
(replacing any existing one; that line itself is not part of the comparison).
A mismatch or content no longer available → ask. The edit fails → report the
PR URL and the failure per Rule 2. PR not opened → no marker
