# /feature — step 9: PR

Part of `/feature` (`SKILL.md` beside this file, whose mode table decides when
this phase runs). Files named below are beside this one.

## Input

`build.md`'s *Output*: a committed HEAD with a passing review recorded, the
approved plan text, the plan file path if one was saved or read, the final
test evidence, the review and QA outcomes with every decision the user made
on them, and the run facts step 9 reports.

## 9. PR

Only after: code review passed, every QA finding dispositioned and every
Blocker decided (or QA skipped).

### Open the PR

**Review guide**: before opening the PR, run the `review-guide` skill. It
returns the Tier line and the Review guide. Pass it the default branch and the
plan source: the plan file path this run last wrote (1d or `plan.md` →
*Rewrite*) or `--from-plan` read;
`--plan-reapproved` after a `--from-plan` step 2 material deviation; nothing
if no plan file was saved. Its paths are plain until the PR is open; then apply
its step 4 (links) with the PR URL before posting the first comment.

The PR description usually becomes the merge commit message: keep it short
and commit-ready. Pipeline details go in the first PR comment.

**PR description** (about 10–15 lines):
- **What and why**: requirements + approach in a few sentences, the decisions
  that shape the change (one line each), link to the source spec if any
- **Tier**: the Tier line `review-guide` returned
- **Test evidence**: one line, test count + result of the final full run (no
  suite: walkthroughs run + result, naming any waived)
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
  the walkthrough and its result). Every ID has a row with at least one test
  or walkthrough
- **Review outcome**: final verdict, each `NEEDS_DECISION`, Open Question and
  user-overridden FAIL, and the user's decision; for the second reviewer
  (`build.md` step 4), each `/code-review` finding as fixed, the user's
  decision, or a duplicate of a `code-critic` item, or that the user chose to
  proceed without it
- **QA outcome**: findings + disposition (fixed / deferred with task id /
  ignored), any Blockers and the user's decision (including a partial or
  skipped QA run and why), or "skipped: no UI or API surface". Describe in
  words; no `.qa-evidence/` paths

**Plan file**: after the PR opens, run `SKILL.md` → **Ownership check** on the
file at the path this run last wrote (1d or `plan.md` → *Rewrite*) or read
(`--from-plan`), then set the frontmatter's `consumed: <PR URL>` line
(replacing any existing one). The check fails → ask. The edit fails → report
the PR URL and the failure per Rule 2. PR not opened → no marker

### After the PR is open

Any commit made once the PR is open (e.g. fixes after a review comment):
- Follow `build.md` step 6 (re-run step 3, commit, re-review, record) before
  pushing
- Then run `review-guide` again, passing the PR URL, and replace the Tier
  line and the guide

## Output

- Open PR with the description and the first comment above
- The plan file marked consumed, if one was saved or read
