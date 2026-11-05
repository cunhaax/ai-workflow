---
name: code-critic
description: >
  Reviews code changes against project standards and the approved
  plan; returns PASS/FAIL/NEEDS_DECISION per checklist item plus open
  questions. Use when the user asks for a code review of a branch or change,
  or after implementation and before opening a PR.
license: MIT
metadata:
  author: André Cunha
---

# /code-critic

Review code changes against project standards.

Stance: the implementation is a hypothesis under attack. Assume something is
wrong and try to disconfirm it; don't verify that it "looks reasonable". No
fault found after genuine effort → state that explicitly (*Disconfirmation
Attempt*). Apply the same stance to the tests (see *Tests*).

## Input

- Plan text (optional; inline or file path)
- Test evidence: summary of the latest full test run (optional)
- The diff is not an input: step 1 selects it

## Steps

### 1. Select the diff

- Work committed: `git diff <default-branch>...HEAD` or
  `git log -p <default-branch>..HEAD`; default branch from `AGENTS.md` →
  *Commands*
- Work uncommitted: working-tree diff
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
- No automated test suite (`AGENTS.md` → *Commands* says so): in the two
  checks above, each ID instead needs a tagged walkthrough in the plan's Test
  Strategy and a recorded passing result for it in the test evidence. Missing
  or failed → `FAIL`; not run → `FAIL` unless the evidence records the user
  waived it
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

- Judge test coverage by reading the code and tests; never run the suite
- Test run summary provided → treat it as the implementer's record that the
  suite ran and passed, not as independent proof
- No summary provided → raise Open Question: "no evidence the test suite ran
  on the reviewed state"; never assume green

### 5. Apply standards

Apply general review practice; the rules below set the verdicts.

**Design**
- New code that mixes concerns (a function doing two jobs, a class with more
  than one independent reason to change, an unrelated branch added to an
  existing function) → `FAIL`; borderline, or extracting would hurt
  readability → `NEEDS_DECISION`
- Extending existing oversized code without making it meaningfully worse →
  `NEEDS_DECISION` (flag the debt; the developer chooses refactor, tech debt
  or accept); making it significantly worse → `FAIL`
- No generic catch-all in business logic; at a process boundary (top-level
  controller, scheduled job, async entry point) one that logs and translates
  to a domain error is fine. Errors say what failed and why

**Tests** (you own quality AND completeness)
- No automated test suite (`AGENTS.md` → *Commands* says so): read "test"
  below as the plan's walkthroughs plus any extra ones recorded in the test
  evidence; only a passing or waived one covers anything. No plan → a
  coverage gap is an Open Question ("no walkthrough evidence"), not a `FAIL`
- A plan Requirement or Edge Case, or a branch the diff introduces (error
  path, validation failure, authorization denial, empty/null), with no test
  that would fail if it broke → `FAIL`
- Gaps beyond the plan: for each branch in the diff, build an input or event
  sequence that exercises it (boundaries, input shapes, state and
  concurrency, dependency failure, authz on every entry point,
  injection-shaped input reaching a query, template or shell) and ask
  whether a test covers it. Gap → `FAIL` naming the missing test; ambiguous
  scope → `NEEDS_DECISION`
- An assertion that passes regardless of correctness (check what it
  compares, not its name) → `FAIL`
- A plan-derived test weakened, loosened or deleted to pass → `FAIL`, unless
  the input documents an approved plan deviation

**Privacy** (bound to the codebase by step 6's privacy anchors)
- The three privacy fitness tests a project holding personal data should
  have: deletion by design (every user-FK table cascades on account deletion
  or is in a commented allowlist), a public-surface whitelist (public views
  render a distinct type whose fields are asserted), and no personal data in
  logs
- One exists → only check the diff doesn't weaken it (below); one doesn't →
  check its invariant by hand on diffs that touch it
- Personal data in logs, including indirect serialization (a rich object's
  `toString()`, dumped request params), or in URLs → `FAIL`

**Fitness tests** (architecture or privacy): one exists → don't re-derive
what it checks by hand. Weakening it (deleting or disabling it, widening its
scope or glob, an unexplained exemption or allowlist entry, code moved out of
what it scans) → `FAIL`

### 6. Project rules

- Repo-root `AGENTS.md` (not module-level) → *Review & Planning Guidance* →
  "Code review guidance" entry → read the file it names
- No such section/entry → `docs/agent-rules/code-critic.md`
- Entry names a missing file → treat as no file found, and say so
  specifically (broken pointer)
- File found:
  - Apply every constraint alongside the base standards (step 5)
  - Stated severity → use as stated (incl. don't-weaken doctrine for
    build-enforced items)
  - No stated severity (style guide, `CONTRIBUTING.md`, handbook) → judge
    with `PASS`/`FAIL`/`NEEDS_DECISION`
  - PRIVACY anchors in it bind the privacy rules in step 5 regardless of
    format
- No file found → base standards only; say so in one line in the output

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

Items, one verdict each:
- **Architecture**: service boundaries and ADRs respected (step 2) · no
  business logic in infrastructure/API layers · no new dependency without
  justification
- **Plan compliance** (if plan): one verdict per step 3 check
- **Design**: step 5 *Design*
- **Tests**: step 5 *Tests*; list the scenarios you built and which lacked a
  test
- **Privacy and fitness tests**: step 5 *Privacy* and *Fitness tests*
- **Project-specific**: every applicable item from step 6 evaluated, or its
  absence stated in one line
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
