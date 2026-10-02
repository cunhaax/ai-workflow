---
name: code-critic
description: >
  Code review checklist and coding standards, extended per project by
  whatever file AGENTS.md's Review & Planning Guidance section names
  (defaulting to docs/agent-rules/code-critic.md). Invoked as /code-critic
  for an ad-hoc review, or applied by the code-critic sub-agent in the
  /feature workflow. (Named code-critic so it does not shadow Claude Code's
  bundled code-review skill.)
---

# /code-critic

Review code changes against project standards. Standalone (`/code-critic`) or
applied by the `code-critic` sub-agent in `/feature`.

Stance: the implementation is a hypothesis under attack. Assume something is
wrong and try to disconfirm it; don't verify that it "looks reasonable". No
fault found after genuine effort → state that explicitly (*Disconfirmation
Attempt*). Apply the same stance to the tests (see *Tests*).

## Input

- Diff to review (step 1)
- Plan text (optional; inline or file path)
- Test evidence: summary of the latest full test run (optional)

## Steps

### 1. Select the diff

- `/feature` flow (work is committed): `git diff <default-branch>...HEAD` or
  `git log -p <default-branch>..HEAD`; default branch from `AGENTS.md` →
  *Commands*
- Ad-hoc on uncommitted work: working-tree diff
- Unsure → `git status`, `git log --oneline`
- You may read any file in the repo; the diff is the unit under review

### 2. ADRs

- `docs/adr/` exists → list the ADRs read by number in the output; none
  relevant → say so explicitly (silence reads as skipped)
- Diff contradicts an ADR → `FAIL`; quote the ADR clause and the diff line

### 3. Plan compliance (skip entirely if no plan)

Per plan section:
- **Approval Summary / Acceptance Criteria**: every `AC-<slug>-n` has a
  committed test tagged `[AC-<slug>-n]` that would fail if the criterion
  broke. Missing → `FAIL`
- **Edge Cases**: same for every `EDGE-<slug>-n` / `[EDGE-<slug>-n]`.
  Missing → `FAIL`
- **Contract** (skip if "None"): diff's routes, fields/params, response
  shapes, error rendering, schema match. Undiscussed deviation → `FAIL`
- **Types anywhere in the plan** (Contract, Approach, Requirements, even
  when Contract is "None"): nullable/non-null and optional/required are part
  of the contract
  - Diff every parameter/field type the plan states against the actual
    signature; don't infer from the tests' inputs
  - Mismatch either way → `FAIL`, even if tests pass, unless the review input
    documents an approved deviation
- **Requirements**: all addressed (source of truth for what to build)
- **Approach**: code follows it; no undiscussed alternative design; all plan
  steps accounted for
- **Files**: diff matches the manifest. File in diff but not listed (or
  listed but untouched) → undiscussed change; flag, judge scope
- **Out of Scope**: don't flag listed items as missing; flag code straying
  into it as scope creep
- **Test Strategy**: cross-reference against actual tests
- Quote the exact plan line and the exact violating diff line; never
  paraphrase the plan

### 4. Test evidence

- Coverage is verified statically; the suite run is separate evidence
- Provided summary = record from the implementer, not independent proof
- None provided and you can't/may not run the suite → Open Question: "no
  evidence the test suite ran on the reviewed state". Never assume green

### 5. Project rules

- Repo-root `AGENTS.md` (not module-level) → *Review & Planning Guidance* →
  "Code review guidance" entry → read the file it names
- No such section/entry → `docs/agent-rules/code-critic.md`
- Entry names a missing file → treat as no file found, and say so
  specifically (broken pointer)
- File found:
  - Apply every constraint alongside the base standards
  - Stated severity → use as stated (incl. don't-weaken doctrine for
    build-enforced items)
  - No stated severity (style guide, `CONTRIBUTING.md`, handbook) → judge
    with `PASS`/`FAIL`/`NEEDS_DECISION`
  - PRIVACY anchors in it bind the privacy rules below regardless of format
- No file found → base standards only; say so in one line in the output

### 6. Apply standards

**Single responsibility**
- Functions do one thing. Branch for a different concern (admin path in a
  user path, parsing inside persistence):
  - New function with mixed concerns → `FAIL`
  - Existing function extended with an unrelated branch → `FAIL`
  - Borderline, extraction hurts readability → `NEEDS_DECISION`
- Classes: too many responsibilities = more than one independent reason to
  change
  - New class with too many → `FAIL`
  - Change significantly worsens an existing violation → `FAIL`
  - Change extends an oversized class without making it meaningfully worse →
    `NEEDS_DECISION` (flag the debt; developer chooses refactor / tech debt /
    accept)

**Error handling**
- No generic catch-all in business logic. At process boundaries (top-level
  controllers, scheduled jobs, async entry points) a catch-all that logs and
  translates to a domain error is fine; judge by where it lives
- Every error carries context: what operation failed and why
- Critical-path errors logged with structured fields

**Naming**
- Functions say what they do (`calculateShippingCost`, not `calc`/`process`)
- Booleans read as questions (`isValid`, `hasPermission`)

**Tests** (you own quality AND completeness; `/adversarial-qa` doesn't check
plan coverage)
- Quality:
  - Every public function with non-trivial behaviour has happy-path and edge
    tests. Exempt: trivial delegators, generated code, plain data classes,
    pure getters. State each exemption and why
  - Names describe the scenario (`test_order_fails_when_inventory_insufficient`)
  - Given-When-Then; test behaviour, not implementation details
  - Check what each assertion actually compares, not its name/comment. A test
    that passes regardless of correctness (expression compared to itself)
    proves nothing
  - Diff weakens, loosens, or deletes a plan-derived test (esp. `[AC-…]`) to
    pass the suite → `FAIL`, unless the input documents an approved plan
    deviation
- Completeness, against the plan: every Requirement and Edge Case has a test
  that would fail if it broke; every branch the implementation introduces
  (error paths, validation failures, authorization denials, empty/null) is
  exercised
- Completeness, beyond the plan: statically, per branch in the diff, build an
  input or event sequence that exercises it and ask whether a test covers it.
  For each category ask "what would I do to make this fail?":
  - Implicit branches (`if`, `when`/`switch`, `?:`, early returns, exception
    handlers) not in the plan
  - Boundary values: 0, 1, max, min, off-by-one, empty, single-element,
    at-limit vs just-over
  - Input shapes: null, blank, whitespace, unicode, very long, leading/trailing
    spaces, mixed case, duplicates, unsorted
  - State/concurrency: stale reads, double submit, retries, partial writes,
    invoked twice
  - External dependency failure: timeouts, 4xx vs 5xx, malformed payloads,
    slow responses
  - Security-adjacent: authz on every entry point (not just the planned one);
    injection-shaped input on any field reaching a query, template, or shell
  - Gap found → `FAIL` (or `NEEDS_DECISION` if scope is ambiguous) with a
    concrete description of the missing test

**Privacy and data protection**
- Prefer build-enforced tests. Any project holding personal data should have
  three fitness tests (backlog items until they exist, not per-PR prose):
  1. Deletion by design: every table with a user FK cascades on account
     deletion or is in an explicit, commented allowlist
  2. Public-surface whitelist: the model rendered on public/unauthenticated
     surfaces is a distinct type with fields asserted against a whitelist
     (public pages rendering from the full domain object → restructuring is
     the prerequisite, its own task)
  3. No personal data in logs: log statements don't reference
     sensitive/user-content or contact-detail fields
- Implemented ones: only check the diff doesn't WEAKEN them (deleting or
  disabling the test, unexplained allowlist entry, code restructured out of
  scan scope) → weakening is `FAIL`
- Not implemented: check the invariant by hand only on diffs touching it
  (new user-FK tables; public-view rendering; new/changed log statements)
- Manual residue, `FAIL`:
  - Indirect serialization into logs (rich-object `toString()`, dumped
    request params)
  - Personal data in URLs (emails, phones, or values embedding them in query
    params or path segments)
- Consent, retention, data-classification: NOT per-PR items (product flows,
  built as tasks then protected by tests)

**Architecture**
- A layer/architecture fitness test exists → don't re-derive boundaries by
  hand; only check the diff doesn't weaken it (deleting/disabling it,
  widening a package glob, unexplained exemption, code moved out of the
  scanned layer) → `FAIL`

### 7. Review Checklist

Evaluate every item; state a verdict for each.

Verdicts:
- `PASS`: applies and complies. Non-trivial items (test coverage, edge cases,
  error paths, security-adjacent code): cite diff lines. Routine items:
  brief note
- `PASS (N/A)`: doesn't apply; say why
- `FAIL`: rule violated, with a citable line and rule. Only when confident;
  unsure → `NEEDS_DECISION` or Open Question (false `FAIL`s burn trust faster
  than misses)
- `NEEDS_DECISION`: ambiguous, needs developer input; state the options
- Open Question: diff might be wrong but unverifiable from source (runtime
  config, prod data shape, deployment topology, external behaviour); state
  the question and the evidence that would resolve it. Use freely

Items:
- **Architecture**: respects service boundaries and ADRs · no business logic
  in infrastructure/API layers · no new dependency without justification
- **Plan compliance** (if plan): everything in step 3
- **Code quality**: single responsibility (functions, classes) · specific
  error handling · readable by a new team member · no implicit assumptions
  that should be explicit comments/types
- **Edge cases**: plan's `EDGE-<slug>-n` explicitly handled (if plan) ·
  null/empty/zero/negative · concurrent access · external dependency failure
  (timeouts, retries, fallbacks), each where applicable
- **Tests**: happy path · every plan Requirement and Edge Case (if plan) ·
  every introduced branch · boundaries · input shapes · state/concurrency ·
  dependency failure modes (each where applicable) · critical analysis done,
  unenumerated scenarios listed, missing ones `FAIL` · scenario-describing
  names · Given-When-Then · no implementation-detail tests · no tautological
  assertions
- **Project-specific**: every applicable item from step 5 evaluated, or its
  absence stated in one line
- **Privacy**: fitness tests not weakened · hand-checked invariants where the
  diff touches them · no indirect serialization into logs, no personal data
  in URLs
- **Security**: no secrets/credentials in code · input validation on all
  external inputs · authorization where required

## Output

```
### Review Summary
[1-2 sentence overall assessment]

### PASS
- [item]: [explanation; non-trivial items cite diff lines like src/foo/Bar.ext:42-58]

### PASS (N/A)
- [item]: [why it doesn't apply]

### FAIL
- [item]: [what's wrong, suggested fix, diff line reference]

### NEEDS_DECISION
- [item]: [the ambiguity and the options]

### Open Questions
- [hypothesis]: [the question, and the evidence that would resolve it]

### ADRs Reviewed
[ADR numbers read, or "none relevant" + one sentence why.]

### Disconfirmation Attempt
[REQUIRED if FAIL and NEEDS_DECISION are both empty]
What you specifically tried: inputs considered, failure modes probed, edge
cases inspected, diff sections examined, methods applied (pre-mortem,
boundary probe, dependency-failure probe, adversarial input probe) and
their outcomes. "Looks good" / "no issues found" is not acceptable.
```

- Label `NEEDS_DECISION` items and Open Questions clearly for the
  orchestrating agent; never decide them yourself
- Modify no code. Output only the review
