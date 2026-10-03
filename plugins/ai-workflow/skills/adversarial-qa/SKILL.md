---
name: adversarial-qa
description: >
  Exploratory QA of a running feature through its UI (Playwright) and/or API
  (curl) to find issues the plan and committed tests missed; returns findings
  with evidence, known issues, and blockers. Use when the user asks to QA,
  probe, or try to break a feature, after code review passes.
license: MIT
compatibility: >
  Needs a runnable dev server (AGENTS.md Commands) and, for UI surfaces, the
  plugin's bundled Playwright MCP server; API probing uses curl.
metadata:
  author: André Cunha
---

# /adversarial-qa

Exercise a feature in the running app and surface anything wrong, confusing,
or likely to bite a real user. Go beyond the committed tests; don't
re-verify the spec or review code.

## Input

- Plan text (optional): read Requirements only to understand what the feature
  does, not as a checklist
- Open deferred QA findings list (optional; empty list = "none open", which
  is a value, not an omission)

## Steps

### 1. Get open deferred QA findings

- List passed in → use it as-is
- Otherwise:
  - `AGENTS.md` → *Task Tracking* → *List open deferred QA findings* holds a
    real command/tool call → run it
  - section/bullet absent, `[TODO:]`, or `none` →
    `gh issue list --label known-issue --state open`
  - holds a real command you cannot run (e.g. an MCP tool you don't have) →
    never fall back to `gh` (wrong tracker). Report under *Blockers* "known
    issues not checked: <reason>", skip step 5, continue the rest

### 2. Determine the surface(s)

- From the plan's Requirements (or the diff, if no plan): **UI** (templates,
  views, a controller path rendering a view/fragment/client-driven response),
  **API** (REST or other network-callable endpoint, no view layer), or both
- Probe every surface the feature exposes; findings on one don't substitute
  for another

### 3. Set up and drive, per surface

Start the server with the project's dev-server command; app URL from
`AGENTS.md` → *Commands*. Stop it with the documented stop command when done
(never `kill` by PID, never hunt processes with `lsof`).

- **UI**: drive the feature in a browser via Playwright MCP
  - Server won't start or Playwright unavailable → STOP, report the blocker
  - Never substitute `curl`, SQL, or other workarounds for browser
    exploration on a UI surface
  - Mechanical setup with a fixed sequence (login, navigating to the
    feature) → batch it in one `browser_run_code_unsafe` call, not a
    click/type/snapshot round trip per step
  - Use granular tools (`browser_click`, `browser_snapshot`, …) only for the
    exploration in step 4
- **API**: `curl` via `Bash` against the same app URL
  - Server won't start, or a request needs credentials you don't have →
    STOP, report the blocker

### 4. Probe beyond the happy path

Try what the planner likely didn't enumerate.

- **UI**: narrow viewports · keyboard-only navigation · browser back ·
  multiple tabs on the same form · paste of weird/long/XSS content · reload
  mid-edit · error-toast timing · interaction with unrelated UI on the page
  · stale state after a failed submit
- **API**: malformed, missing, or extra fields · wrong `Content-Type` ·
  auth/authz boundaries (missing/expired token, wrong role or tenant) ·
  idempotency and duplicate submission · pagination and limit edge cases ·
  concurrent/racing requests · oversized payloads · unicode/injection strings
  · status-code and error-envelope correctness · rate limiting

Report anything that looks off, even outside this feature's plan. Never work
around issues, infer intent, or decide a bug is "probably expected"; the
developer decides.

### 5. Compare with known issues

(Skip if *Blockers* already reports them as unchecked.)

- Finding matches an open `known-issue` → *Known issues* section, cite its
  task id; not in *Findings*
- Observed behaviour worse than or different from the task's description →
  that difference IS a finding

## Evidence

Capture only once something is a confirmed finding, never while exploring.

- **UI**: `browser_take_screenshot` (costs more than `browser_snapshot`; use
  it only for a confirmed finding)
- **API**: the request and response showing the problem: method, URL,
  relevant headers, status code, body
- Save under `.qa-evidence/` at the repo root (gitignored)
- Every finding cites ≥1 evidence file there + a one-sentence description of
  what it shows

## Output

```
### Findings
- [Short description] — [evidence path] — [severity: bug / concern / nit]

### Known issues (already deferred — no action needed)
- [task id] [title] — [still present / not observed on this pass]

### Blockers (if any)
[Anything that prevented exploring — server won't start, Playwright
unavailable, credentials needed, etc.]
```

- Empty *Findings* is valid only if you genuinely probed and found nothing
  worth flagging; "ran out of ideas" is not
