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
plan critic, developer, code reviewer, and QA.

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
│   ├── agents/                            # Sub-agent definitions (frontmatter + inline prompt)
│   │   ├── planner.md                     # Orchestration + skills: [plan]
│   │   ├── plan-critic.md                 # Orchestration + skills: [plan-critic]
│   │   ├── code-reviewer.md               # Orchestration + skills: [code-review]
│   │   └── adversarial-qa.md              # Orchestration + skills: [adversarial-qa]  (+ Playwright tools)
│   └── skills/                            # Reusable knowledge, one directory per skill
│       ├── feature/SKILL.md               # Full workflow (plan → critique → implement → review → QA)
│       ├── plan/SKILL.md
│       ├── plan-critic/SKILL.md
│       ├── code-review/SKILL.md           # Base standards + a Project-Specific Rules section
│       └── adversarial-qa/SKILL.md
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
> the planner, plan-critic, code-reviewer, and adversarial-qa sub-agents.

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
  the `## Project-Specific Rules` section inside `.claude/skills/code-review/SKILL.md`).
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

### `.claude/skills/plan/SKILL.md` — `/plan`

Produces a structured implementation plan before any code is written: gather
context (external specs, module `AGENTS.md` files, ADRs, product docs), reproduce
the **complete** requirements verbatim (the plan's Requirements section is the
spec other agents validate against), enumerate every edge case, and propose a
test strategy. Key convention: **tests are the plan's deterministic oracle** —
every claim the plan makes about user-visible behavior must map to a committed
end-to-end test, and the plan must **not** contain a separate "manual
verification / QA checklist" (convert any "try X and confirm Y" into a committed
test assertion). Ambiguities are flagged as `NEEDS_DECISION` in the plan, never
asked directly from inside a sub-agent. Output is plan text only — no files, no
code. See `.claude/skills/plan/SKILL.md` for the rules and the plan template.

### `.claude/skills/plan-critic/SKILL.md` — `/plan-critic`

Attacks a **draft plan** before it becomes commitment — load-bearing logic:
if the plan is wrong, downstream review and QA mostly verify that the wrong thing
was built correctly. Applies four methods, each of which must produce findings or
an explicit "no concerns, because…": (1) **pre-mortem**, (2) **inversion**,
(3) **load-bearing assumptions**, (4) **consistency** with ADRs and product
intent. A **Project-Specific Lenses** section (fill it in per product) directs
extra attention to the areas where generic plans regularly miss issues that
matter. It critiques the plan's substance, not its writing or formatting, and
does **not** rewrite the plan — concrete suggestions go in a "Suggested Plan
Amendments" section; the developer decides what to adopt. See
`.claude/skills/plan-critic/SKILL.md` for the methods and output format.

### `.claude/skills/code-review/SKILL.md` — `/code-review`

Reviews a diff against project standards from an adversarial stance (assume
something is wrong; guard against confirmation bias; if you find nothing after
genuine effort, that is itself a finding to state). Notable points:

- **It owns test completeness**, not just test quality. Because `/adversarial-qa` is
  exploratory (below), code-review verifies that committed tests cover every
  Requirement and Edge Case in the plan **and** the branches/boundaries/inputs
  the plan did not enumerate (critical-analysis pass).
- Verdicts are `PASS`, `PASS (N/A)`, `FAIL`, `NEEDS_DECISION`, plus an
  **Open Question** category for risks that cannot be confirmed from source alone
  (runtime config, prod data shape, deployment topology).
- It reads beyond the diff (surrounding code, tests, migrations) and reports
  which **ADRs** it read (or "none relevant" with a reason).
- A `## Project-Specific Rules` section inlines the repo's hard constraints
  (fill it in per project). Violations carry the same severity as the base
  standards. Any mechanically checkable subset should be build-enforced (see
  *Deterministic enforcement* below); for those the reviewer only checks that the
  diff doesn't weaken the enforcement.

See `.claude/skills/code-review/SKILL.md` for the full checklist and output format.

## Deterministic enforcement — below the LLM layer

Instructions alone drift; three mechanisms enforce the load-bearing gates
mechanically, so neither the agents nor the human re-verify them by hand:

- **Architecture / fitness tests** encode the mechanically checkable review
  rules as build failures (layer direction, banned APIs, required
  registrations/annotations, reserved route segments, and so on). The
  code-review skill tells the reviewer to verify only that a diff doesn't
  *weaken* these tests, not to re-derive the rules. Start with the layer rule
  (*Your first fitness test*, below). <!-- [TODO: add fitness tests for your
  stack and list them in the code-review skill's Project-Specific Rules
  section.] -->
- **The pre-push review gate** (`githooks/pre-push`, enabled once per clone
  via `git config core.hooksPath githooks`): after a code-reviewer pass with
  no FAIL items, the agent records the reviewed HEAD with `scripts/review-ok.sh`;
  the hook refuses to push any other commit, so post-review changes force a
  re-review. Human bypass: `git push --no-verify`.
- **CI** (e.g. a `.github/workflows/ci.yml` that runs `[CHECK_CMD]` on every
  push and PR) — independent evidence for the human reviewer that tests pass,
  replacing trust in a session transcript. <!-- [TODO: add a CI workflow for
  your platform.] -->

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
`code-review` skill (its *Architecture* checklist) to "verify the diff doesn't
*weaken* the layer test" rather than re-deriving boundaries by hand. Add further
fitness tests the same way — one per mechanically checkable rule.

### `.claude/skills/adversarial-qa/SKILL.md` — `/adversarial-qa`

**Exploratory and adversarial — not a re-verification of the spec.** Committed
end-to-end tests encode the plan's Requirements deterministically (and
code-review checks their completeness); `/adversarial-qa`'s job is to go **beyond** them.
It drives the feature in the **running app** via the Playwright MCP, probes past
the happy path (narrow viewports, keyboard-only nav, browser back button,
multi-tab forms, weird/long/XSS paste, mid-edit reloads, stale state after a
failed submit), and surfaces anything that looks wrong — even outside the
feature's plan — rather than working around it. Before reporting, it checks
open `known-issue` GitHub issues and lists matches as known/deferred instead
of re-triaging them. If the server won't start or Playwright is unavailable it
STOPs and reports the blocker (no curl/SQL substitutes). Findings cite
evidence saved under `.qa-evidence/`. See `.claude/skills/adversarial-qa/SKILL.md` for the
probe list and output format.

### `.claude/skills/feature/SKILL.md` — `/feature`

The full lifecycle the **main** agent runs for non-trivial work:
**plan → critique → implement → test → code-review → QA → PR**, with explicit
gates. Highlights of the definition:

1. **Enter plan mode first** (a structural gate — edit tools are blocked until
   approval), then delegate to the `planner` sub-agent (passing the user's prompt
   verbatim; the planner fetches any external specs).
2. **Critique** via the `plan-critic` sub-agent. Skip **only** if the change is
   trivial under **all** criteria (≲50 lines non-test; touches none of the
   project's sensitive areas; no new endpoints/persisted fields/dependencies)
   **and the user explicitly said "skip the critic"**. Do not infer "trivial"
   yourself — the user has to ask.
3. **Present plan and critique together** for approval; exit plan mode only after
   approval. Re-plan → re-critique → re-present on changes, leading with a delta
   against the previous version; fold amendments the user accepts into the plan
   text itself.
4. **Implement**, running tests once a coherent unit is complete. Material scope
   changes send you back into plan mode.
5. **Code review** via the `code-reviewer` sub-agent (pass the approved plan and
   the latest test output). Relay all `NEEDS_DECISION` items to the user; fix
   `FAIL` items and re-run. **Do not push or open a PR until the reviewer passes
   with no FAIL items** — after a pass, record it with `scripts/review-ok.sh`
   (the pre-push hook enforces it); re-run the reviewer after any later change,
   including QA-driven fixes. For a diff that touches the security surface,
   escalate the reviewer's model to `opus` (the stronger bug-finder) for that
   review.
6. **Exploratory QA** via the `adversarial-qa` sub-agent — only for changes with a UI
   surface (templates/views, static assets, view/fragment-rendering
   controllers); otherwise state that QA was skipped and why. Relay findings and
   wait for direction; deferred findings become `known-issue` GitHub issues.
7. **Open the PR** only after the code review passes and every QA finding is
   dispositioned (or QA was skipped, no UI surface). The PR body carries the
   pipeline's conclusions — plan summary, review outcome with decisions, QA
   dispositions, test evidence — and flags security-surface changes with a
   recommendation for a second, independent `code-reviewer` pass before merging.

See `.claude/skills/feature/SKILL.md` for the authoritative step list and rules.

## Sub-agents — orchestration over the skills

Each `.claude/agents/<name>.md` file is a Claude Code sub-agent definition: YAML
frontmatter (metadata + tools/model/effort/permission + the `skills:` to
preload) followed by the body, which **is** the sub-agent's system prompt. The
body is written for the **autonomous** case (a sub-agent), which also makes it
usable as an interactive main agent (`claude --agent <name>`).

- **`planner`** — senior architect. Reads the prompt, linked docs, module
  `AGENTS.md` files, ADRs, and product docs; applies the preloaded `plan` skill;
  returns plan text only (no files, no code).
- **`plan-critic`** — adversarial plan reviewer. Reads the plan text, relevant
  ADRs, product docs in `docs/product-context/`, and touched-module `AGENTS.md`
  files; applies the preloaded `plan-critic` skill; surfaces concerns without
  rewriting the plan.
- **`code-reviewer`** — strict reviewer. Bash for **read-only** inspection only
  (`git diff`, `git log`, dependency/version checks); never runs the test suite
  or mutates files; applies the preloaded `code-review` skill; outputs the review
  only.
- **`adversarial-qa`** — QA engineer. Not a code-quality review; applies the preloaded `adversarial-qa`
  skill to drive the running app and surface what the plan and tests missed.

The frontmatter each sub-agent carries:

| Sub-agent        | tools                          | model  | effort | permissionMode | skills        |
|------------------|--------------------------------|--------|--------|----------------|---------------|
| `planner`        | Read, Bash, WebFetch           | opus   | high   | plan           | plan          |
| `plan-critic`    | Read, Bash                     | opus   | high   | plan           | plan-critic   |
| `code-reviewer`  | Read, Bash                     | sonnet | high   | —              | code-review   |
| `adversarial-qa` | Read, Bash, Playwright MCP set | sonnet | medium | —              | adversarial-qa |

The `planner` and `plan-critic` carry `permissionMode: plan` so they stay
read-only; the `planner` also carries `WebFetch` so it — and only it — can pull
the external specs a prompt links to; the `adversarial-qa` sub-agent lists the Playwright
`browser_*` MCP tools so it can drive the app. Each lists exactly the one skill
it applies, so that skill's full body is preloaded at startup. Example —
`.claude/agents/code-reviewer.md`:

```markdown
---
name: code-reviewer
description: "Reviews code changes against project standards after implementation is complete. MUST be invoked before presenting any work to the user. Produces a structured review with PASS/FAIL/NEEDS_DECISION per item."
tools: Read, Bash
model: sonnet
effort: high
skills:
  - code-review
---

# Code Reviewer Agent

You are a strict code reviewer for a production system.

You may use Bash for read-only inspection only … Apply the `/code-review` skill
to review the changes. Output only the review.
```

The `skills: [code-review]` line preloads the full `/code-review` checklist and
standards into the sub-agent's context at startup, so the body only needs the
orchestration.

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
6. **Code-reviewer sub-agent** (isolated) → reads its standards, checklist,
   project-specific rules, and the approved plan → returns a structured review,
   including verification that committed tests cover the spec and beyond.
7. `NEEDS_DECISION` / `Open Question` items → main agent relays them to you → you
   decide → main agent applies fixes and re-runs the reviewer until no `FAIL`
   remains.
8. **QA sub-agent** (isolated) → drives the running app in a browser via
   Playwright, probing **beyond** the plan and committed tests for anything that
   looks wrong → returns findings with evidence. (It does not re-check the
   Requirements — that is locked down by the committed tests and code-review.)
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
    Reviewer[[code-reviewer]]
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
claude --agent code-reviewer
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
preloads. For example, `/code-review` and the `code-reviewer` sub-agent both use
`.claude/skills/code-review/SKILL.md`:

```markdown
---
name: code-review
description: >
  Code review checklist, coding standards, and this repo's inlined
  project-specific rules. Invoked as /code-review for an ad-hoc review, or
  preloaded by the code-reviewer sub-agent in the /feature workflow.
---

# /code-review — Code Review

Apply this skill to review code changes against project standards.
… (full checklist, standards, and Project-Specific Rules) …
```

The five wired-up commands are `/feature`, `/plan`, `/plan-critic`,
`/code-review`, and `/adversarial-qa`. `/feature` is the primary entry point — it triggers
the full orchestrated workflow; the others invoke individual steps ad-hoc.

**Naming note (Claude Code).** `/code-review` is also a skill Claude Code
**bundles by default**. A project skill of the same name intentionally
*overrides* the bundled one — project skills shadow bundled skills completely and
by design ([Skills docs](https://code.claude.com/docs/en/skills) use
`code-review` as their own example) — so `/code-review` here always resolves to
this repo's checklist, and the `code-reviewer` sub-agent's `skills: [code-review]`
preload uses the same repo copy. One consequence: `ultra` is the bundled skill's
cloud-review argument, and it is shadowed too, so **`/code-review ultra` does not
launch a cloud review in a project using this template** — use `/ultrareview`
instead, the alias Claude Code still ships (upstream now prefers
`/code-review ultra`, which is shadowed here), for that occasional, billed deep
pass. If you rename the skill or don't use Claude Code, this note doesn't apply.
Also note `/plan` shares a name with Claude Code's built-in *plan-mode* command
(a separate mechanism from skills), so if you invoke `/plan` ad-hoc, confirm your
build runs this repo's planning skill.

#### Skills vs sub-agents vs slash commands

Three concepts, two directories under `.claude/`:

- **Skills** (`.claude/skills/<name>/SKILL.md`) are the reusable knowledge —
  standards, checklists, rules, templates. No orchestration behavior.
- **Sub-agents** (`.claude/agents/<name>.md`) compose a skill with orchestration —
  what context to read, output format, file constraints, and the tools/model the
  agent runs with. They preload their skill via the `skills:` frontmatter field.
- **Slash commands** are just the skills invoked directly (`/plan`,
  `/code-review`, …), skipping the orchestration layer, for interactive ad-hoc
  use. `/feature` is the exception — its skill triggers the full orchestrated
  workflow.

The knowledge lives in one place (`.claude/skills/`). Sub-agents compose it with
workflow behavior; slash commands expose it directly. The workflow itself
(`.claude/skills/feature/SKILL.md`) is also a skill, so `AGENTS.md` references it
instead of duplicating the steps.

## Evolving the System

- **Start small.** Begin with the planner and code-reviewer; add QA and
  plan-critic once the basic workflow is stable.
- **Track failure patterns.** Every time an agent produces bad output your rules
  didn't catch, add a rule to the relevant skill in `.claude/skills/` (this is
  how the code-review skill's Project-Specific Rules section grows).
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
