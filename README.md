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
quick-start for *adapting* the template to a new project.

## What's in here

```
AGENTS.md                    # Lean project guide (canonical; imported by CLAUDE.md)
CLAUDE.md                    # Thin: imports AGENTS.md via @AGENTS.md
.claude/
├── agents/                  # Sub-agent definitions (frontmatter + inline prompt)
│   ├── planner.md           # Orchestration + skills: [plan]
│   ├── plan-critic.md       # Orchestration + skills: [plan-critic]
│   ├── code-critic.md       # Orchestration + skills: [code-critic]
│   └── adversarial-qa.md    # Orchestration + skills: [adversarial-qa]  (+ Playwright)
└── skills/                  # The reusable knowledge, one directory per skill
    ├── feature/SKILL.md     # The full workflow (plan→critique→…→PR)
    ├── plan/SKILL.md
    ├── plan-critic/SKILL.md
    ├── code-critic/SKILL.md # Base standards + a Project-Specific Rules placeholder
                             #   (named code-critic to avoid shadowing Claude Code's
                             #   bundled code-review skill)
    └── adversarial-qa/SKILL.md
docs/
├── adr/                     # Architecture Decision Records (add your own)
├── product-context/         # Vision, strategy, requirements (add your own)
└── AI-workflow.md           # The full guide to this system
githooks/pre-push            # Review gate: blocks pushing unreviewed commits
scripts/review-ok.sh         # Records a passing review for the current HEAD
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

## Adapting it to your project — the placeholders

The template ships with the **reusable** content intact and every
**project-specific** decision left as a placeholder. Search the tree for `[` and
`TODO` and fill in:

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

Sections marked `<!-- ... -->` with a `[TODO: ...]` are where you write your own
project-specific content:

- **`.claude/skills/code-critic/SKILL.md` → "Project-Specific Rules"** — your
  repo's hard constraints (one bullet per rule, each with a severity). This is
  the section that grows over time as agents produce bad output your rules
  didn't catch. It includes the PRIVACY block (`[SENSITIVE_CATEGORIES]`,
  `[PUBLIC_SURFACES]`, `[IDENTIFIER_EXEMPTIONS]`, `[PRIVACY_TESTS]`) that
  anchors the base privacy rules to your codebase — for a project holding
  personal data, the most consequential placeholder in the template.
- **`.claude/skills/plan-critic/SKILL.md` → "Project-Specific Lenses"** — the
  areas where generic plans regularly miss issues that matter for *your* product.
- **`AGENTS.md`** — overview, commands, architecture, testing conventions, and
  the *Sensitive Areas* (security surface) list — the canonical list `/feature`
  consults for the critic-skip, model-escalation, and PR-flag decisions.
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

## Evolving the system

- **Start small.** Begin with the planner and code-critic; add QA and
  plan-critic once the basic loop is stable.
- **Track failure patterns.** Every time an agent produces bad output your rules
  didn't catch, add a rule to the relevant skill in `.claude/skills/`.
- **Prefer build-enforced rules over prose.** When a review rule is mechanically
  checkable, encode it as an architecture/fitness test — tests don't drift and
  the human never re-verifies them by hand.
- **Keep `AGENTS.md` lean.** Detailed standards and steps belong in the skills.
