# AI-Assisted Development Workflow — Claude Code Plugin

A portable, tool-agnostic scaffold for running AI coding agents through a
structured lifecycle: **plan → critique → implement → test → code-review → QA →
PR**, with explicit gates between steps and deterministic enforcement below the
LLM layer.

It replicates a real development team as purpose-built sub-agents — planner,
plan-critic, code-critic, QA — each in its own context window, composed from
a single source of reusable knowledge (the *skills*). Implementation itself
stays with the main agent, which orchestrates the rest.

This README is the quick-start for *installing and adapting* the plugin.
Read **[`docs/AI-workflow.md`](docs/AI-workflow.md)** for the full design
rationale, the skill/sub-agent reference, and how the workflow actually
executes step by step.

## What's in here

```
.claude-plugin/marketplace.json     # Lists this repo's one plugin
plugins/ai-workflow/
├── .claude-plugin/plugin.json      # Plugin metadata
├── agents/                         # Sub-agent definitions (planner, plan-critic, code-critic, adversarial-qa)
└── skills/                         # The reusable knowledge — one directory per skill
    └── init-workflow/templates/    # Single source of truth for what a new project receives
docs/
├── agent-rules/                    # This repo's own real review rules + risk lenses
└── AI-workflow.md                  # The full guide to this system
githooks/pre-push, scripts/*.sh     # This repo's own review gate (symlinks into templates/)
AGENTS.md, CLAUDE.md, LICENSE
```

This repo has no project-local skills or sub-agents — `plugins/ai-workflow/`
is the plugin's real source. To use `/feature` etc. while working on this
repo, install the plugin the same way any consumer would (see below).

`init-workflow/templates/` is the single source of truth for what a new
project receives: `AGENTS.md.template`, `CLAUDE.md.template`,
`settings.json.template`, `docs/agent-rules/*`, `docs/adr/*`,
`docs/product-context/*`, and the three enforcement scripts
(`githooks/pre-push`, `scripts/review-ok.sh`, `scripts/check-hook-status.sh`).
This repo's own root `AGENTS.md`/`CLAUDE.md`/`docs/agent-rules/*` are real,
hand-written files, not copies of the template; `.claude/settings.json` and
the three enforcement scripts are symlinks into `templates/` instead — see
this repo's own `AGENTS.md` (*Architecture* section) for why, which is
specific to this repo's own root layout rather than the general plugin
design `docs/AI-workflow.md` covers.

## Installing into a project

*This hasn't been exercised end-to-end yet — the manifests exist and
validate, but the actual `/plugin marketplace add`/`/plugin install` flow
requires an interactive scope-selection step only a human can drive.
First real install is the test.*

```
/plugin marketplace add cunhaax/ai-workflow-template
/plugin install ai-workflow@ai-workflow
```

Choose the `project` scope if you want the install recorded and shared via
your project's own git history. Then, inside the project, run
**`/init-workflow`** — it scaffolds whichever project-owned files are
missing, adapts them to your codebase, and validates the whole setup. Every
write is proposed and confirmed before anything happens; whatever you defer
stays an explicit TODO. See *Repository Structure* in `docs/AI-workflow.md`
for exactly what gets scaffolded and how it decides.

**Developing the plugin itself?** The GitHub form above sources from the
published repo's default branch, not your working tree. Point the
marketplace at a local checkout instead:

```
/plugin marketplace add /path/to/this/repo
/plugin install ai-workflow@ai-workflow
```

**Updating later**: update the plugin (`/plugin marketplace update` /
`/plugin update`), then re-run `/init-workflow` — in doctor mode it reports
anything the update newly expects.

## Adapting it to your project — where your content goes

You never edit the skills. All project-specific content lives in files you own:

- **`AGENTS.md`** — overview, architecture, testing conventions, the
  *Sensitive Areas* list, and *Commands* — the single home of every
  `[PLACEHOLDER]`:

  | Placeholder            | Replace with                                              |
  |------------------------|----------------------------------------------------------|
  | `[PROJECT_NAME]`       | Your project's name                                       |
  | `[BUILD_CMD]`          | Build command (e.g. `make build`, `npm run build`)        |
  | `[TEST_CMD]`           | Run-all-tests command                                     |
  | `[CHECK_CMD]`          | All-checks-incl-tests command                             |
  | `[RUN_CMD]`            | Start the dev server                                      |
  | `[STOP_CMD]`           | Stop the dev server                                       |
  | `[SINGLE_TEST_EXAMPLE]`| How to run one test                                       |
  | `[APP_URL]`            | Local app URL for QA (e.g. `http://localhost:3000`)       |
  | `[DEFAULT_BRANCH]`     | `main` / `master` — the branch reviews diff against       |

- **`AGENTS.md`'s *Review & Planning Guidance* section** — names your code
  review and planning guidance files by role. `/init-workflow` asks up front
  whether you already have docs for this (a style guide, `CONTRIBUTING.md`)
  and points here instead of creating new ones, so you don't duplicate
  content you already maintain.
- **`docs/agent-rules/code-critic.md`** (the default target) — your repo's
  hard review constraints, including the privacy anchors that bind the base
  privacy rules to your codebase. Grows over time as agents produce bad
  output the base rules didn't catch.
- **`docs/agent-rules/plan-critic.md`** (the default target) — the areas
  where generic plans regularly miss issues that matter for *your* product.
- **`docs/product-context/`** and **`docs/adr/`** — your vision/strategy docs
  and architecture decisions.

## Enabling the review gate

Once per clone:

```sh
git config core.hooksPath githooks
```

After the `code-critic` passes with no FAIL items, record it:

```sh
scripts/review-ok.sh          # writes HEAD's SHA to .review-passed
```

`githooks/pre-push` then refuses to push any commit that doesn't match the
recorded review. Human bypass: `git push --no-verify`. This enforces
*freshness* (the pushed commit is exactly the reviewed one), not the
review's *verdict* — see *Deterministic Enforcement* in
`docs/AI-workflow.md` for the full trust model and what mitigates that gap.

## Day-to-day use

Start each feature session on a **fresh feature branch created by you** — the
agents may not create or switch branches (Rule 3 in `AGENTS.md`), and the
workflow diffs against the default branch and opens a PR targeting it, neither
of which works from the default branch itself. Then drive the work with
`/feature`.

## Evolving the system

See *Evolving the System* in `docs/AI-workflow.md`. Short version: start
small (planner + code-critic first); every time an agent's bad output slips
past the rules, add a rule to whatever `AGENTS.md`'s *Review & Planning
Guidance* points to for code review — or better, a build-enforced fitness
test; keep `AGENTS.md` lean.

## License

MIT — see [`LICENSE`](LICENSE).
