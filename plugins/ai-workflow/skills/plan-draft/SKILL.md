---
name: plan-draft
description: >
  Drafts a structured implementation plan (approval summary with acceptance
  criteria, contract, files, edge cases, test strategy) before any code is
  written. Use when the user asks for a plan or design for a feature or
  change, or before starting implementation.
license: MIT
metadata:
  author: André Cunha
---

# /plan-draft

Draft a structured implementation plan before any code is written.

## Input

- User prompt (primary source)
- Source contents: the full text of every link/ticket/doc the prompt
  references, already read by the caller, verbatim and labelled
- Prior plan and requested changes (optional; on a re-plan)

## Steps

### 1. Gather context

- Never fetch anything yourself. Prompt references a source you were not
  given (including a link inside a given source) → stop and return only
  `BLOCKED: need <source>`; never infer requirements from the branch name,
  the diff, or guesses
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
- Number `AC-<slug>-n`. Choose `<slug>` once and record it as `**Slug:**` in
  the Approval Summary
  - Format: lowercase `a-z0-9-`, max 30 chars
  - Content: ticket ID first, only if the prompt, linked spec, or tracker
    gives one (never invent one), then a short name for what the feature
    does (`proj-123-csv-export`); no ticket → short name alone
  - Unique across the suite: grep the repo for existing `AC-<slug>-` /
    `EDGE-<slug>-` tags; taken → pick another
  - Fixed after approval. Given a prior plan, keep its slug (this wins over
    the uniqueness grep: the grep may find the feature's own tags). A rename
    by the user at approval is final. Everything downstream reads it from the plan
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
     [AC-<slug>-n] / [EDGE-<slug>-n] tests first (Step 2), and builds the
     PR's plan ID → test table (Step 9), and checks the **Slug:** line, the
     AC numbering and the tagged Test Strategy entries before presenting the
     plan (Step 1c). adversarial-qa reads Requirements for context.
     Add/rename/remove a section → update those consumers. -->

```markdown
# Implementation Plan: [Feature Name]

## Approval Summary
**Goal:** [1–2 sentences — what the user gains]

**Slug:** [`<slug>` per rules above]

**Acceptance Criteria:**
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
