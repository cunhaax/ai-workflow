---
name: adversarial-qa
description: >
  Exploratory, adversarial QA: drive the running feature in a browser and
  surface UX issues and edge cases the plan and committed tests did not
  anticipate — not a re-verification of the spec. Invoked as /adversarial-qa
  for an ad-hoc session, or applied by the adversarial-qa sub-agent in the
  /feature workflow.
---

# /adversarial-qa — Exploratory QA

Exercise a feature in the running app and surface anything that looks wrong,
confusing, or likely to bite a real user. This is exploratory and adversarial,
not a re-verification of the spec — committed end-to-end tests encode the plan's
Requirements deterministically. Your job is to go beyond them.

If a plan was provided (inline or by path), read the Requirements section only
to understand what the feature does — not as a checklist to tick through.

---

## What to do

1. Start the local dev server with `[RUN_CMD]` ([APP_URL]) and drive the
   feature in a browser via the Playwright MCP. When you are done, stop it with
   `[STOP_CMD]` — never `kill` by PID or hunt processes with `lsof`. If the
   server will not start or Playwright is unavailable, STOP and report the
   blocker. Do not substitute curl, SQL, or any other workaround for browser
   exploration — those answer different questions.

2. Probe beyond the happy path. Try things the planner likely did not
   enumerate: narrow viewports, keyboard-only navigation, browser back button,
   multiple tabs on the same form, paste of weird/long/XSS content, reloading
   mid-edit, error-toast timing, interactions with unrelated UI on the same
   page, stale state after a failed submit.

3. Surface anything that looks off — even if it is not part of this feature's
   plan. Do not act "smart" by working around issues, inferring intent, or
   deciding a bug is "probably expected". Report it and let the developer
   decide.

4. Before writing the report, list the known deferred issues with
   `gh issue list --label known-issue --state open` and compare them against
   what you found. A finding that matches an open `known-issue` goes in the
   *Known issues* section of the report (cite the issue number), NOT in
   Findings — the developer has already triaged it once and should not have
   to re-triage it on every QA pass. If the observed behaviour is worse than
   or different from what the issue describes, that difference IS a finding.

---

## Evidence

Save screenshots under `.qa-evidence/` at the repo root (gitignored). Every
finding in the report MUST cite at least one screenshot there, with a
one-sentence description of what it shows.

---

## Output Format

```
### Findings
- [Short description] — [evidence path] — [severity: bug / concern / nit]

### Known issues (already deferred — no action needed)
- [#issue-number] [title] — [still present / not observed on this pass]

### Blockers (if any)
[Anything that prevented you from exploring — server won't start, Playwright
unavailable, credentials needed, etc.]
```

An empty `Findings` section is a valid output if you genuinely probed the
feature and found nothing worth flagging. An empty output because you "ran out
of ideas" is not.
