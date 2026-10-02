---
name: plan-critic
description: >
  Critiques an implementation plan using pre-mortem, inversion, load-bearing
  assumption analysis, and consistency checks. Invoked as /plan-critic for
  ad-hoc plan critique, or used by the plan-critic sub-agent in the
  /feature workflow.
---

# /plan-critic

Find weaknesses in a draft plan before code is written. Attack the plan's
outcome, not its writing quality, formatting, or template completeness.
Standalone (`/plan-critic`) or applied by the `plan-critic` sub-agent in
`/feature`.

## Input

- Draft plan (markdown)
- Read-only repo access: `docs/adr/`, `docs/product-context/`, source code,
  module-level `AGENTS.md`

## Steps

### 1. Gather context

- ADRs in `docs/adr/` relevant to the affected areas
- Product docs in `docs/product-context/`
- Module `AGENTS.md` in directories the plan touches

### 2. Load lenses

Lenses direct extra attention while applying the methods (step 3). They are
not a separate checklist; no severity or structure required.

- Base lens (any project handling personal data): **personal-data leakage**
  — new data or rendering paths reaching public surfaces, logs, analytics,
  or URLs
- Project lenses, first match wins:
  1. Repo-root `AGENTS.md` (not module-level) → *Review & Planning Guidance*
     → "Planning guidance" entry → read the file it names
  2. No such section/entry → `docs/agent-rules/plan-critic.md`
  3. Entry names a missing file → treat as no file found, and say so
     specifically in Confidence
- Any doc found (lens-format file, style guide, handbook, product docs)
  applies the same way
- No file found → base lens alone

<!-- When the product grows consent and retention/deletion flows, add lenses
     here: consent lifecycle (not-given / withdrawn / re-consent) and right
     to erasure (cascade, TTL, or explicit reason to retain). -->

### 3. Apply ALL four methods

Each yields findings or an explicit "no concerns surfaced by this method,
because [reason]". Never skip silently.

1. **Pre-mortem**: assume it shipped 30 days ago and caused a production
   incident, support escalation, or regulatory complaint
   - Write 2–3 failure scenarios, 1–2 sentences each
   - Per scenario: does the plan address it, and how? Unaddressed → finding
2. **Inversion**: read the plan as a recipe for failure
   - List 2–3 things an adversarial implementer could do while technically
     following the plan that yield a broken or unsafe feature
3. **Load-bearing assumptions**: list the 3 most load-bearing (user
   behaviour, data shape, system state, regulation, third-party behaviour,
   scale)
   - Per assumption: what if wrong? Is the plan robust? If not, flag
4. **Consistency**: check ADRs and product docs/vision
   - Flag contradictions the plan does not acknowledge

## Output

Markdown, concerns first, in this format:

```
### Pre-mortem Scenarios
- [scenario]: [whether the plan handles it; if not, the specific gap]

### Inversion Findings
- [gap]: [how the plan permits the broken outcome; suggested constraint]

### Load-bearing Assumptions
- [assumption]: [what happens if wrong; whether the plan is robust]

### Consistency Issues
- [contradiction]: [the relevant ADR/doc and the conflict]

### Suggested Plan Amendments
[Concrete amendments, phrased as suggestions, not edits — the developer decides.]

### Confidence
[HIGH / MEDIUM / LOW, with one sentence of justification.]
```

## Constraints

- Never rewrite the plan or present a revised version; amendments go only in
  *Suggested Plan Amendments*
- Write no files
- Propose no implementation code
- Empty section → per-method justification (step 3)
