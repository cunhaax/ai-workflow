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

This template is deliberately **Claude-native**: the sub-agents and skills live
directly in `.claude/`, using Claude Code's own mechanisms (sub-agent
definitions, skills, and the `skills:` preload) with no intermediate layer. The
root `AGENTS.md` still gives baseline, cross-tool project context, but the deep
agent/skill definitions are Claude-specific. (If you later need the workflow
knowledge to be portable to another AGENTS.md-aware tool, you would lift the
skill bodies out of `.claude/skills/` into tool-neutral markdown and have both
the skills and that tool reference them — the split this template intentionally
collapsed.)

> This is a **template**. Project-specific rules, commands, and product context
> are left as placeholders (search the tree for `[` and `TODO`). See the
> top-level `README.md` for how to adapt it.

## Repository Structure

```
project-root/
├── AGENTS.md                              # Lean project guide (canonical)
├── CLAUDE.md                              # Thin: imports AGENTS.md via `@AGENTS.md`
├── .claude/
│   ├── settings.json                      # Permission rules guarding the review gate
│   ├── agents/                            # Sub-agent definitions (frontmatter + inline prompt)
│   │   ├── planner.md                     # Orchestration + skills: [plan-draft]
│   │   ├── plan-critic.md                 # Orchestration + skills: [plan-critic]
│   │   ├── code-critic.md                 # Orchestration + skills: [code-critic]
│   │   └── adversarial-qa.md              # Orchestration + skills: [adversarial-qa]  (+ Playwright tools)
│   └── skills/                            # Reusable knowledge, one directory per skill
│       ├── feature/SKILL.md               # Full workflow (plan → critique → implement → review → QA)
│       ├── plan-draft/SKILL.md
│       ├── plan-critic/SKILL.md
│       ├── code-critic/SKILL.md           # Base standards + a Project-Specific Rules section
│       └── adversarial-qa/SKILL.md
├── .github/workflows/
│   └── ci.yml.example                     # CI skeleton — rename to ci.yml and fill in
├── githooks/
│   └── pre-push                           # Review gate: blocks pushes of unreviewed commits
├── scripts/
│   └── review-ok.sh                       # Records a passing review for the current HEAD
├── docs/
│   ├── adr/                               # Architecture Decision Records
│   ├── product-context/                   # Product vision, strategy, requirements
│   └── AI-workflow.md                     # This guide
└── src/
    └── <module>/
        └── AGENTS.md                      # Optional: module-specific constraints for critical areas
```

> Note: there is no `feature` sub-agent. `feature` is a workflow skill
> (`.claude/skills/feature/SKILL.md`) the **main** agent runs; it orchestrates
> the planner, plan-critic, code-critic, and adversarial-qa sub-agents.

### Why This Structure

Two roles, each with its own home under `.claude/`, sharing one copy of the
knowledge:

- **Skills** (`.claude/skills/<name>/SKILL.md`) are the reusable knowledge —
  coding standards, review checklists, planning rules, and the workflow itself
  (`feature`). They carry **no orchestration concerns**, which is what lets a
  single skill serve two consumers at once (see below).
- **Sub-agents** (`.claude/agents/<name>.md`) are orchestration over a skill:
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
- **Project-specific rules** are inlined directly into the relevant skill (e.g.
  the `## Project-Specific Rules` section inside `.claude/skills/code-critic/SKILL.md`).
  Inlining keeps the rules where the reviewer is already reading.
- **Module-level `AGENTS.md`** files are the place for constraints in critical
  areas (e.g. auth, payments) where mistakes are expensive.

**Plan storage:** Plans are not stored in the repository. The planner sub-agent
returns plan text to the main agent, which presents it for user review via plan
mode.

## AGENTS.md

This file should contain the project overview, essential commands, and the
workflow the agent must follow. Detailed standards and rules belong in skills
under `.claude/skills/`; orchestration behavior belongs in sub-agent files under
`.claude/agents/`. The real file is at the repo root — the skeleton below shows
the shape a lean `AGENTS.md` should keep:

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
- `[RUN_CMD]` — Dev server

## Project Structure
- `src/api/` — HTTP handlers, request/response types
- `src/domain/` — Business logic, domain models
- `src/infra/` — Database, external service clients

## Key Context
- Product vision, strategy, requirements: `docs/product-context/`
- Architecture Decision Records: `docs/adr/`
- Sub-agents and skills: `.claude/agents/`, `.claude/skills/`
- AI workflow guide: `docs/AI-workflow.md`

## Workflow for New Features
Use the `/feature` slash command to trigger the full workflow (plan, critique,
implement, review, QA) with explicit gates between steps. See
`.claude/skills/feature/SKILL.md` for the complete definition.
```

If your primary tool is Claude Code, keep `CLAUDE.md` thin and have it import
`AGENTS.md` with `@AGENTS.md` — the approach this repo uses. (Avoid a
`ln -s AGENTS.md CLAUDE.md` symlink: a single file under two names confuses
agents about which is canonical.)

## Skills — the reusable knowledge

Skills live in `.claude/skills/<name>/SKILL.md` and contain reusable knowledge:
standards, rules, checklists, and templates. They carry no orchestration
concerns, so the same file backs both a workflow sub-agent (preloaded via
`skills:`) and an ad-hoc slash command. Each summary below is a pointer — the
linked file is the source of truth. Keep each `SKILL.md` focused (Claude Code
recommends under ~500 lines; move bulky reference material into sibling files in
the skill's directory).

### `.claude/skills/plan-draft/SKILL.md` — `/plan-draft`

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

### `.claude/skills/plan-critic/SKILL.md` — `/plan-critic`

Attacks a **draft plan** before it becomes commitment — if the plan is wrong,
downstream review and QA mostly verify that the wrong thing was built
correctly. Four mandatory methods (pre-mortem, inversion, load-bearing
assumptions, consistency with ADRs and product intent), each of which must
produce findings or an explicit "no concerns, because…". It critiques
substance, not writing, and never rewrites the plan — suggestions go in a
"Suggested Plan Amendments" section; the developer decides what to adopt.
The skill file holds the methods, the project-specific lenses to fill in,
and the output format.

### `.claude/skills/code-critic/SKILL.md` — `/code-critic`

Reviews the diff from an adversarial stance (assume something is wrong; a
review that finds nothing must document its disconfirmation attempt). Two
design points matter to the system as a whole: it **owns test completeness**
— because `/adversarial-qa` is exploratory, verifying that committed tests
cover the plan *and* the branches/boundaries the plan never enumerated lives
here — and its verdicts (`PASS` / `PASS (N/A)` / `FAIL` / `NEEDS_DECISION` /
**Open Question**) are what the `/feature` gates key on. Project-specific
rules and the privacy rules are inlined in the skill; any mechanically
checkable rule should graduate to a build-enforced test (below), after which
the reviewer only checks that the diff doesn't weaken the enforcement. The
skill file holds the full standards, checklist, and output format.

## Deterministic enforcement — below the LLM layer

Instructions alone drift; three mechanisms enforce the load-bearing gates
mechanically, so neither the agents nor the human re-verify them by hand:

- **Architecture / fitness tests** encode the mechanically checkable review
  rules as build failures (layer direction, banned APIs, required
  registrations/annotations, reserved route segments, and so on). The
  code-critic skill tells the reviewer to verify only that a diff doesn't
  *weaken* these tests, not to re-derive the rules. Start with the layer rule
  (*Your first fitness test*, below). <!-- [TODO: add fitness tests for your
  stack and list them in the code-critic skill's Project-Specific Rules
  section.] -->
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
  and a dependency audit into `[CHECK_CMD]` and CI, so committed credentials
  and known-vulnerable dependencies fail the build instead of relying on
  reviewer attention. These are the cheapest security gates in the pipeline.
  The CI skeleton includes gitleaks. <!-- [TODO: add a dependency audit for
  your stack and mirror both scanners into [CHECK_CMD] for local runs.] -->

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

Wire it into `[CHECK_CMD]` and CI so it gates merges, then relink the
`code-critic` skill (its *Architecture* checklist) to "verify the diff doesn't
*weaken* the layer test" rather than re-deriving boundaries by hand. Add further
fitness tests the same way — one per mechanically checkable rule.

### `.claude/skills/adversarial-qa/SKILL.md` — `/adversarial-qa`

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

### `.claude/skills/feature/SKILL.md` — `/feature`

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

## Sub-agents — orchestration over the skills

Each `.claude/agents/<name>.md` file is a Claude Code sub-agent definition: YAML
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
and the one skill it preloads. The four files in `.claude/agents/` are the
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
follows the `/feature` skill (`.claude/skills/feature/SKILL.md`):

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
spike, or running QA on one area. Skills live in `.claude/skills/`
(project-scoped) or `~/.claude/skills/` (personal). Each is a directory with a
`SKILL.md` that holds the full knowledge — the same file the matching sub-agent
preloads. For example, `/code-critic` and the `code-critic` sub-agent both use
`.claude/skills/code-critic/SKILL.md` — see that file for the shape: a `name`,
a `description` the tool matches invocations against, and a body that is the
knowledge itself.

The five wired-up commands are `/feature`, `/plan-draft`, `/plan-critic`,
`/code-critic`, and `/adversarial-qa`. `/feature` is the primary entry point — it triggers
the full orchestrated workflow; the others invoke individual steps ad-hoc.

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

#### Skills vs sub-agents vs slash commands

Three concepts, two directories under `.claude/`:

- **Skills** (`.claude/skills/<name>/SKILL.md`) are the reusable knowledge —
  standards, checklists, rules, templates. No orchestration behavior.
- **Sub-agents** (`.claude/agents/<name>.md`) compose a skill with orchestration —
  what context to read, output format, file constraints, and the tools/model the
  agent runs with. They preload their skill via the `skills:` frontmatter field.
- **Slash commands** are just the skills invoked directly (`/plan-draft`,
  `/code-critic`, …), skipping the orchestration layer, for interactive ad-hoc
  use. `/feature` is the exception — its skill triggers the full orchestrated
  workflow.

The knowledge lives in one place (`.claude/skills/`). Sub-agents compose it with
workflow behavior; slash commands expose it directly. The workflow itself
(`.claude/skills/feature/SKILL.md`) is also a skill, so `AGENTS.md` references it
instead of duplicating the steps.

## Evolving the System

- **Start small.** Begin with the planner and code-critic; add QA and
  plan-critic once the basic workflow is stable.
- **Track failure patterns.** Every time an agent produces bad output your rules
  didn't catch, add a rule to the relevant skill in `.claude/skills/` (this is
  how the code-critic skill's Project-Specific Rules section grows).
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
  files in `.claude/` rather than pasting their contents — verbatim copies are
  what drift.
```
