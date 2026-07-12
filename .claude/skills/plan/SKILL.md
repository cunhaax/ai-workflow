---
name: plan
description: >
  Planning rules and plan template for drafting implementation plans.
  Invoked as /plan for an ad-hoc planning session, or used by the planner
  sub-agent in the /feature workflow.
---

# /plan — Implementation Planning

Use this skill to produce a structured implementation plan before writing any code.
Can be invoked standalone (`/plan`) or applied by the `planner` sub-agent during the
`/feature` workflow.

---

## Context Gathering

Before planning, collect all relevant context:

- **External specs**: If the prompt references an external link or doc, fetch
  it before planning — the Requirements section must quote the source verbatim.
- **Codebase**: Read any module-specific `AGENTS.md` files in directories likely to
  be affected, ADRs in `docs/adr/`, and relevant product docs in `docs/`.

---

## Planning Rules

- **Lead with intent.** The **Context & Decisions** section states, in a few
  sentences, what problem this solves and the shape of the solution — then lists
  every decision taken during planning and every alternative considered and
  rejected, each with its reason. The plan is self-contained: a reader with no
  access to the planning conversation must understand what to build and why.
  Nothing load-bearing may live only in the chat.
- The **Requirements** section MUST capture the complete feature requirements
  exactly as specified by the user or the linked spec. Do not summarize or omit
  details — the `code-reviewer` cross-checks every requirement and edge case in
  this section against the committed tests. If they come from a document, quote
  them; if from the user's prompt, reproduce them in full.
- The **Files** section MUST list every file the change touches, each tagged
  `NEW` / `EDIT` / `DELETE` / `MOVE`, with a phrase on what changes and why. It
  is the implementer's checklist and the reviewer's blast-radius map — a file in
  the diff but not here is an undiscussed change.
- The **Out of Scope** section MUST state the boundary explicitly: what a reader
  might reasonably expect this change to include but it deliberately does not.
  This is where scope disagreements surface cheaply and what stops the
  implementer gold-plating. Write "None" only if you mean it.
- List ALL edge cases explicitly in **Edge Cases** — do not assume any can be
  skipped.
- Flag any potential single-responsibility concerns in the proposed approach.
- Propose a test strategy that covers the happy path AND every identified edge
  case. Tests are the plan's deterministic oracle — every claim the plan makes
  about user-visible behaviour (error placement, section open/closed state,
  button enable/disable, post-failure page coherence, persistence-vs-UI
  consistency) MUST map to a committed end-to-end test that exercises the
  behaviour and observes the rendered result (per project convention; e.g.,
  Playwright for a web UI). If a UI claim is worth writing down in the plan, it
  is worth committing as a test.
- Do NOT write a manual "Verification" or "QA checklist" of behavioural steps.
  If you catch yourself writing "Try X and confirm Y", convert it into a
  committed test assertion in the Test Strategy. The one exception is
  **environmental preconditions** that are not themselves behaviour under test
  (e.g. "a migration was edited in place, so the local DB must be reset first") —
  record those under **Environment & Preconditions**, not as verification.
- Prefer concrete, quotable statements over prose blobs: name the files, show
  the key data class or signature, number the edge cases. The plan is reviewed
  line by line — a reviewer can only annotate what is stated specifically. Where
  an existing pattern should be followed, point at it by name (e.g. "mirror
  `ExistingValidator`") so the implementer copies the canonical shape.
- If any part of the spec is ambiguous, flag it as `NEEDS_DECISION` with options.
  Do NOT ask the user directly from within a sub-agent — surface ambiguities in
  the plan so the main agent can relay them.
- Respect existing ADRs. If your plan contradicts a past decision, flag it
  explicitly and explain why the decision should be reconsidered.
- Sections that genuinely do not apply may be marked "None" (Out of Scope,
  Environment & Preconditions, NEEDS_DECISION) — but do not drop them; "None"
  tells the reader you considered them.

---

## Plan Template

```markdown
# Implementation Plan: [Feature Name]

## Source
[User prompt summary / external doc title + URL]

## Context & Decisions
[Why this change exists and the shape of the solution, in a few sentences. Then:
decisions taken during planning, and alternatives considered and rejected — each
with its reason.]

## Requirements
[Complete feature requirements — quoted from the source or reproduced verbatim
from the prompt. Do not summarize.]

## Approach
[Step-by-step implementation strategy. Point at existing patterns to follow by
name where one applies.]

## Files
- NEW    [path]: [what it holds / why]
- EDIT   [path]: [what changes / why]
- DELETE [path]: [why]
- MOVE   [old] → [new]: [why]

## Out of Scope
- [What a reader might expect but this change deliberately excludes]

## Edge Cases
1. [Edge case]: [handling strategy]

## Test Strategy
- [Test]: [what it verifies]

## Environment & Preconditions
[Non-behavioural setup the implementer needs — e.g. "migration edited in place,
reset the local DB first". Behavioural claims belong in Test Strategy. "None" if
nothing applies.]

## NEEDS_DECISION
- [Ambiguity]: [options available]

## Risks
- [Anything that could go wrong or needs extra attention]
```

---

## Output

Return the plan as markdown text. Do NOT write any files — the main agent will submit the
plan for review.

Do NOT write implementation code. Output only the plan.
