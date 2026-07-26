# AI-Assisted Development Workflow Guide

## Overview

This document describes the approach this repository uses to improve the quality
and consistency of AI-generated code: structuring the repo with clear
instructions, coding standards, and specialized sub-agents that each own a
distinct phase of the development workflow.

The core idea is that giving an agent access to code and telling it what to build
is not enough. The quality of AI output depends heavily on the structure,
constraints, and standards already embedded in the repository. By combining
well-documented guidelines with purpose-built sub-agents — each operating in its
own context window — we replicate the roles of a real development team: planner,
plan critic, code critic, and QA. (Implementation is deliberately not
delegated — the main agent plays the developer, as the workflow below shows.)

This template is deliberately **Claude-native**: the sub-agents and skills
use Claude Code's own mechanisms (sub-agent definitions, skills, and the
`skills:` preload) with no intermediate layer, distributed as a plugin from
`plugins/ai-workflow/` in this repo's source. The
root `AGENTS.md` still gives baseline, cross-tool project context, but the deep
agent/skill definitions are Claude-specific. (If you later need the workflow
knowledge to be portable to another AGENTS.md-aware tool, you would lift the
skill bodies out of `plugins/ai-workflow/skills/` into tool-neutral markdown and have both
the skills and that tool reference them — the split this template intentionally
collapsed.)

> A project that scaffolds from this plugin starts with project-specific
> rules, commands, and product context left as placeholders, all in
> project-owned files — `AGENTS.md`, `docs/agent-rules/`,
> `docs/product-context/` (search those for `[` and `TODO`); the skills and
> sub-agents supplied by the plugin are project-agnostic and need no
> editing. See the top-level `README.md` for installing and adapting.

## Repository Structure

This is the shape of a project *after* installing the plugin and running
`/init-workflow`:

```
project-root/
├── AGENTS.md                              # Lean project guide (canonical)
├── CLAUDE.md                              # Thin: imports AGENTS.md via `@AGENTS.md`
├── .claude/
│   └── settings.json                      # Permission rules guarding the review gate
├── .github/workflows/
│   └── ci.yml.example                     # CI skeleton — rename to ci.yml and fill in
├── githooks/
│   └── pre-push                           # Review gate: blocks pushes of unreviewed commits
├── scripts/
│   └── review-ok.sh                       # Records a passing review for the current HEAD
├── docs/
│   ├── adr/
│   │   ├── README.md                      # ADR format guide
│   │   └── 0001-record-architecture-decisions.md
│   ├── agent-rules/                       # Project-owned skill extensions (read at runtime) —
│   │   ├── code-critic.md                 #   review rules + privacy anchors — Step 4 creates
│   │   └── plan-critic.md                 #   risk lenses — these two conditionally, see below
│   └── product-context/
│       └── README.md                      # Product-context guide
├── .gitignore                             # NOT a template file — /init-workflow creates it if
│                                              #   missing and appends its three entries either way
└── src/
    └── <module>/
        └── AGENTS.md                      # Optional, NOT scaffolded — you add this yourself
```

The **canonical enumeration** of what `/init-workflow` can scaffold is
`plugins/ai-workflow/skills/init-workflow/templates/` itself, not this tree — the two
entries marked above aren't template files. This tree exists for human
orientation and must stay in sync with `templates/` (AGENTS.md Rule 5 in
this repo requires it), but Step 1 of `/init-workflow` reads `templates/`
directly rather than this diagram. `templates/`'s `AGENTS.md.template`/
`CLAUDE.md.template`/`settings.json.template` land at `AGENTS.md`/
`CLAUDE.md`/`.claude/settings.json` (dropping the `.template` suffix);
everything else keeps its relative path — **except**
`docs/agent-rules/code-critic.md`/`plan-critic.md`, which Step 1
deliberately does not copy. Step 4 asks first whether the project already
has equivalent docs elsewhere: if not, it copies these two from
`templates/` and fills them in; if so, it points `AGENTS.md`'s *Review &
Planning Guidance* section at the existing file instead, and neither
template file is ever written. See that skill's own Step 4 for the full
logic — this is the one place the tree and the scaffold behavior
genuinely diverge, by design.

The plugin itself (`plugins/ai-workflow/agents/`, `plugins/ai-workflow/skills/`)
is not vendored into the project — it's supplied by the plugin install and
lives wherever Claude Code resolves an installed plugin's files. This guide isn't inside that installed payload either (the marketplace
entry's `source` is `./plugins/ai-workflow`, and this file lives outside
it, at the repo root) — it's linked from `plugin.json`'s `homepage` field
instead, in this repo's own source. Everything in the tree above, except
the two entries marked otherwise and the two conditional `docs/agent-rules/`
files just discussed, is scaffolded into the project by `/init-workflow`
from the plugin's bundled templates whenever its own destination is found
missing — each file's presence is checked independently, so a project that
already has its own `AGENTS.md` still gets the review gate scaffolded (and
vice versa). `.claude/settings.json` is the one file handled as a merge
rather than a copy, since a project-scope plugin install can create it
before `/init-workflow` ever runs; `githooks/pre-push`/`scripts/review-ok.sh`
are left alone only if they already are this gate's files, not any
pre-existing script at that path (see that skill's Step 1; see *Installing
and updating the plugin* below); the project owns each file from that
point on.

This repo (the plugin's own source) is the one exception, but not the way
you might expect: it carries `plugins/ai-workflow/agents/`,
`plugins/ai-workflow/skills/`, and `docs/AI-workflow.md` — the plugin's real
source — *and*, side by side, its own real `AGENTS.md`/`CLAUDE.md`/
`.claude/settings.json`/`docs/agent-rules/*`, because it's a real project in
its own right, not just a plugin package. It does **not**, however, carry
project-local `.claude/skills/`/`.claude/agents/` copies of its own tooling.
That was tried — twice, in two shapes, during this plugin's initial
packaging — and rejected both times: with the plugin also installed
globally, Claude Code would show both bare `/feature` (project-local) and
`/ai-workflow:feature` (the installed plugin) at once, two command surfaces
for the same thing with no way to know if they'd drifted. To dogfood
`/feature` etc. while working on this repo, install the plugin the same
way any consumer would.

> Note: there is no `feature` sub-agent. `feature` is a workflow skill
> (`plugins/ai-workflow/skills/feature/SKILL.md`) the **main** agent runs; it orchestrates
> the planner, plan-critic, code-critic, and adversarial-qa sub-agents.
> `init-workflow`, `workflow-retro`, and `workflow-inspect` are likewise
> main-agent skills with no sub-agent wrapper — setup and the evaluation
> passes are interactive conversations, not delegated work.

### Why This Structure

Two roles, each with its own home under `plugins/ai-workflow/`, sharing one copy of the
knowledge:

- **Skills** (`plugins/ai-workflow/skills/<name>/SKILL.md`) are the reusable knowledge —
  coding standards, review checklists, planning rules, and the workflow itself
  (`feature`). They carry **no orchestration concerns**, which is what lets a
  single skill serve two consumers at once (see below).
- **Sub-agents** (`plugins/ai-workflow/agents/<name>.md`) are orchestration over a skill:
  the frontmatter sets the tools/model/effort/permission the agent runs with and
  **preloads the skill** via the `skills:` field; the body says what context to
  gather, what to output, and what not to touch. For Claude Code, `skills:`
  injects the **full** skill body into the sub-agent's context at startup
  (sub-agents do not inherit skills from the parent conversation, so each lists
  its own explicitly).
- **One source of truth.** Because the skill holds the knowledge and the
  sub-agent only adds orchestration, the same `SKILL.md` backs both the sub-agent
  (via preload) and the `/slash` command (ad-hoc, invoked directly). The
  knowledge is written once; nothing is duplicated and nothing can drift.

Supporting pieces:

- **`AGENTS.md`** is the lean, tool-agnostic project guide. Keep it lean — as
  instruction count increases, instruction-following quality degrades uniformly
  across all instructions. `CLAUDE.md` imports it with `@AGENTS.md` so Claude
  Code (and its sub-agents) load it without duplicating content.
- **`docs/adr/`** contains Architecture Decision Records — read by the agents,
  maintained as human-facing documentation alongside the other docs.
- **`docs/product-context/`** contains product vision, strategy, and
  requirements — the RAG context the planner and plan-critic ground their work in.
- **Project-specific content lives outside the skills.** The skills are
  project-agnostic: they name the project's commands, app URL, and default
  branch *by role* from `AGENTS.md` → *Commands*, and read the project's own
  review rules and risk lenses at runtime from whatever file `AGENTS.md`'s
  *Review & Planning Guidance* section names — falling back to
  `docs/agent-rules/<skill>.md` if that section is absent or incomplete,
  and to base rules alone if nothing is found either way (the code-critic
  states the absence in its output rather than skipping silently). The
  indirection through `AGENTS.md` means a project can point at a doc it
  already had before adopting this plugin — a style guide,
  `CONTRIBUTING.md` — instead of duplicating that content into a new file;
  see *Installing and updating the plugin* for how `/init-workflow` decides
  which applies. This split is what makes the knowledge layer portable: the
  same skill files apply unchanged to any project, which is what makes
  distributing them as a single Claude Code plugin (rather than a
  per-project copy) possible.
- **Module-level `AGENTS.md`** files are the place for constraints in critical
  areas (e.g. auth, payments) where mistakes are expensive.

**Plan storage:** Plans are not stored in the repository. The planner sub-agent
returns plan text to the main agent, which presents it for user review via plan
mode.

## AGENTS.md

This file should contain the project overview, essential commands, and the
workflow the agent must follow. Detailed standards and rules belong in the
skills and sub-agents supplied by whatever AI workflow plugin is installed —
not copied into the project, so `AGENTS.md` should reference them by role
rather than by a hardcoded path (this template's own plugin happens to keep
its skills/agents at `plugins/ai-workflow/skills/` and
`plugins/ai-workflow/agents/` in its own source, but that's an
implementation detail a project's `AGENTS.md` shouldn't depend on — see
`AGENTS.md` in this repo's own root for how that decoupling reads in
practice). The real file is at the repo root — the skeleton below shows the
shape a lean `AGENTS.md` should keep:

```markdown
# Project Name

## Overview
Brief description of the project, its purpose, and how it fits into the broader system.

## Tech Stack
- Language/framework versions, key dependencies, infrastructure

## Commands
- `[BUILD_CMD]` — Build the project
- `[TEST_CMD]` — Run all tests
- `[CHECK_CMD]` — All checks incl. tests
- `[RUN_CMD]` — Dev server (serves at `[APP_URL]`)
- default branch: `[DEFAULT_BRANCH]`

## Project Structure
- `src/api/` — HTTP handlers, request/response types
- `src/domain/` — Business logic, domain models
- `src/infra/` — Database, external service clients

## Key Context
- Product vision, strategy, requirements: `docs/product-context/`
- Architecture Decision Records: `docs/adr/`
- Sub-agents and skills: supplied by the installed AI workflow plugin
- AI workflow guide: the plugin's own documentation

## Review & Planning Guidance
- Code review guidance: `docs/agent-rules/code-critic.md`
- Planning guidance: `docs/agent-rules/plan-critic.md`

## Workflow for New Features
Use the `/feature` slash command to trigger the full workflow (plan, critique,
implement, review, QA) with explicit gates between steps. See the installed
plugin's own documentation for the complete definition.
```

If your primary tool is Claude Code, keep `CLAUDE.md` thin and have it import
`AGENTS.md` with `@AGENTS.md` — the approach this repo uses. (Avoid a
`ln -s AGENTS.md CLAUDE.md` symlink: a single file under two names confuses
agents about which is canonical.)

## Skills — the reusable knowledge

Skills live in `plugins/ai-workflow/skills/<name>/SKILL.md` and contain reusable knowledge:
standards, rules, checklists, and templates. They carry no orchestration
concerns, so the same file backs both a workflow sub-agent (preloaded via
`skills:`) and an ad-hoc slash command — and no project-specific content,
which is what the `docs/agent-rules/` extension files and the `AGENTS.md`
*Commands* section exist for. Each summary below is a pointer — the
linked file is the source of truth. Keep each `SKILL.md` focused (Claude Code
recommends under ~500 lines; move bulky reference material into sibling files in
the skill's directory).

### `plugins/ai-workflow/skills/plan-draft/SKILL.md` — `/plan-draft`

Produces the implementation plan before any code is written. The design
choices worth knowing: the plan opens with a phone-sized **Approval Summary**
(the thing the developer actually approves), pins a **Contract** section
before the Approach, and treats **tests as the plan's deterministic oracle** —
every user-visible claim maps to a committed test tagged `[AC-n]`, and manual
"try X and confirm Y" checklists are banned (each becomes a test assertion
instead). Ambiguities surface as `NEEDS_DECISION` in the plan, never as
questions asked from inside a sub-agent. The skill file holds the full rules
and the plan template. (Named `plan-draft` so it cannot collide with Claude
Code's built-in plan-mode `/plan` command.)

### `plugins/ai-workflow/skills/plan-critic/SKILL.md` — `/plan-critic`

Attacks a **draft plan** before it becomes commitment — if the plan is wrong,
downstream review and QA mostly verify that the wrong thing was built
correctly. Four mandatory methods (pre-mortem, inversion, load-bearing
assumptions, consistency with ADRs and product intent), each of which must
produce findings or an explicit "no concerns, because…". It critiques
substance, not writing, and never rewrites the plan — suggestions go in a
"Suggested Plan Amendments" section; the developer decides what to adopt.
The skill file holds the methods and the output format; the project's own
risk lenses live wherever `AGENTS.md`'s *Review & Planning Guidance*
section points (defaulting to `docs/agent-rules/plan-critic.md`), which the
skill reads at critique time.

### `plugins/ai-workflow/skills/code-critic/SKILL.md` — `/code-critic`

Reviews the diff from an adversarial stance (assume something is wrong; a
review that finds nothing must document its disconfirmation attempt). Two
design points matter to the system as a whole: it **owns test completeness**
— because `/adversarial-qa` is exploratory, verifying that committed tests
cover the plan *and* the branches/boundaries the plan never enumerated lives
here — and its verdicts (`PASS` / `PASS (N/A)` / `FAIL` / `NEEDS_DECISION` /
**Open Question**) are what the `/feature` gates key on. The base standards
(including the base privacy rules) live in the skill; the project's own
rules and privacy anchors live wherever `AGENTS.md`'s *Review & Planning
Guidance* section points (defaulting to `docs/agent-rules/code-critic.md`),
which the skill reads at review time. Any mechanically checkable rule should
graduate to a build-enforced test (below), after which the reviewer only
checks that the diff doesn't weaken the enforcement. The skill file holds
the full standards, checklist, and output format.

## Deterministic enforcement — below the LLM layer

Instructions alone drift; three mechanisms enforce the load-bearing gates
mechanically, so neither the agents nor the human re-verify them by hand:

- **Architecture / fitness tests** encode the mechanically checkable review
  rules as build failures (layer direction, banned APIs, required
  registrations/annotations, reserved route segments, and so on). The
  code-critic skill tells the reviewer to verify only that a diff doesn't
  *weaken* these tests, not to re-derive the rules. Start with the layer rule
  (*Your first fitness test*, below). <!-- [TODO: add fitness tests for your
  stack and list them as build-enforced rules in your code review guidance
  file (docs/agent-rules/code-critic.md by default).] -->
- **The pre-push review gate** (`githooks/pre-push`, enabled once per clone
  via `git config core.hooksPath githooks`): after a code-critic pass with
  no FAIL items, the agent records the reviewed HEAD with `scripts/review-ok.sh`;
  the hook refuses to push any other commit, so post-review changes force a
  re-review. Human bypass: `git push --no-verify`. Be precise about the trust
  boundary: the hook deterministically enforces **freshness** (the pushed
  commit is exactly the reviewed one), not the review's **verdict** —
  `review-ok.sh` records whatever it is told. The verdict is covered by the
  `ask` rule in `.claude/settings.json` (recording a pass always surfaces a
  human approval prompt in Claude Code, and the bypass flags are denied to
  agents, best-effort) and by CI as independent test evidence. `review-ok.sh`
  also warns when `core.hooksPath` is unset, so a clone that skipped the
  one-time setup finds out instead of running gateless.
- **CI** — independent evidence for the human reviewer that tests pass on the
  pushed state, replacing trust in a session transcript (or in a test summary
  pasted by the implementing agent). A ready-to-adapt skeleton ships as
  `.github/workflows/ci.yml.example` — rename to `ci.yml` and replace the
  placeholders.
- **Secret and dependency scanning** — wire a secret scanner (e.g. gitleaks)
  and a dependency audit into the all-checks command and CI, so committed
  credentials and known-vulnerable dependencies fail the build instead of
  relying on reviewer attention. These are the cheapest security gates in the
  pipeline. The CI skeleton includes gitleaks. <!-- [TODO: add a dependency
  audit for your stack and mirror both scanners into the all-checks command
  for local runs.] -->

Deferred QA findings live as GitHub issues labeled **`known-issue`** — not in
the repo, not in session memory — so every agent and session sees the same
triage state, and the `/adversarial-qa` skill reports matches as known instead of
re-surfacing them.

### Your first fitness test: the layer rule

The highest-value fitness test is the **layer-dependency rule** — layer
violations are invisible in a diff (an `import` line looks harmless) but erode
the architecture over time. It ships as a placeholder because *what enforces it*
is stack-specific, but *the rule itself* is not:

- **`domain` must not depend on `api`** — the core is independent of delivery.
  Universal; never disputed.
- **`api` and `infra` must not depend on each other** — sibling outer layers
  stay decoupled.
- **No package cycles.**
- **The `domain`↔`infra` edge is a convention choice** — forbid `domain → infra`
  for clean/hexagonal (domain is pure; infra implements its ports); allow it for
  traditional layered (web → service → repository). Pick one.

Enforce it with the real dependency-analysis tool for your stack. Do **not**
substitute a text/grep check: it can't see package semantics, aliased imports,
or cycles, and a gate you can't fully trust defeats the purpose of deterministic
enforcement (a false green is worse than an honest gap the reviewer still sees).

| Stack               | Tool                                             |
|---------------------|--------------------------------------------------|
| Kotlin / Java / JVM | ArchUnit (bytecode) or Konsist (Kotlin-native)   |
| TypeScript / JS     | dependency-cruiser or eslint-plugin-boundaries   |
| Python              | import-linter                                    |
| Go                  | depguard or arch-go                              |

Wire it into the all-checks command and CI so it gates merges, and list it as
a build-enforced rule in your code review guidance file
(`docs/agent-rules/code-critic.md` by default) so the reviewer verifies the
diff doesn't *weaken* the layer test rather than re-deriving boundaries by
hand. Add further fitness tests the same way — one per
mechanically checkable rule.

### `plugins/ai-workflow/skills/adversarial-qa/SKILL.md` — `/adversarial-qa`

**Exploratory and adversarial — not a re-verification of the spec.** Committed
end-to-end tests encode the plan's Requirements deterministically (and
code-critic checks their completeness); `/adversarial-qa`'s job is to go
**beyond** them. It drives the feature in the **running app** via the
Playwright MCP, probes past the happy path, and surfaces anything that looks
wrong — even outside the feature's plan — rather than working around it. It
checks open `known-issue` GitHub issues so already-deferred findings are
reported as known instead of re-triaged, and STOPs on blockers (server won't
start, Playwright unavailable) with no curl/SQL substitutes. Evidence
screenshots land in `.qa-evidence/` — gitignored and session-local, which is
why deferred findings must be fully described in their `known-issue` issue.
The skill file holds the probe list and output format.

### `plugins/ai-workflow/skills/feature/SKILL.md` — `/feature`

The full lifecycle the **main** agent runs for non-trivial work:
**plan → critique → implement → test → code-review → QA → PR**. The
authoritative step list lives in the skill; the orchestration view is
diagrammed under *How It Works* below. The gates worth naming: the session
must start on a human-created feature branch (agents may not create one —
Rule 3); plan mode is entered before any planning (a structural block on
edit tools until approval); the plan-critic may be skipped only for trivial
changes **and** only when the user explicitly asks; `[AC-n]` acceptance tests
are written before implementation and may not be weakened to pass; no push or
PR until the code-critic passes with no FAIL items (recorded via
`scripts/review-ok.sh`, enforced by the pre-push hook), with the reviewer's
model escalated to Opus on security-surface diffs; QA runs only for changes
with a UI surface; and the PR body carries the pipeline's conclusions (plan
summary, AC → test table, review outcome with decisions, QA dispositions,
test evidence).

### `plugins/ai-workflow/skills/init-workflow/SKILL.md` — `/init-workflow`

The bootstrap-and-adaptation pass, run by the **main** agent once the plugin
is installed in a project (and re-run any time as a doctor). It first
scaffolds whichever project-owned files are missing, from
`plugins/ai-workflow/skills/init-workflow/templates/` (its bundled source of
truth) — each file's own destination gates its own scaffolding, so this
runs the same whether the project is brand-new or already has some of its
own `AGENTS.md`/`CLAUDE.md`/gate files — then continues into adaptation:
detects the build/test commands and
default branch, drafts the `AGENTS.md` sections from the actual codebase,
asks whether the project already has docs for code review/planning
guidance — pointing `AGENTS.md`'s *Review & Planning Guidance* section at
them if so, or interviewing the user to seed new files under
`docs/agent-rules/` if not — and validates the whole setup (hook
executable, `core.hooksPath`, `CLAUDE.md` import, `.gitignore`, settings,
CI, no unfilled Commands placeholders, the guidance section itself
resolving to real files). Everything is proposed and user-confirmed before
writing; deferred items stay explicit TODOs. It never
edits the plugin's own mechanism — skills, sub-agents, and this guide update
via the plugin itself. (Named `init-workflow` to avoid Claude Code's
built-in `/init`.) The skill file holds the step list and the doctor
checklist; `templates/` holds everything it scaffolds.

### `plugins/ai-workflow/skills/workflow-retro/SKILL.md` — `/workflow-retro`

An optional end-of-session pass, run manually by the **main** agent after a
`/feature` session (typically once the PR is open). It records the *outcome*
half of the feature's workflow evaluation — which steps ran or were skipped,
cycle counts, what each critic caught and what was adopted, plus a short
judgment section — as one fixed-schema file per feature branch in
`.workflow-log/` (gitignored: local evaluation data, never committed). The
directory lives under the repo's **main** worktree, so records survive the
deletion of per-feature worktrees. The
file also records the session's transcript ID(s) so the companion
`/workflow-inspect` skill can later join the *cost* half from the raw
transcripts — which are pruned after Claude Code's retention window, so that
join is time-boxed; the distilled record in `.workflow-log/` is what
persists. Over several features, these records are the evidence base for
tuning the workflow — see *Evolving the System*.

### `plugins/ai-workflow/skills/workflow-inspect/` — `/workflow-inspect`

The retro's companion, run manually by the **main** agent any time after a
retro, while the session transcripts still exist. It fills the record's
pending `## Cost` section with numbers computed by a bundled read-only
script (`inspect.py`, requires `python3`): tokens and wall-clock per
sub-agent, the sub-agents' share of total output, and the handoff tax —
files the planner read that the main agent re-read. The script locates
transcripts by a global search of `~/.claude/projects/` for the recorded
session IDs (transcripts are filed under the session's *launch* directory,
so path derivation is unreliable), resolves each sub-agent's transcript via
its spawn `toolUseId`, and deduplicates records shared by resumed sessions;
it fails soft, folding anything unparseable or missing into warning lines.
The transcript format is Claude Code internal and undocumented — the script
observes it, it is not a contract.

## Sub-agents — orchestration over the skills

Each `plugins/ai-workflow/agents/<name>.md` file is a Claude Code sub-agent definition: YAML
frontmatter (metadata + tools/model/effort/permission + the `skills:` to
preload) followed by the body, which **is** the sub-agent's system prompt. The
body is written for the **autonomous** case (a sub-agent), which also makes it
usable as an interactive main agent (`claude --agent <name>`).

- **`planner`** — senior architect. Reads the prompt, linked docs, module
  `AGENTS.md` files, ADRs, and product docs; applies the preloaded `plan-draft`
  skill; returns plan text only (no files, no code).
- **`plan-critic`** — adversarial plan reviewer. Reads the plan text, relevant
  ADRs, product docs in `docs/product-context/`, and touched-module `AGENTS.md`
  files; applies the preloaded `plan-critic` skill; surfaces concerns without
  rewriting the plan.
- **`code-critic`** — strict reviewer. Bash for **read-only** inspection only
  (`git diff`, `git log`, dependency/version checks); never runs the test suite
  or mutates files; applies the preloaded `code-critic` skill; outputs the review
  only.
- **`adversarial-qa`** — QA engineer. Not a code-quality review; applies the preloaded `adversarial-qa`
  skill to drive the running app and surface what the plan and tests missed.

Each sub-agent's frontmatter pins its tools, model, effort, permission mode,
and the one skill it preloads. The four files in `plugins/ai-workflow/agents/` are the
source of truth — each is one screen long, so their values are deliberately
not restated here (a table of them is exactly the kind of verbatim copy that
drifts). The design choices behind those values:

- `planner` and `plan-critic` carry `permissionMode: plan`, so they stay
  read-only structurally, not just by instruction.
- Only the `planner` carries `WebFetch` — external specs enter the pipeline
  at exactly one point.
- `adversarial-qa` lists the Playwright `browser_*` MCP tools so it can
  drive the app.
- The plan-stage critics run on the stronger model tier (a bad plan poisons
  everything downstream); the `code-critic` runs a tier lower by default and
  is escalated by the `/feature` workflow on security-surface diffs.
- Each agent lists exactly the one skill it applies, so that skill's full
  body is preloaded into its context at startup and the agent body only
  needs the orchestration (what to read, what to output, what not to touch).

## How It Works

### Orchestrated workflow (main agent coordinates)

When you trigger `/feature` (or ask the main agent to implement a feature), it
follows the `/feature` skill (`plugins/ai-workflow/skills/feature/SKILL.md`):

1. **Main agent** → enters plan mode immediately, before any sub-agent work, so
   edit tools are blocked until approval.
2. **Planner sub-agent** (isolated context) → reads the prompt, linked docs,
   ADRs, and codebase → returns plan text.
3. **Plan-critic sub-agent** (isolated, read-only) → pre-mortem, inversion,
   load-bearing-assumption, and consistency analysis against ADRs and product
   docs → returns critique text. Skipped only when the change meets *all* of the
   trivial-change criteria in the `/feature` skill **and** the user explicitly
   asked to skip it.
4. **Main agent** → exits plan mode by presenting **both** the plan and the
   critique; the user reads them together and decides.
5. **Main agent** (interactive) → implements the approved plan. You can steer and
   course-correct during this phase.
6. **Code-critic sub-agent** (isolated) → reads its standards, checklist,
   project-specific rules, and the approved plan → returns a structured review,
   including verification that committed tests cover the spec and beyond.
7. `NEEDS_DECISION` / `Open Question` items → main agent relays them to you → you
   decide → main agent applies fixes and re-runs the reviewer until no `FAIL`
   remains.
8. **QA sub-agent** (isolated) → drives the running app in a browser via
   Playwright, probing **beyond** the plan and committed tests for anything that
   looks wrong → returns findings with evidence. (It does not re-check the
   Requirements — that is locked down by the committed tests and code-critic.)
9. PR is opened only after the code review passes and every QA finding is
   dispositioned (or QA was skipped for lack of a UI surface).

The same orchestration as a picture. Solid arrows are the information that flows
between agents, numbered **1–13** in information-flow order (these numbers track
message passing and do not line up one-to-one with the Step 1–9 numbering in the
`/feature` skill); **↻** marks loops that are not part of the linear sequence —
re-review after fixes, including QA-driven changes, and decision relays that fire
whenever a sub-agent raises an item. Dotted arrows are repo context a sub-agent
reads at any point during its step:

```mermaid
flowchart TB
    User([User])
    PR([Pull request])

    subgraph Repo [Repo context the sub-agents read]
        direction LR
        ADR["ADRs in docs/adr/"]
        Docs["docs/product-context/"]
        Code["repo code + git diff"]
    end

    Main{{Main agent<br/>orchestrator}}
    Planner[[planner]]
    Critic[[plan-critic]]
    Reviewer[[code-critic]]
    QA[[adversarial-qa]]
    App([Running app])

    User -- "1. feature prompt + links" --> Main

    Main -- "2. prompt (verbatim)" --> Planner
    Planner -- "3. draft plan" ---> Main

    Main -- "4. draft plan" --> Critic
    Critic -- "5. critique" ---> Main

    Main -- "6. plan + critique" ---> User
    User -- "7. approval / amendments" --> Main

    Main -- "8. implement approved plan" --> Main

    Main -- "9. approved plan + diff" --> Reviewer
    Reviewer -- "10. review: PASS / FAIL /<br/>NEEDS_DECISION / Open Question" ---> Main
    Main -- "↻ fix FAIL or QA-driven change, re-run" ----> Reviewer

    Main -- "11. approved plan (context)" --> QA
    QA -- "12. findings + .qa-evidence/" ---> Main

    Main -- "↻ relay NEEDS_DECISION /<br/>QA findings" ----> User
    Main -- "13. open PR (review passed,<br/>QA dispositioned)" --> PR

    Planner -.-> ADR & Docs & Code
    Critic -.-> ADR & Docs & Code
    Reviewer -.-> ADR & Code
    QA -. drives via Playwright .-> App

    classDef hub fill:#1d4ed8,stroke:#1e3a8a,color:#ffffff;
    classDef agent fill:#059669,stroke:#065f46,color:#ffffff;
    classDef actor fill:#f59e0b,stroke:#b45309,color:#1f2937;
    classDef ctx fill:#e5e7eb,stroke:#9ca3af,color:#1f2937;

    class Main hub;
    class Planner,Critic,Reviewer,QA agent;
    class User,PR actor;
    class ADR,Docs,Code,App ctx;

    style Repo fill:#f9fafb,stroke:#d1d5db,color:#374151;
```

Each sub-agent runs in its own isolated context — they never talk to each other
directly; the main agent is the only hub, passing artifacts (plan, critique,
review, findings) between phases and relaying decisions to and from the user.
Step 8 is a self-loop because implementation is the main agent's own work, done
between plan approval and code review rather than delegated to a sub-agent.

### Direct invocation (interactive)

Any sub-agent can be invoked directly for an interactive session:

```bash
# Claude Code
claude --agent code-critic
```

When invoked directly, the agent runs as the main agent with full interactivity —
useful for ad-hoc reviews, exploratory planning, or discussing a concern with a
specialized agent.

### Key design principle for sub-agent prompts

Since the same agent file can run as an autonomous sub-agent or an interactive
main agent, write prompts for the autonomous case. Instead of:

> "If you find an ambiguous pattern, ask the user whether to flag it as a warning
> or an error."

Write:

> "If you find an ambiguous pattern, flag it in your output as `NEEDS_DECISION`
> with both options described, so the developer can decide."

This produces clear, actionable output in both modes.

### Ad-hoc invocation via skills (slash commands)

Claude Code skills expose each workflow step as a slash command, outside the full
orchestrated cycle — useful for reviewing code you wrote manually, planning a
spike, or running QA on one area. Skills generally live in `.claude/skills/`
(project-scoped) or `~/.claude/skills/` (personal) — but this plugin's own
skills live at `plugins/ai-workflow/skills/` in its source, not in either of
those, since they're supplied by the plugin install rather than copied into
a project. Each is a directory with a `SKILL.md` that holds the full
knowledge — the same file the matching sub-agent preloads. For example,
`/code-critic` and the `code-critic` sub-agent both use
`plugins/ai-workflow/skills/code-critic/SKILL.md` — see that file for the shape: a `name`,
a `description` the tool matches invocations against, and a body that is the
knowledge itself.

The eight wired-up commands are `feature`, `init-workflow`, `plan-draft`,
`plan-critic`, `code-critic`, `adversarial-qa`, `workflow-retro`, and
`workflow-inspect` — installed via this plugin, Claude Code may expose them
namespaced as `/ai-workflow:feature` etc. rather than bare `/feature`
(unverified — see *Installing and updating the plugin*, this hasn't been
exercised end to end yet). The rest of this guide uses the bare forms as
shorthand for the skill/command by name, not as a claim about the exact
string you'd type once installed — treat every bare `/name` below as
provisional on that same open question. `feature` is the primary entry point — it
triggers the full orchestrated workflow; `init-workflow` is the one-time
setup (and recurring doctor) pass; `workflow-retro` and `workflow-inspect`
are the optional evaluation pair (outcome record, then cost fill-in); the
others invoke individual steps ad-hoc.

**Naming note (Claude Code).** Claude Code **bundles** a skill named
`code-review`, and project skills shadow bundled skills completely and by
design ([Skills docs](https://code.claude.com/docs/en/skills) use
`code-review` as their own example). This template deliberately names its
review skill `code-critic` to avoid that collision: `/code-critic` always
resolves to this repo's checklist — the same copy the `code-critic`
sub-agent preloads via `skills: [code-critic]` — while the bundled
`/code-review` (including `/code-review ultra`, the billed deep cloud review)
stays reachable as an optional, user-launched pass on especially high-stakes
changes. Do not rename the skill back to `code-review` unless you want the
shadowing. The planning skill follows the same principle from the other
direction: it is named `plan-draft` rather than `plan` because Claude Code's
built-in *plan-mode* command already answers to `/plan` (a separate mechanism
from skills), and the rename removes the collision instead of documenting it.
`init-workflow` follows suit: Claude Code bundles an `/init` command (it
generates a `CLAUDE.md`), so the setup skill takes a distinct name. This
rationale predates the plugin packaging and was written for project-scoped
skills; if plugin skills turn out to be namespaced by default (the same
open question noted above), the collision these names dodge may not even
be reachable post-install — but the names stay regardless, since renaming
back would be a real breaking change for no benefit either way.

#### Skills vs sub-agents vs slash commands

Three concepts, two directories under `plugins/ai-workflow/`:

- **Skills** (`plugins/ai-workflow/skills/<name>/SKILL.md`) are the reusable knowledge —
  standards, checklists, rules, templates. No orchestration behavior.
- **Sub-agents** (`plugins/ai-workflow/agents/<name>.md`) compose a skill with orchestration —
  what context to read, output format, file constraints, and the tools/model the
  agent runs with. They preload their skill via the `skills:` frontmatter field.
- **Slash commands** are just the skills invoked directly (`/plan-draft`,
  `/code-critic`, …), skipping the orchestration layer, for interactive ad-hoc
  use. `/feature` is the exception — its skill triggers the full orchestrated
  workflow.

The knowledge lives in one place (`plugins/ai-workflow/skills/`). Sub-agents compose it with
workflow behavior; slash commands expose it directly. The workflow itself
(`plugins/ai-workflow/skills/feature/SKILL.md`) is also a skill, so `AGENTS.md` references it
instead of duplicating the steps.

## Installing and updating the plugin

*This hasn't been exercised end-to-end yet — see `README.md` for what's
verified so far.*

The workflow is distributed as a single Claude Code plugin:

```
/plugin marketplace add cunhaax/ai-workflow-template
/plugin install ai-workflow@ai-workflow
```

Choose a scope (`user`/`project`/`local`) at install time. Project scope
records the install (and its pinned version, if any) in the project's own
`.claude/settings.json`, so the choice of workflow version is committed and
reviewable in that project's git history like any other dependency bump.

This gives the same two ownership classes as before, just split across two
different homes instead of one repo:

- **Plugin-owned** — the skills and the sub-agents. These are not copied
  into the project at all; they live wherever Claude Code resolves the
  installed plugin's files, and they update when the plugin updates
  (`/plugin update`, per whatever scope was chosen). This guide isn't part
  of that installed payload (see *Repository Structure* above) — it's
  linked from `plugin.json`'s `homepage` field, in this repo's own source.
- **Project-owned** — `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`,
  the CI example, the ADR/product-context scaffolding, and the two
  enforcement files (`githooks/pre-push`, `scripts/review-ok.sh` — these
  must physically live in the project's own repo, since a git hook has to
  fire for humans and every tool, not just Claude). These get scaffolded
  into the project by `/init-workflow` whenever each one's own destination
  is missing — no file's presence gates another's, so adopting the gate
  doesn't require rewriting a project's existing guidance doc, and a
  pre-existing `AGENTS.md` still gets the gate. `.claude/settings.json` is
  merged rather than overwritten if it already exists (a project-scope
  install, per the paragraph above, can create it first); both
  `githooks/pre-push` and `scripts/review-ok.sh` are left alone only if
  their content already identifies them as this gate's files, and flagged
  as a conflict otherwise. Sourced from
  `plugins/ai-workflow/skills/init-workflow/templates/` (the plugin's
  bundled source of truth) — see its skill summary above. `.claude/settings.json`
  and the two gate scripts are re-inspected (merged or conflict-checked) on
  every later run; everything else in this list, once written, is not
  touched by the plugin again — the project owns it from that point.
  `docs/agent-rules/*` is the one exception: Step 4 only copies these two
  from `templates/` if the project doesn't already have equivalent docs —
  see that step for the full logic.

Re-run `/init-workflow` after every plugin update — in doctor mode it
reports anything the update newly expects, the same as it reports any other
setup drift.

## Evolving the System

- **Start small.** Begin with the planner and code-critic; add QA and
  plan-critic once the basic workflow is stable.
- **Track failure patterns.** Every time an agent produces bad output your
  rules didn't catch, add a rule to whatever `AGENTS.md`'s *Review &
  Planning Guidance* section names for code review (`docs/agent-rules/code-critic.md`
  by default — the file is designed to accrete) or a lens to its planning
  counterpart (`docs/agent-rules/plan-critic.md` by default).
  The skills in `plugins/ai-workflow/skills/` stay project-agnostic and plugin-owned,
  so plugin updates never collide with your rules.
- **Tune the workflow itself with evidence, not intuition.** Run
  `/workflow-retro` at the end of feature sessions; the per-feature records in
  `.workflow-log/` show what each step cost and caught over time. A step
  that keeps producing nothing is a candidate for a skip rule or removal — a
  step that keeps catching real problems has earned its place. Change the
  workflow's steps on that record, not on how a single session felt.
- **Prefer build-enforced rules over prose.** When a new review rule is
  mechanically checkable, encode it as an architecture/fitness test instead of
  (or in addition to) skill text — tests don't drift, don't consume reviewer
  attention, and the human never has to re-verify them.
- **Keep `AGENTS.md` lean.** Project overview, commands, and a reference to the
  workflow skill — detailed standards and steps belong in the skills.
- **Keep each `SKILL.md` focused.** Under ~500 lines; when a skill outgrows that,
  move bulky reference material into sibling files in the skill's directory and
  reference them from `SKILL.md`.
- **Module-level docs for critical areas.** When a module has specific
  constraints, add an `AGENTS.md` in that directory rather than bloating the root.
- **Don't re-embed.** When updating this guide, summarize and link the canonical
  files in `plugins/ai-workflow/` rather than pasting their contents —
  verbatim copies are what drift.
```
