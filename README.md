# AI-Assisted Development Workflow — Project Template

A portable, tool-agnostic scaffold for running AI coding agents through a
structured lifecycle: **plan → critique → implement → test → code-review → QA →
PR**, with explicit gates between steps and deterministic enforcement below the
LLM layer.

It replicates a real development team as purpose-built sub-agents — planner,
plan-critic, code-critic, QA — each in its own context window, composed from
a single source of reusable knowledge (the *skills*). Implementation itself
stays with the main agent, which orchestrates the rest.

Read **`docs/AI-workflow.md`** for the full design rationale. This README is the
quick-start for *installing and adapting* the template in a new project.

## What's in here

```
AGENTS.md                    # Lean project guide (canonical; imported by CLAUDE.md)
CLAUDE.md                    # Thin: imports AGENTS.md via @AGENTS.md
.claude/
├── settings.json            # Permission rules: recording a review pass asks the
│                            #   human; the gate's bypass flags are denied to agents
├── agents/                  # Sub-agent definitions (frontmatter + inline prompt)
│   ├── planner.md           # Orchestration + skills: [plan-draft]
│   ├── plan-critic.md       # Orchestration + skills: [plan-critic]
│   ├── code-critic.md       # Orchestration + skills: [code-critic]
│   └── adversarial-qa.md    # Orchestration + skills: [adversarial-qa]  (+ Playwright)
└── skills/                  # The reusable knowledge, one directory per skill
    ├── feature/SKILL.md     # The full workflow (plan→critique→…→PR)
    ├── plan-draft/SKILL.md  # (named plan-draft to avoid Claude Code's built-in /plan)
    ├── plan-critic/SKILL.md
    ├── code-critic/SKILL.md # Base review standards (named code-critic to avoid
    │                        #   shadowing Claude Code's bundled code-review skill)
    └── adversarial-qa/SKILL.md
.github/workflows/
└── ci.yml.example           # CI skeleton — rename to ci.yml and fill in
docs/
├── adr/                     # Architecture Decision Records (ADR 0001 included)
├── agent-rules/             # Project-owned skill extensions, read at runtime:
│   ├── code-critic.md       #   your review rules + privacy anchors
│   └── plan-critic.md       #   your product's risk lenses
├── product-context/         # Vision, strategy, requirements (add your own)
└── AI-workflow.md           # The full guide to this system
githooks/pre-push            # Review gate: blocks pushing unreviewed commits
scripts/
├── install.sh               # Installs/updates the template in a target repo
└── review-ok.sh             # Records a passing review for the current HEAD
.gitignore                   # Ignores .review-passed and .qa-evidence/
```

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
file means base rules only). You never edit `.claude/` to adapt the template —
which is also what makes the knowledge layer copyable between projects, and
installable once at user level (`~/.claude/`) or as a Claude Code plugin later,
without edits.

## Installing into a project

From a clone of this template:

```sh
scripts/install.sh /path/to/your-repo
```

Files come in two ownership classes:

- **Template-owned** — the skills, sub-agents, git hook, `review-ok.sh`, and
  the workflow guide. Copied verbatim and **overwritten on every re-run**;
  they contain nothing project-specific.
- **Project-owned** — `AGENTS.md`, `CLAUDE.md`, `docs/agent-rules/*`,
  `.claude/settings.json`, the CI example, and the ADR / product-context
  scaffolding. Created only if missing, **never overwritten**.

The script also appends the two `.gitignore` entries the gate needs, records
the installed template revision in `.claude/ai-workflow-template.rev` (commit
it — the repo history then shows every template update), and prints the
remaining manual steps (fill in `AGENTS.md` and `docs/agent-rules/`, rename
the CI example, enable the hook).

**Updating later** is the same command: `git pull` in the template clone, then
re-run `scripts/install.sh` against your repo. Template-owned files are
refreshed; everything you filled in stays untouched.

## Adapting it to your project — where your content goes

You never edit the skills. All project-specific content lives in files you own:

- **`AGENTS.md`** — overview, architecture, testing conventions, the
  *Sensitive Areas* (security surface) list — the canonical list `/feature`
  consults for the critic-skip, model-escalation, and PR-flag decisions — and
  the *Commands* section, the single home of every `[PLACEHOLDER]`:

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
  project holding personal data, the most consequential file in the template.
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
told, on the agent's honesty. Three mitigations ship with the template:
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
