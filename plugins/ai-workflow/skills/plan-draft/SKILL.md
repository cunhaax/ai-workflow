---
name: plan-draft
description: >
  Planning rules and plan template for drafting implementation plans.
  Invoked as /plan-draft for an ad-hoc planning session, or used by the
  planner sub-agent in the /feature workflow. (Named plan-draft so it does
  not collide with Claude Code's built-in plan-mode /plan command.)
---

# /plan-draft

Standalone (`/plan-draft`) or applied by the `planner` sub-agent in `/feature`.

## Input

- User prompt (primary source), incl. any links/doc references

## Steps

### 1. Gather context

- Prompt links/docs → fetch before planning
- Read: module-specific `AGENTS.md` in likely-affected directories,
  `docs/adr/`, relevant `docs/` product docs
- Do not ask the user from a sub-agent; ambiguities go in the plan as
  `NEEDS_DECISION`

### 2. Draft the plan

Fill the template below, following these rules.

**Approval Summary** (read on a phone; what the developer approves)
- Goal: 1–2 sentences
- One line per acceptance criterion, per key decision, per `NEEDS_DECISION`
- No total line cap. More than ~10 criteria → split the task
- Criterion = user-visible behaviour, not implementation
  ("a visitor submitting an invalid form sees the error next to the field",
  not "add a guard clause")
- Number `AC-<slug>-n`. `<slug>` = current git branch name, minus one leading
  type prefix (`worktree-`, `feat-`, `feature-`, `fix-`, `bugfix-`,
  `hotfix-`, `chore-`, or similar), `/` → `-`, truncated to 30 chars
  (keeps tags unique across the suite)
- Every `AC-<slug>-n` maps to ≥1 Test Strategy entry tagged `[AC-<slug>-n]`;
  none → incomplete plan
- Sections below must never contradict the summary

**Other sections**
- **Contract**: written before Approach; end-to-end tests are coded against it
  - Full-stack: pin routes, fields/params, response shapes, error rendering,
    schema changes
  - Pure backend/infra: "None"
  - Deviating from it during implementation = material change, needs
    re-approval
- **Context & Decisions**: problem + solution shape in a few sentences, then
  every decision and every rejected alternative with its reason
  - Self-contained: nothing load-bearing may live only in the chat
- **Requirements**: complete, verbatim from the user or spec; never summarize
  or omit (`code-critic` cross-checks each against tests)
- **Files**: every touched file tagged `NEW`/`EDIT`/`DELETE`/`MOVE` + what
  changes and why (a diff file not listed = undiscussed change)
- **Out of Scope**: what a reader might expect but is deliberately excluded.
  "None" only if meant
- **Edge Cases**: list ALL, numbered `EDGE-<slug>-n` (same slug as ACs)
  - Every one maps to ≥1 Test Strategy entry tagged `[EDGE-<slug>-n]`;
    none → incomplete plan
- **Test Strategy**: cover happy path and every edge case
  - Every claim about user-visible behaviour (error placement, open/closed
    state, enable/disable, post-failure coherence, persistence-vs-UI
    consistency) maps to a committed end-to-end test that observes the
    rendered result (per project convention, e.g. Playwright)
  - No manual "Verification"/"QA checklist". "Try X and confirm Y" → make it
    a test assertion
  - Exception: environmental preconditions (e.g. "migration edited in
    place, reset local DB first") → **Environment & Preconditions**
- **Risks / SRP**: flag single-responsibility concerns in the approach
- Be concrete: name files, show key signatures/data classes, point at
  existing patterns by name (e.g. "mirror `ExistingValidator`")
- Plan contradicts an ADR → flag it and explain why to reconsider
- Ambiguous spec → `NEEDS_DECISION` with options
- Non-applicable sections (Out of Scope, Environment & Preconditions,
  NEEDS_DECISION): write "None", never drop them

## Output

- Plan as markdown text, per the template
- Write no files, no implementation code

## Plan Template

<!-- COUPLING NOTE: section names and semantics are consumed elsewhere.
     code-critic cross-checks diffs against Approval Summary / Contract /
     Requirements / Approach / Edge Cases / Test Strategy / Files / Out of
     Scope. feature presents the Approval Summary (Step 1c), writes the
     [AC-<slug>-n] tests first (Step 2), and builds the PR's AC → test table
     (Step 9). Add/rename/remove a section → update those consumers. -->

```markdown
# Implementation Plan: [Feature Name]

## Approval Summary
**Goal:** [1–2 sentences — what the user gains]

**Acceptance Criteria** (`<slug>` per rules above):
- AC-<slug>-1: [one line: given/when/then]
- AC-<slug>-2: [...]

**Key decisions:** [2–3 bullets, one line each]

**Risk flags:** security surface: [yes/no] · new persisted field: [yes/no] ·
sensitive-category data: [yes/no] · schema migration: [yes/no] ·
new dependency: [yes/no] · new/changed route: [yes/no]

**NEEDS_DECISION:** [one line each, or "None"]

*(The summary above is what the developer approves; everything below is the
detailed contract it stands on.)*

## Source
[User prompt summary / external doc title + URL]

## Context & Decisions
[Problem + solution shape. Decisions taken; alternatives rejected, each with reason.]

## Requirements
[Complete, verbatim. Do not summarize.]

## Contract  _(full-stack slices; "None" for pure backend/infra work)_
- Routes: [METHOD /path — purpose, required authority]
- Form fields / params: [name, type, validation rule]
- Response shape: [full page / fragment + target / redirect (per the
  project's redirect convention, if any)]
- Error rendering: [where errors surface, message keys]
- Schema: [tables/columns added or changed]

## Approach
[Step-by-step strategy. Existing patterns to follow, by name.]

## Files
- NEW    [path]: [what it holds / why]
- EDIT   [path]: [what changes / why]
- DELETE [path]: [why]
- MOVE   [old] → [new]: [why]

## Out of Scope
- [Expected but deliberately excluded]

## Edge Cases  _(same `<slug>` as Acceptance Criteria)_
- EDGE-<slug>-1: [Edge case]: [handling strategy]
- EDGE-<slug>-2: [...]

## Test Strategy
- [AC-<slug>-1] [test name]: [what it verifies]
- [AC-<slug>-2] [...]
- [EDGE-<slug>-1] [test name]: [what it verifies]

## Environment & Preconditions
[Non-behavioural setup, or "None".]

## NEEDS_DECISION
- [Ambiguity]: [options available]

## Risks
- [Anything that could go wrong or needs extra attention]
```
