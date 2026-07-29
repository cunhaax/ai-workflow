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

1. Start the local dev server with the project's dev-server command and
   drive the feature at the documented app URL (both in `AGENTS.md` →
   *Commands*) in a browser via the Playwright MCP. When you are done, stop
   it with the documented stop command —
   never `kill` by PID or hunt processes with `lsof`. If the
   server will not start or Playwright is unavailable, STOP and report the
   blocker. Do not substitute curl, SQL, or any other workaround for browser
   exploration — those answer different questions.

   For mechanical setup with a known, fixed sequence — logging in,
   navigating through boilerplate screens to reach the feature under test —
   batch the steps into one `browser_run_code_unsafe` call instead of a
   click/type/snapshot round trip per step; each round trip returns a full
   accessibility snapshot, which adds up fast. Reserve the granular tools
   (`browser_click`, `browser_snapshot`, etc.) for the actual exploration in
   step 2, where you need to see state after each action to decide the next
   one.

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

Only take a screenshot once you've decided something is a finding worth
reporting — never while just looking around. `browser_take_screenshot`
returns an image, which costs meaningfully more than the text snapshots from
`browser_snapshot`, so screenshotting every step of the exploration adds up
quickly for no benefit. Save each finding's screenshot under `.qa-evidence/`
at the repo root (gitignored); every finding in the report MUST cite at least
one screenshot there, with a one-sentence description of what it shows.

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
