---
name: feature
description: >
  Runs the full feature workflow. A single-task request goes straight
  through plan, critique, implement, review, QA. A request spanning
  several PRs is clarified, decomposed, tracked, and (once execution
  lands) orchestrated as multiple isolated tasks. Use this when starting
  new feature work of any size.
---

# /feature — AI-Assisted Development Lifecycle

Activate this skill for non-trivial features or changes.

See `feature/decomposition.md` for the multi-task path's triage criteria,
decomposition rubric, collision scan, self-critique lenses, and approval
screen template — this file covers the flow between them.

## Preconditions — check the branch first

The workflow assumes the human started this session on a fresh branch: the
single-task path's code review diffs against the default branch (named in
`AGENTS.md` → *Commands*) and opens a PR targeting it; the multi-task
path's tasks diff against and target the feature-integration branch this
session's own branch must be. Neither works from the default branch
itself. If the session is on the default branch, STOP and ask the user to
create a branch — you may not create or switch branches yourself (Rule 3
in `AGENTS.md`).

## Clarify the request

Enter plan mode now, before drafting anything. Clarify the request with the
human — question requirements, resolve ambiguity, follow any referenced
docs or links by delegating the fetch to the `planner` sub-agent in digest
mode (never fetch directly — regardless of platform).

## Triage

Apply `feature/decomposition.md`'s triage criteria to decide whether this
is a single task or several. **State which path you're taking, and give
the human a beat to object, before doing anything else with write
access** — this is not a formality, it is what stops a misjudged
classification from silently granting write access (single-task path) or
imposing decomposition ceremony (multi-task path) nobody asked for.

### Single-task path

Apply the `task-lifecycle` skill inline, as the main agent — today's plan
→ critique → implement → test → code-review → QA → PR loop, unchanged.
Retain the plan text; you will need it later for the `code-critic` and
`adversarial-qa` sub-agents `task-lifecycle` itself invokes.

### Multi-task path

**Preconditions, checked before the approval screen is drawn (so failures
appear on it) and re-checked before anything is written:**

| | Check | Failure |
|---|---|---|
| P0 | Claude Code ≥ v2.1.206 (`claude --version`; undetermined output → treat as this row passing with a note, never a hard failure) | **WARN**: this floor matters once execution (a later addition to this skill) actually runs; note it now so it isn't a surprise later |
| P3 | Current branch has an upstream on `origin` (`git rev-parse --abbrev-ref --symbolic-full-name @{u}`) | STOP: give `git push -u origin <branch>` — and note explicitly that this push has nothing to review yet (the branch is identical to the default branch at this point), so `--no-verify` is safe here specifically, not a general license |
| P4 | `AGENTS.md` → *Task Tracking* has no remaining `[TODO:` | STOP: name the unfilled fields; point at `/init-workflow` |
| P5 | `scripts/check-hook-status.sh` reports `ACTIVE` | STOP: the review gate must be enforced before any task pushes |
| P8 | `gh api repos/{owner}/{repo}` → `allow_merge_commit` is true, AND `gh api repos/{owner}/{repo}/branches/<integration>/protection` → `required_linear_history` is not set (run only after P3 confirms the branch exists on the remote — a 404 before that point is ambiguous between "unprotected" and "branch doesn't exist yet"; once the branch exists, 404 = unprotected/fine, 403 = unknown/warn, not fine) | STOP: a squash-only repository breaks the ancestry check the dependency model relies on; default-branch protection is not checked here and can still affect the final PR later |
| P2 | `worktree.baseRef` resolves to `"head"` (report which of `~/.claude/settings.json` / `.claude/settings.json` / `.claude/settings.local.json` supplied it; if the user-global file, warn the blast radius is every repository, not just this one) | **WARN** — "execution will be unavailable until this is set; the breakdown and tickets still proceed" |
| P6 | `.claude/worktrees/` is gitignored | **WARN**, same reasoning as P2 |
| P7 | If `.gitignore` mentions `.env*`, a `.env` exists, and no `.worktreeinclude` exists | WARN — task worktrees are fresh checkouts and won't have it |

None of these run on the single-task path — an unconfigured tracker or an
unset `worktree.baseRef` must never block a plain single-task request.

**Decompose, scan, self-critique, present.** Follow
`feature/decomposition.md` exactly: decompose into tasks, run the bounded
collision scan, apply the three self-critique lenses, then present the
approval screen it specifies — including the precondition results above.
Nothing is written until the human approves.

**File tracker items.** Once approved, execute the tracker commands shown
on the approval screen exactly as shown: parent/epic first (if the
tracker has one), then one item per task, then dependency links, then each
task's initial status. If any command fails, STOP per Rule 2 with the
exact command and output, and report precisely which items were created —
never retry with a different form. If `AGENTS.md` → *Task Tracking* →
`Tracker` is `none`, follow `feature/decomposition.md`'s durable-record
fallback instead.

**End of what this skill does today.** Once tickets are filed (or the
durable record is written), tell the human plainly: the breakdown is
approved and tracked, and running each task is theirs to drive — create a
branch off the feature-integration branch per task, run `/feature` on it,
and tell it the base branch is the feature-integration branch, per the
approval screen's per-task run instruction. Orchestrating that execution
automatically is a planned addition to this skill, not yet present.

---

## Important Rules

- NEVER decide this is a single task without stating so and giving the
  human a chance to object first. Silent self-classification is exactly
  the gap that lets a mis-triaged request slip past planning and review —
  and on the single-task path specifically, it is what would let this
  skill write and commit code without ever having stated it was doing so.
- On the single-task path, this skill may write files and commit **only**
  after that confirmation beat. On the multi-task path (today) it writes
  nothing to the repository itself — only tracker entries, and only after
  the breakdown is approved.
- NEVER fetch external links or docs directly — always delegate to the
  `planner` sub-agent, regardless of platform.
- NEVER present work to the user before `task-lifecycle`'s `code-critic`
  step has reviewed it.
- NEVER decompose a multi-task request without presenting the full
  approval screen first — no tracker item exists before that approval.
- NEVER act unilaterally on a collision flag — it is advisory input to the
  human's decision, never a verdict this skill enforces by reordering,
  merging, or dropping tasks.
- NEVER create, switch to, or remove a branch or worktree yourself (Rule 3
  in `AGENTS.md`) — the human creates the feature-integration branch, the
  same as they already create a task branch today.
- Everything `task-lifecycle` itself requires (planner-first, plan-critic
  by default, relaying `NEEDS_DECISION`, code-critic before presenting
  work) applies here unchanged — see that skill's own Important Rules.
