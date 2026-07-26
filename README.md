# AI-Assisted Development Workflow — Claude Code Plugin

A portable, tool-agnostic scaffold for running AI coding agents through a
structured lifecycle: **plan → critique → implement → test → code-review → QA →
PR**, with explicit gates between steps and deterministic enforcement below the
LLM layer.

It replicates a real development team as purpose-built sub-agents — planner,
plan-critic, code-critic, QA — each in its own context window, composed from
a single source of reusable knowledge (the *skills*). Implementation itself
stays with the main agent, which orchestrates the rest.

Read **`docs/AI-workflow.md`** for the full design rationale. This README is the
quick-start for *installing and adapting* the plugin in a new project.

## What's in here

```
.claude/
├── settings.json                # This repo's own permission rules (see below)
├── agents/                      # Sub-agent definitions (frontmatter + inline prompt)
│   ├── planner.md                # Orchestration + skills: [plan-draft]
│   ├── plan-critic.md            # Orchestration + skills: [plan-critic]
│   ├── code-critic.md            # Orchestration + skills: [code-critic]
│   └── adversarial-qa.md         # Orchestration + skills: [adversarial-qa]  (+ Playwright)
└── skills/                      # The reusable knowledge, one directory per skill
    ├── feature/SKILL.md          # The full workflow (plan→critique→…→PR)
    ├── init-workflow/
    │   ├── SKILL.md               # Bootstrap + doctor: scaffolds a new project,
    │   │                          #   fills AGENTS.md, seeds agent-rules, validates the gate
    │   └── templates/             # THE scaffold source — see below
    ├── plan-draft/SKILL.md       # (named plan-draft to avoid Claude Code's built-in /plan)
    ├── plan-critic/SKILL.md
    ├── code-critic/SKILL.md      # Base review standards (named code-critic to avoid
    │                             #   shadowing Claude Code's bundled code-review skill)
    ├── adversarial-qa/SKILL.md
    ├── workflow-retro/SKILL.md   # Optional end-of-session workflow-evaluation
    │                             #   record (writes to gitignored .workflow-log/)
    └── workflow-inspect/         # Companion: fills the record's Cost section from
                                  #   session transcripts (SKILL.md + inspect.py)
docs/
├── agent-rules/                 # This repo's own real review rules + risk lenses
└── AI-workflow.md               # The full guide to this system
githooks/pre-push                # Symlink → .claude/skills/init-workflow/templates/githooks/pre-push
scripts/review-ok.sh             # Symlink → .claude/skills/init-workflow/templates/scripts/review-ok.sh
AGENTS.md, CLAUDE.md             # This repo's own real project guide (not a template — see below)
```

**`init-workflow/templates/` is the single source of truth for what a new
project receives**: `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`, a CI
skeleton, `docs/agent-rules/*`, `docs/adr/*`, `docs/product-context/*`, and
the two enforcement files (`githooks/pre-push`, `scripts/review-ok.sh`). This
repo's own root `AGENTS.md`/`CLAUDE.md`/`settings.json`/`docs/agent-rules/*`
are **not** copies of that template — they're this repo's own real,
hand-written project files, since this is a docs/tooling repo, not a generic
app. The two enforcement files *are* meant to be identical everywhere, so at
root they're symlinks into `templates/` rather than a second copy.

**Orchestration vs. knowledge, one source of truth.** Each skill in
`.claude/skills/` holds reusable knowledge (standards, checklists, rules) with no
orchestration. Each sub-agent in `.claude/agents/` wraps a skill with
orchestration — what context to read, what to output, what not to touch — and
preloads it via the `skills:` frontmatter field (Claude injects the full skill
body into the sub-agent at startup). The *same* skill also backs its `/slash`
command for ad-hoc use, so the knowledge lives in exactly one place — no
duplication, nothing to drift.

**Project-agnostic knowledge, project-owned extensions.** The skills and
sub-agents contain no project-specific text. They name your commands, app URL,
and default branch *by role* from `AGENTS.md` → *Commands*, and they read your
own review rules and risk lenses from `docs/agent-rules/` at runtime (a missing
file means base rules only).

## Installing into a project

Install the plugin (`/plugin marketplace add`, then `/plugin install` —
choose the `project` scope if you want the install recorded and shared via
your project's own git history). Then, inside the project, run
**`/init-workflow`**.

On a brand-new project, `/init-workflow` scaffolds the project-owned files
from the plugin's bundled templates (proposing the full list before writing
anything), then continues straight into adaptation: it detects your
build/test commands and default branch, drafts the `AGENTS.md` sections from
the real codebase, interviews you to seed `docs/agent-rules/`, and validates
the whole setup (hook, `core.hooksPath`, settings, `.gitignore`, CI).
Everything is proposed and confirmed before it is written; whatever you
defer stays an explicit TODO. The section below is the manual map of the
same work.

**Updating later**: update the plugin (`/plugin marketplace update` /
`/plugin update`, per whatever scope you installed at), then re-run
`/init-workflow` — in doctor mode it reports anything the update newly
expects.

## Adapting it to your project — where your content goes

You never edit the skills. All project-specific content lives in files you own:

- **`AGENTS.md`** — overview, architecture, testing conventions, the
  *Sensitive Areas* (security surface) list, and the *Commands* section, the
  single home of every `[PLACEHOLDER]`:

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

- **`docs/agent-rules/code-critic.md`** — your repo's hard review constraints
  (one bullet per rule, each with a severity), read by the `code-critic` skill
  on every review. This is the file that grows over time as agents produce bad
  output the base rules didn't catch. It includes the privacy anchors
  (sensitive categories, public surfaces, identifier exemptions, existing
  privacy tests) that bind the base privacy rules to your codebase — for a
  project holding personal data, the most consequential file in the plugin.
- **`docs/agent-rules/plan-critic.md`** — the areas where generic plans
  regularly miss issues that matter for *your* product, read by the
  `plan-critic` skill on every critique.
- **`docs/product-context/`** and **`docs/adr/`** — your vision/strategy docs and
  architecture decisions.

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
recorded review. Human bypass: `git push --no-verify`.

**What the gate does and doesn't enforce.** The hook deterministically
enforces *freshness*: the pushed commit must be exactly the SHA recorded at
review time, so any commit made after a review forces a re-review. It does
**not** verify the review's verdict — `review-ok.sh` records whatever it is
told, on the agent's honesty. Three mitigations ship with the scaffold:
`.claude/settings.json` makes any run of `review-ok.sh` require human
approval in Claude Code (the human is the final sign-off on the gate) and
denies the agent the bypass flags (best-effort prefix matching); CI is the
independent evidence that tests pass on the pushed state
(`.github/workflows/ci.yml.example` — rename and fill in); and
`review-ok.sh` warns when `core.hooksPath` is unset, so a clone that forgot
the one-time setup finds out instead of running gateless.

## Day-to-day use

Start each feature session on a **fresh feature branch created by you** — the
agents may not create or switch branches (Rule 3 in `AGENTS.md`), and the
workflow diffs against the default branch and opens a PR targeting it, neither
of which works from the default branch itself. Then drive the work with
`/feature`.

## Evolving the system

See *Evolving the System* in `docs/AI-workflow.md` (the canonical version —
this section deliberately doesn't restate it). The short version: start small
(planner + code-critic first); every time an agent's bad output slips past
the rules, add a rule to `docs/agent-rules/code-critic.md` — or better, a
build-enforced fitness test; keep `AGENTS.md` lean.
