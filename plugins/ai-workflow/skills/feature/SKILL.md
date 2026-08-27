---
name: feature
description: >
  Runs the full feature workflow. A single-task request goes straight
  through plan, critique, implement, review, QA. A request spanning
  several PRs is clarified, decomposed, tracked, and orchestrated as
  multiple isolated tasks running in parallel, with every approval
  relayed back to the human and an integration check at the end. Use
  this when starting new feature work of any size.
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
`adversarial-qa` sub-agents `task-lifecycle` itself invokes. `task-lifecycle`
defaults `BASE_BRANCH` to `AGENTS.md` → *Commands* → default branch; if the
human states this task belongs to a feature-integration branch instead
(the manual fallback in `feature/decomposition.md`'s per-task run
instruction, item 8), apply `task-lifecycle` with that `BASE_BRANCH`
explicitly instead of the default.

### Multi-task path

**Preconditions, checked before the approval screen is drawn (so failures
appear on it) and re-checked before anything is written:**

| | Check | Failure |
|---|---|---|
| P0 | Claude Code ≥ v2.1.206 (`claude --version`; undetermined output → treat as this row passing with a note, never a hard failure) | STOP: the floor exists for `SendMessage`'s sub-agent addressing and call-level worktree isolation, both load-bearing for scheduling and relay below |
| P1 | Not on the repository's default branch (same check as *Preconditions* above, restated here so it appears as a row on the approval screen) | STOP — see *Preconditions* above |
| P3 | Current branch has an upstream on `origin` (`git rev-parse --abbrev-ref --symbolic-full-name @{u}`) | STOP: give `git push -u origin <branch>` — and note explicitly that this push has nothing to review yet (the branch is identical to the default branch at this point), so `--no-verify` is safe here specifically, not a general license |
| P4 | `AGENTS.md` → *Task Tracking* has no remaining `[TODO:` | STOP: name the unfilled fields; point at `/init-workflow` |
| P5 | `scripts/check-hook-status.sh` reports `ACTIVE` | STOP: the review gate must be enforced before any task pushes |
| P8 | `gh api repos/{owner}/{repo}` → `allow_merge_commit` is true, AND `gh api repos/{owner}/{repo}/branches/<integration>/protection` → `required_linear_history` is not set (run only after P3 confirms the branch exists on the remote — a 404 before that point is ambiguous between "unprotected" and "branch doesn't exist yet"; once the branch exists, 404 = unprotected/fine, 403 = unknown/warn, not fine) | STOP: a squash-only repository breaks the ancestry check the dependency model relies on; default-branch protection is not checked here and can still affect the final PR later |
| P2 | `worktree.baseRef` resolves to `"head"` (report which of `~/.claude/settings.json` / `.claude/settings.json` / `.claude/settings.local.json` supplied it; if the user-global file, warn the blast radius is every repository, not just this one) | **WARN** — "execution will be unavailable until this is set; the breakdown and tickets still proceed" |
| P6 | `.claude/worktrees/` is gitignored | **WARN**, same reasoning as P2 |
| P7 | If `.gitignore` mentions `.env*`, a `.env` exists, and no `.worktreeinclude` exists | WARN — task worktrees are fresh checkouts and won't have it |
| P9 | A concurrency guard is detected (`AGENTS.md` → *Commands* points at `make` targets, or an equivalent the human confirms) — checked only when the breakdown has 2+ tasks and at least one has a UI/API surface | WARN — name the risk (concurrent tasks may collide on a shared dev server or database) and point at `/init-workflow`'s concurrency-guard question; not a hard stop, since a project may have its own equally valid answer that doesn't look like the scaffolded template |

**P2 and P6 are re-checked immediately before the first task launches and
are hard STOPs at that point** — a task launched without `"head"`
resolution would silently branch from the wrong ref, defeating the
dependency model with no visible error. See `feature/delegation.md`.

None of these run on the single-task path — an unconfigured tracker or an
unset `worktree.baseRef` must never block a plain single-task request.

**Decompose, scan, self-critique, present.** Follow
`feature/decomposition.md` exactly: decompose into tasks, run the bounded
collision scan, apply the three self-critique lenses, then present the
approval screen it specifies — including the precondition results above.
Nothing is written until the human approves. **Exit plan mode here, on
approval** — the same point standalone `task-lifecycle` exits it on plan
approval; everything before this point (clarify, triage, decompose, scan,
self-critique) happens inside plan mode, same as drafting a single-task
plan does today.

**File tracker items.** Once approved, execute the tracker commands shown
on the approval screen exactly as shown: parent/epic first (if the
tracker has one), then one item per task, then dependency links, then each
task's initial status. If any command fails, STOP per Rule 2 with the
exact command and output, and report precisely which items were created —
never retry with a different form. If `AGENTS.md` → *Task Tracking* →
`Tracker` is `none`, follow `feature/decomposition.md`'s durable-record
fallback instead.

**Concurrency cap.** Ask for it on the approval screen (not before —
nothing in this skill executes until approval), default **2**. This is a
per-feature judgment call, not a stable project fact, so it has no
`AGENTS.md` knob. **If the dependency graph's critical path equals the
task count** (a mostly-linear breakdown), say so explicitly: effective
concurrency is 1 regardless of the cap, and this skill's value for such a
feature is the tracking, relay, and closure below — not parallelism.

**Schedule and launch.** See `feature/delegation.md` for the full detail:
launching a `task-runner` sub-agent per ready task (up to the cap), the
four-call readiness sequence, and why both `name` and call-level
`isolation` are required on every launch.

**Relay every pause.** A task sub-agent cannot enter plan mode — every
plan approval, `NEEDS_DECISION`, QA finding, and material deviation it
raises comes back to you as a `TASK-RESULT` pause, and you relay it to the
human and resume the task with the answer. See `feature/delegation.md`
for the exact protocol, including the ripple handling a material
deviation triggers (holding affected siblings, *and waiting for their
acknowledgement*, before presenting the deviation) and how a
sibling-caused conflict on an already-open task PR gets resolved and
re-reviewed rather than silently merged.

**Closure.** Once every task has merged into the feature-integration
branch: run the project's tests, one `code-critic` pass over the whole
integration diff, `adversarial-qa` narrowed to cross-task seams if there's
a UI/API surface, then the final integration-branch → default-branch PR
and a rollup for the human. Full procedure, including the exact
`worktree.baseRef` exit reminder text, in `feature/delegation.md`.

**Cancellation and mid-flight re-scope.** Prefer asking a running task to
wind down cleanly over hard-killing it — a hard-killed task cannot be
resumed. Full procedure in `feature/delegation.md`.

---

## Important Rules

- NEVER decide this is a single task without stating so and giving the
  human a chance to object first. Silent self-classification is exactly
  the gap that lets a mis-triaged request slip past planning and review —
  and on the single-task path specifically, it is what would let this
  skill write and commit code without ever having stated it was doing so.
- On the single-task path, this skill may write files and commit **only**
  after that confirmation beat. On the multi-task path it writes **no
  repository files and makes no commits, ever** — its only repo-mutating
  git commands are `git fetch` and `git merge --ff-only` on the branch
  it is already on (a fast-forward, not a branch switch — no Rule 3
  exception needed). Its other write actions are tracker commands, the
  final `gh pr create`, and `scripts/review-ok.sh` once at closure — never
  `git worktree`, `git branch`, `git checkout <branch>`, or `git push`.
- NEVER fetch external links or docs directly — always delegate to the
  `planner` sub-agent, regardless of platform.
- NEVER present work to the user before `task-lifecycle`'s `code-critic`
  step has reviewed it.
- NEVER decompose a multi-task request without presenting the full
  approval screen first — no tracker item exists before that approval.
- NEVER act unilaterally on a collision flag — it is advisory input to the
  human's decision, never a verdict this skill enforces by reordering,
  merging, or dropping tasks.
- NEVER launch a task whose prerequisite has not actually merged into the
  feature-integration branch (verified via `gh`/`git`, never a sub-agent's
  own say-so).
- NEVER answer a task's `NEEDS_DECISION`, QA disposition, or plan-approval
  question on the human's behalf — relay every one of them.
- NEVER hard-kill a task that could instead be asked to wind down — a
  hard-killed sub-agent cannot be resumed.
- NEVER create, switch to, or remove a branch or worktree yourself (Rule 3
  in `AGENTS.md`) — the human creates the feature-integration branch, the
  same as they already create a task branch today.
- Everything `task-lifecycle` itself requires (planner-first, plan-critic
  by default, relaying `NEEDS_DECISION`, code-critic before presenting
  work) applies here unchanged — see that skill's own Important Rules.
