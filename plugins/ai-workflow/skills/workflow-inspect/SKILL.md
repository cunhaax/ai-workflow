---
name: workflow-inspect
description: >
  Appends the cost half to a workflow-retro record: parses the feature
  session's Claude Code transcripts with a bundled read-only script
  (tokens per agent, wall-clock, handoff tax) and writes the result into
  the record's Cost section. Companion of /workflow-retro; run it while
  the transcripts still exist (they are pruned after Claude Code's
  retention window, ~30 days by default). Requires python3.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/inspect.py *)
---

# /workflow-inspect

Fill a `/workflow-retro` record's pending `## Cost` section with numbers
computed from the raw session transcripts: tokens and wall-clock per
sub-agent, sub-agents' share of the total, and the handoff tax (files the
planner read that the main agent re-read). Run after `/workflow-retro`, within
the transcript retention window.

## Input

- `.workflow-log/` records whose `## Cost` is `pending`
- `python3`; `inspect.py` in this skill's directory (read-only: parses
  transcripts, prints markdown to stdout)

## Ground rules

- **Numbers come from the script, verbatim.** Never estimate, adjust, or add
  a figure the script didn't print. Script fails or its output carries
  warnings → surface them to the user as-is (`AGENTS.md` Rule 2 applies)
- **The only mutation is the log file**: replacing the `## Cost` section of
  the chosen record(s), after the user confirms. Never commit anything;
  `.workflow-log/` stays local

## Steps

### Step 1 — Pick the record(s)

- Log directory, as in `/workflow-retro`: `.workflow-log/` under the main
  worktree (parent of `git rev-parse --path-format=absolute --git-common-dir`)
- List records whose `## Cost` is still `pending`
  - One → proceed with it
  - Several → ask which (offer "all"; each is one script run)
  - None → report that every record is already inspected, and stop

### Step 2 — Gather the session IDs

- Read the record's `Sessions:` line
- `unknown`, or Step 3 finds no transcript for any listed ID → cost is
  unrecoverable once transcripts are pruned. With the user's confirmation,
  close the section with `unavailable — transcripts pruned or session IDs
  unknown` instead of leaving `pending` forever

### Step 3 — Run the inspector

One command, from the repository root:

```sh
python3 ${CLAUDE_SKILL_DIR}/inspect.py <session-id> [<session-id> …]
```

The script:
- Locates each session's transcript by **global search** of
  `~/.claude/projects/` (transcripts are filed under the session's *launch*
  directory, not necessarily the worktree; never derive the directory from a
  path)
- Resolves every sub-agent transcript via its spawn `toolUseId`
- Deduplicates records shared by resumed sessions
- Prints a complete `## Cost` section
- Fails soft: what it can't parse or find becomes a warning line in the
  output, and the numbers are then lower bounds

### Step 4 — Reconcile

Before writing, act on the output:
- Warning that sub-agent transcripts belong to **sessions not listed in the
  record** → the feature spanned more sessions than the retro knew. Offer to
  add those IDs to the record's `Sessions:` line and re-run the script once
  with the full list
- Cost data contradicts the record's outcome half (e.g. more sub-agent runs
  than the Steps table's review rounds) → point out the discrepancy to the
  user. The outcome sections are theirs to amend; never edit them yourself

### Step 5 — Confirm and write

- Show the user the script's output
- Confirmed → replace the record's entire `## Cost` section (heading
  included) with it, leave every other section untouched, report the file
  path
- Declined → leave the record as it was

## Output

- The record's `## Cost` section replaced (or closed as `unavailable`)
