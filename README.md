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
└── settings.json                # This repo's own permission rules — symlink → plugins/ai-workflow/skills/init-workflow/templates/settings.json.template
.claude-plugin/
└── marketplace.json             # Lists this repo's one plugin (self-referential: ai-workflow@ai-workflow)
plugins/ai-workflow/
├── .claude-plugin/plugin.json   # Plugin metadata: name, description, version, author, homepage, repository, license
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
    │   └── templates/             # THE scaffold source — single source of truth, below
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
githooks/pre-push                # Symlink → plugins/ai-workflow/skills/init-workflow/templates/githooks/pre-push
scripts/review-ok.sh             # Symlink → plugins/ai-workflow/skills/init-workflow/templates/scripts/review-ok.sh
LICENSE                          # MIT
AGENTS.md, CLAUDE.md             # This repo's own real project guide
```

This repo has no project-local skills or sub-agents — `plugins/ai-workflow/`
is the plugin's real source. To use `/feature` etc. while working on this
repo, install the plugin the same way any consumer would (see *Installing
into a project* below); see `docs/AI-workflow.md` for why.

`init-workflow/templates/` is the single source of truth for what a new
project receives: `AGENTS.md.template`, `CLAUDE.md.template`,
`settings.json.template`, a CI skeleton, `docs/agent-rules/*`, `docs/adr/*`,
`docs/product-context/*`, and the two enforcement scripts. This repo's own
root `AGENTS.md`/`CLAUDE.md`/`docs/agent-rules/*` are real, hand-written
files, not copies of the template; `.claude/settings.json`,
`githooks/pre-push`, and `scripts/review-ok.sh` are symlinks into
`templates/` instead — see this repo's own `AGENTS.md` (*Architecture*
section) for the rationale, which is specific to this repo's own root
layout rather than the general plugin design `docs/AI-workflow.md` covers.

Each skill in `plugins/ai-workflow/skills/` holds reusable, project-agnostic
knowledge (standards, checklists, rules) with no orchestration; each
sub-agent in `plugins/ai-workflow/agents/` wraps a skill with orchestration
(context, output format, tools) and preloads it. Skills also back their
`/slash` command directly for ad-hoc use — one copy of the knowledge,
nothing to drift. Your project's own commands, app URL, and review rules
come from `AGENTS.md` and `docs/agent-rules/` at runtime.

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
**`/init-workflow`**.

**Developing the plugin itself?** The GitHub form above sources from the
published repo's default branch, not your working tree — it won't reflect
in-progress edits. Point the marketplace at a local checkout instead:

```
/plugin marketplace add /path/to/this/repo
/plugin install ai-workflow@ai-workflow
```

`/init-workflow` scaffolds whichever project-owned files are missing from
the plugin's bundled templates (proposing the full list before writing
anything) — every file's own destination gates its own scaffolding, so
adopting this on a project with its own pre-existing `AGENTS.md` still gets
the review gate, and vice versa. (`.claude/settings.json` is merged rather
than overwritten if it already exists — a project-scope install can create
it first — and a foreign pre-existing `githooks/pre-push` or
`scripts/review-ok.sh` is flagged as a conflict rather than silently
trusted.) It then continues into adaptation: detects your build/test
commands and default branch, drafts the `AGENTS.md` sections from the real
codebase, asks whether you already have docs for code review/planning
guidance (pointing `AGENTS.md` at them if so, or seeding
`docs/agent-rules/` if not), and validates the whole setup (hook,
`core.hooksPath`, settings, `.gitignore`, CI, the guidance section itself
resolving to real files). Everything is proposed and confirmed before it is
written; whatever you defer stays an explicit TODO. The section below is
the manual map of the same work.

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

- **`AGENTS.md`'s *Review & Planning Guidance* section** — names the code
  review and planning guidance files by role. `code-critic`/`plan-critic`
  read whatever it points to, falling back to the defaults below if it's
  absent. `/init-workflow` asks up front whether you already have docs for
  this (a style guide, `CONTRIBUTING.md`, an engineering handbook) — if so
  it points here at your existing file instead of creating a new one, so
  you don't have to duplicate content you already maintain.
- **`docs/agent-rules/code-critic.md`** (the default target) — your repo's
  hard review constraints (one bullet per rule, each with a severity). This
  is the file that grows over time as agents produce bad output the base
  rules didn't catch. It includes the privacy anchors (sensitive
  categories, public surfaces, identifier exemptions, existing privacy
  tests) that bind the base privacy rules to your codebase — for a project
  holding personal data, the most consequential file in the plugin. If you
  point at an existing doc instead, `/init-workflow` still asks for these
  and offers to append them as a clearly delineated section at the end of
  it, since a pre-existing doc won't have them.
- **`docs/agent-rules/plan-critic.md`** (the default target) — the areas
  where generic plans regularly miss issues that matter for *your*
  product. Read as free-form lenses, not a checklist, whether it's this
  default file or something you already had.
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
the rules, add a rule to wherever `AGENTS.md`'s *Review & Planning Guidance*
points for code review (`docs/agent-rules/code-critic.md` by default) — or
better, a build-enforced fitness test; keep `AGENTS.md` lean.

## License

MIT — see [`LICENSE`](LICENSE).
