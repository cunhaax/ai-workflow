# AI-Assisted Development Workflow — Claude Code Plugin

Turns Claude Code into a small development team instead of one agent
guessing alone — with a git-level gate that keeps the humans in charge of
what actually ships.

## What you get

- **A team of specialists, not one generalist.** `planner`, `plan-critic`,
  `code-critic`, and `adversarial-qa` each run in their own context window,
  built from one shared source of knowledge (the *skills*) — so each pass
  stays focused instead of one agent doing everything at once.
- **`/feature` — one command, the whole lifecycle.** Plan → critique →
  implement → test → code-review → QA → PR. You don't orchestrate the
  steps yourself; the workflow does, end to end.
- **It stops and asks instead of guessing.** When a critic raises a
  `NEEDS_DECISION`, or QA turns up something the plan didn't anticipate, the
  loop halts and hands you the decision — fix now, defer with a filed
  issue, or ignore. Nothing gets silently resolved on your behalf.
- **A review gate enforced by git, not by an LLM's good behavior.** A
  pre-push hook blocks pushing any commit that doesn't match a recorded,
  passing review — deterministic and outside the model's control. See
  *Deterministic Enforcement* in [`docs/AI-workflow.md`](docs/AI-workflow.md).

## Getting started

1. **Install the plugin:**

   ```
   /plugin marketplace add cunhaax/ai-workflow-template
   /plugin install ai-workflow@ai-workflow
   ```

   Developing the plugin itself? Point the marketplace at your local
   checkout instead, so you're testing your working tree, not the published
   default branch:

   ```
   /plugin marketplace add /path/to/this/repo
   /plugin install ai-workflow@ai-workflow
   ```

2. **Scaffold and adapt it to your project:**

   ```
   /init-workflow
   ```

   Fills in `AGENTS.md` (build/test/run commands, sensitive areas), points
   review and planning guidance at your existing docs (or seeds new ones),
   and validates the setup. Every write is proposed and confirmed — re-run
   it any time as a doctor.

3. **Enable the review gate (once per clone):**

   ```sh
   git config core.hooksPath githooks
   ```

4. **Start a feature branch, then drive the work:**

   ```
   /feature
   ```

   Start on a fresh branch you create yourself — the agents won't create
   or switch branches, and the workflow diffs against and opens a PR
   against your default branch.

## Reviewing a small change yourself

Not every change needs the full `/feature` loop. For a small, manual
session, you can tell the implementing agent up front that **you'll do the
review yourself** — it will skip launching the `code-critic` sub-agent and,
once you've looked over the diff and approved it, just run:

```sh
scripts/review-ok.sh          # records HEAD's SHA as reviewed
```

The pre-push hook only checks that the pushed commit matches whatever was
last recorded — it doesn't care whether a sub-agent or a human did the
looking. That's the same gate either way, just with you standing in for
the critic.

## Want the full picture?

Design rationale, the skill/sub-agent reference, and how the workflow
executes step by step all live in
**[`docs/AI-workflow.md`](docs/AI-workflow.md)**.

## License

MIT — see [`LICENSE`](LICENSE).
