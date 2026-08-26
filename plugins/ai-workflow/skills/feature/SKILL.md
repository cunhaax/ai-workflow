---
name: feature
description: >
  Runs the full feature workflow. A single-task request goes straight
  through plan, critique, implement, review, QA. A request spanning
  several PRs is clarified, decomposed, tracked, and orchestrated as
  multiple isolated tasks. Use this when starting new feature work of
  any size.
---

# /feature — AI-Assisted Development Lifecycle

Activate this skill for non-trivial features or changes.

## Preconditions — check the branch first

The workflow assumes the human started this session on a fresh branch: the
single-task path's code review diffs against the default branch (named in
`AGENTS.md` → *Commands*) and opens a PR targeting it, neither of which
works from the default branch itself. If the session is on the default
branch, STOP and ask the user to create a branch — you may not create or
switch branches yourself (Rule 3 in `AGENTS.md`).

## Clarify the request

Enter plan mode now, before drafting anything. Clarify the request with the
human — question requirements, resolve ambiguity, follow any referenced
docs or links by delegating the fetch to the `planner` sub-agent (never
fetch directly — regardless of platform).

**State which path you're taking, and give the human a beat to object,
before doing anything else with write access:** *"Treating this as a
single task: `<one-line restatement of scope>`. Say so now if this should
be broken up."* This is not a formality — it is what stops a
misjudged-as-simple request from silently getting the write access that
should only follow an explicit decision, human or otherwise.

## Apply `task-lifecycle`

Apply the `task-lifecycle` skill for the single-task path, inline, as the
main agent — todays' plan → critique → implement → test → code-review → QA
→ PR loop, unchanged. Retain the plan text; you will need it later for the
`code-critic` and `adversarial-qa` sub-agents `task-lifecycle` itself
invokes.

---

## Important Rules

- NEVER decide this is a single task without stating so and giving the
  human a chance to object first. Silent self-classification is exactly
  the gap that lets a mis-triaged request slip past planning and review.
- NEVER fetch external links or docs directly — always delegate to the
  `planner` sub-agent, regardless of platform.
- NEVER present work to the user before `task-lifecycle`'s `code-critic`
  step has reviewed it.
- Everything `task-lifecycle` itself requires (planner-first, plan-critic
  by default, relaying `NEEDS_DECISION`, code-critic before presenting
  work) applies here unchanged — see that skill's own Important Rules.
