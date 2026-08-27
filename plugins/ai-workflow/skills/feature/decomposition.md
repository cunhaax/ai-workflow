# Multi-task decomposition — reference for `/feature`

Sibling reference file for `plugins/ai-workflow/skills/feature/SKILL.md`,
covering the parts of the multi-task path detailed enough to deserve their
own file: triage criteria, the decomposition rubric, the bounded collision
scan, the inline self-critique, the approval-screen template, and the
`Tracker: none` fallback.

## Triage: single task, or several?

**Multi-task** if any of:
- the request names two or more independently reviewable deliverables,
- a natural implementation order exists where a later part cannot be
  written until an earlier part's interface exists,
- the plausible diff spans two or more of the project's *Architecture*
  modules with separate acceptance criteria,
- the human says so.

**Single-task** otherwise — explicitly including a change that touches many
files but has one acceptance story (a mechanical refactor, a rename, a
dependency bump). **Touching many files is not, by itself, a multi-task
signal.**

Either way, state which way you're going and give the human a beat to
object before doing anything else: *"Treating this as a single task: `<one-line
restatement>`. Say so now if this should be broken up."* or *"This looks
like `<N>` tasks: `<one line each>`. Say so now if you'd rather treat this
as one."* This is what stops a misjudged classification from silently
granting write access (single-task path) or imposing decomposition
ceremony (multi-task path) that the human didn't actually want.

## Decomposing into tasks

Each task must:
- fit one PR and one `task-lifecycle` session,
- carry a short id, a 2–4 sentence scope description pitched at
  "senior engineer explaining scope to a teammate" — no file paths, no
  function signatures, no schema. If a task's description needs a file
  list to be understandable, it is really an implementation plan and
  belongs in its own `planner` pass, not this breakdown — split or merge
  it until it doesn't,
- carry an explicit `depends-on` list of other task ids (or none).

The dependency graph must be acyclic and stated explicitly — never implied.
If the count exceeds roughly 8 tasks, say so and propose a narrower first
slice rather than presenting an unreviewable wall of tasks.

## Bounded collision scan

Per task, at most 3 searches: `rg -l` on the distinctive nouns in the
task's scope description, plus a glob for any directory it names. This is
a **path-set lookup, not code comprehension** — no reading file contents
beyond what the search output itself shows, no partial implementation
planning, no verdict. Record the resulting path set per task.

Across all tasks: flag any path that appears in **two or more** path sets
as an advisory `possible collision: T1 ∩ T3 → <path>`. Escalate any flagged
path that also matches an entry in `AGENTS.md` → *Sensitive Areas* to
`possible collision (sensitive area)`. These flags are advisory input to
the human's approval decision — never a verdict `/feature` acts on
unilaterally (it does not merge, reorder, or drop tasks on the strength of
a flag).

Skip this scan entirely for a one-task breakdown. Total search budget:
at most 3 × task count.

## Inline structural self-critique

Apply these three lenses to the breakdown before presenting it — the same
family of methods `plan-critic` applies to a full implementation plan,
adapted to a scoping artefact. Record a finding or an explicit "no
concerns, because …" for each; amend the breakdown before presenting if a
lens finds something:

- **Pre-mortem.** This feature shipped and something broke. Which task
  boundary caused it?
- **Missing dependency.** For each ordered pair of tasks, could the later
  one's plan be drafted with no knowledge of the earlier one's outcome? If
  not, the dependency edge is missing from the graph.
- **Consistency.** Does the task ordering contradict an ADR (`docs/adr/`)
  or the project's architecture rules? Does any task's scope contradict
  another's?

## The approval screen

Present, in this order, before writing anything (no tracker item, no
worktree, nothing):

1. Goal — one to two sentences.
2. The precondition results — pass/fail/warn, each with the exact fix for
   any failure (see `feature/SKILL.md`'s precondition table).
3. Task table: id · one-line scope · depends-on · collision flags
   (`SENSITIVE` marked).
4. Dependency graph (an indented DAG or a mermaid diagram), with a note
   when the critical path equals the task count: "this breakdown is
   effectively serial — expect no parallelism from running it as
   multiple tasks."
5. Self-critique findings.
6. The tracker actions about to be taken — the **literal commands**,
   expanded with real values, one line each, exactly as they will run.
   Not a description of them; the human is about to let this run
   unattended for every task.
7. The merge-strategy expectation for task PRs, and who merges them (the
   human, always).
8. How execution runs: `/feature` launches each ready task itself as an
   isolated sub-agent (up to the concurrency cap below), respecting
   dependencies — see `feature/delegation.md`. **Fallback, only if P2 or
   P6 are still unresolved** (`worktree.baseRef` not set to `"head"`, or
   `.claude/worktrees/` not gitignored): tell the human plainly that
   automatic execution is unavailable until that's fixed, and offer the
   manual alternative instead — create a branch off the
   feature-integration branch per task, run `/feature` on it, and tell it
   `BASE_BRANCH: <the feature-integration branch>` (see `feature/SKILL.md`'s
   single-task path for how it's consumed there).
9. What the human will be asked for later — plan approvals, `NEEDS_DECISION`s,
   QA dispositions, per task. This is not fire-and-forget.
10. The concurrency cap this run will use (default 2, changeable here) —
    see `feature/delegation.md` for how it's applied.

Nothing is written until the human approves. On a substantive change to
the breakdown after this point, re-present with a **delta** section first
— what changed relative to the previous version — so the human re-reads
only the change.

## `Tracker: none`

If `AGENTS.md` → *Task Tracking* → `Tracker` is `none`, skip filing tracker
items and state the real consequence on the approval screen, not as a
footnote:

> No tracker is configured, and this workflow has no cross-session resume.
> If this session is lost, the entire breakdown is lost with it — the task
> list, the dependency ordering, and the collision flags exist nowhere but
> this conversation.

Offer a zero-dependency durable record the human can accept or decline:
write the approved breakdown into the integration branch as either a first
commit (e.g. `FEATURE-BREAKDOWN.md`) or the body of an early draft PR. Both
survive a lost session, need no tracker, and cost one action.
