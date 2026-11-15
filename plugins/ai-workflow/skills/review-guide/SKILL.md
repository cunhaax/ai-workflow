---
name: review-guide
description: >
  Computes a PR's Tier floor and unplanned-changes list with a bundled
  read-only script, then writes the PR's Tier line and Review guide (decisions
  not in the plan, files to read closely vs skim, what to check by hand), and
  once the PR is open links each file to its diff. Use at /feature step 9
  before and after opening the PR, or when the user asks for a review guide for
  the current branch.
license: MIT
compatibility: Requires git and a POSIX sh with awk; file links use sha256sum or shasum when present.
metadata:
  author: André Cunha
---

# /review-guide

Gives a reviewer a short guide to where to look in a PR, split by trust: a
script computes the parts that must be trustworthy, and you write the parts
that need judgment. `/feature` step 9 calls this skill; it can also be run on
its own. It returns text for the caller to place. It never opens, edits or
comments on a PR.

## Input

- The default branch (`AGENTS.md` → *Commands*)
- The plan source, one of: the plan file's absolute path (the one `/feature`
  last wrote, at step 1d or on a rewrite after re-approval, or `--from-plan`
  read); `--plan-reapproved` (a `--from-plan`
  run re-approved at step 2, so its saved plan is stale); or nothing (no plan
  file was saved). Run standalone with none given → ask for the path or "none"
- The approved plan text's **Tier** line and the session's context (deviations,
  decisions made while implementing)
- The PR URL, once the PR is open (the one `gh pr create` printed; on a re-run
  in a resumed session, `gh pr view --json url -q .url`; never build it by
  hand). Without it, step 4 does not run

## Steps

### 1. Run the script

`sh ${CLAUDE_SKILL_DIR}/review-guide.sh <default-branch> [<plan-file> | --plan-reapproved]`

- Any non-zero exit, any stderr, empty stdout, an unexpanded
  `${CLAUDE_SKILL_DIR}` or a missing script → STOP per `AGENTS.md` Rule 2;
  never guess a path or work around it
- A `not computed` reason other than `no plan file` or the re-approved one →
  tell the user before going on
- Syntax, exit codes and limits are in the script's header comment

### 2. Tier line

`**Tier:** <n> — <reason>`

- n = the higher of the plan's tier and the script's floor (2 when it lists
  sensitive paths). A `set by user` plan line counts as the higher of its two
  values, and shows both (`1 (set by user; derived 2) → 2`)
- A judged prose area (step 3, not `unsure`) also raises n to 2, named in the
  reason as `<area> (judged, not computed)`; it never lowers n
- The plan's tier is the approved plan text's `**Tier:**` line (inside
  `/feature`, the one in context). Standalone, read it from the given plan
  file; with no plan, n is the floor, marked "no plan tier"
- The reason names each sensitive area touched, as a fact
- Floor or a judged area above the plan's tier → tell the user before the PR
  opens: `/feature` step 4's `opus` override and second reviewer may not have
  run, and the user decides whether to run them now (inside `/feature`:
  `build.md` step 4 on HEAD with both, counting as the second reviewer's
  first run if it has not run, else its one extra run (already used → the
  user decides whether to exceed it), then
  steps 5–6, steps 7–8 again if a fix touches a UI or API surface, then this
  skill again)

### 3. Review guide

For the reviewer; commit SHAs are allowed here. Each file is an entry once,
so the first place a reviewer meets it is its link:

- Every path from `git -c core.quotepath=off -c diff.relative=false diff
  --no-renames --name-only <base ref from the script's header>...HEAD` is an
  entry in exactly one of **Read closely** or **Skim**, copied, never typed
  from memory; the two lists' entries together equal its line count. Your
  other sections name a file by its short name (basename, plus the fewest
  parent directories that tell two changed files apart), never as a link or
  entry

In this order:

1. **Read closely**: `` - `<path>` — <tag> · <reason> ``, or "none". Tag
   `sensitive` for every path the script lists as sensitive, `judged: <area>`
   for a file judged under a prose area (below), `judged` for any other file
   you pick; several join with `, ` in that order, and entries are grouped by
   their first tag in that order before step 4
2. **Prose Sensitive Areas (judged, not computed)**, when the script prints
   `Not path-checked: <k>` or the branch's `AGENTS.md` diff removes a
   prose-only bullet (no leading backticked path, not a `[TODO` placeholder; read `git show HEAD:AGENTS.md`
   plus the removed ones, marked ` (removed on this branch)`). One line per area,
   named by its text before ` — `: the short names of each changed file whose
   diff changes behaviour it describes (not mere nearness), then
   `(see Read closely)`, else `none judged`. If unsure, still name the file;
   its *Read closely* reason starts `unsure`, and an area naming only `unsure`
   files does not raise the Tier. Your count differs from `<k>` → say so
3. **Decisions not in the plan**: one line each; every unplanned path
   accounted for, or "None"
4. **Check by hand**: what to try in the running app, or "nothing: no UI or API
   surface"
5. **Skim**: `` - `<path>` — <reason> ``, test files last, inside a
   `<details>` block with `<summary>Skim (<n> files)</summary>`. Leave a blank
   line before `<details>`, after `</summary>` and on both sides of
   `</details>`, or GitHub shows the list or what follows as raw text. None →
   `**Skim**: none`, no block
6. The script's stdout, verbatim, last, never inside `<details>`

### 4. Links

Only with a PR URL and a non-empty **Read closely** or **Skim**; with both
empty, skip it (the caller's incomplete-guide rule does not apply).

`sh ${CLAUDE_SKILL_DIR}/review-guide.sh --links <pr-url> <path>...`

- One call: pass every **Read closely** path, then every **Skim** path, in
  single quotes when it has spaces or shell-special characters
- Its lines replace those entries (split back into the two lists by argument
  order); append ` — <tag> · <reason>` to each (**Skim**: ` — <reason>`). A
  `Links: not computed (…)` line goes verbatim once, directly under
  **Read closely**, and tell the user
- Exit 1, any stderr or empty stdout → STOP per `AGENTS.md` Rule 2. Report the
  PR URL, the error and the guide with plain paths, ready to post by hand; the
  plan file stays unconsumed
- Never write a link by hand

## Output

The Tier line and the Review guide. The caller puts the Tier line in the PR
description and the guide at the top of the first comment. Before the PR opens
the entries are plain paths; step 4 links them once it is open, and the
description never carries links. Run again, and replace both, after any commit
made once the PR is open (including step 4).

## Rules

- Never alter, trim, collapse or contradict the script's output; it goes last,
  after your sections, and an omission in your own parts must stay visible.
  Its `→ none` covers computed paths only, so a judged raise beside it is not
  a contradiction
- Step 4's lines are entries to extend as step 4 says; never drop or reorder
  one or edit its path
- Never put the plan file's absolute path in the output: the script prints the
  basename only
