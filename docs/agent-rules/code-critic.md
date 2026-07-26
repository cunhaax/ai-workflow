# Project rules — code-critic

Project-specific extension of the `code-critic` skill
(`plugins/ai-workflow/skills/code-critic/SKILL.md`), for changes to this
repo itself — the AI workflow template.

## Rules

- A file added, removed, or renamed under
  `plugins/ai-workflow/skills/init-workflow/templates/` must be reflected
  in all three places that enumerate it: the file tree in
  `docs/AI-workflow.md`, its `.template` → destination mapping paragraph
  immediately below the tree, and the `init-workflow/templates/`
  enumeration paragraph in `README.md` (not its collapsed file-tree
  diagram, which doesn't expand `templates/`). `FAIL` if any of the three
  goes stale.
- `.claude/settings.json`, `githooks/pre-push`, `scripts/review-ok.sh`, and
  `scripts/check-hook-status.sh` at repo root must remain symlinks into
  `plugins/ai-workflow/skills/init-workflow/templates/`. Replacing any of
  them with a regular file (even with identical content) reintroduces the
  duplication this repo deliberately avoided. `FAIL` if a diff turns any of
  them into a non-symlink.
- `.claude/skills/` and `.claude/agents/` must not be reintroduced at
  repo root, in any form — not real content, not symlinks. That was tried
  and rejected: it collides with the plugin also being installed globally
  (two command surfaces for the same thing). `FAIL` if a diff adds either
  directory back.
- Skill and sub-agent files under `plugins/ai-workflow/skills/` and
  `plugins/ai-workflow/agents/` (excluding `init-workflow/templates/`) must
  stay project-agnostic — no project-specific content, commands, or
  examples baked in. `FAIL` if a diff adds project-specific text outside
  `templates/` or `docs/agent-rules/`.

## Privacy anchors

Not applicable — this repo holds no personal or user data. It is a
documentation/skills/scripts repo with no application, database, or user
surface of its own.

## Checklist

- [ ] Any file added/removed/renamed under `templates/` is reflected in
      `docs/AI-workflow.md`'s file tree, its `.template` → destination
      mapping paragraph, and README.md's `init-workflow/templates/`
      enumeration paragraph.
- [ ] `.claude/settings.json`, `githooks/pre-push`, `scripts/review-ok.sh`,
      and `scripts/check-hook-status.sh` at root are still symlinks into
      `templates/`, not regular files.
- [ ] `.claude/skills/` and `.claude/agents/` are still absent at repo root.
- [ ] No project-specific content leaked into a project-agnostic skill or
      sub-agent file outside `templates/`/`docs/agent-rules/`.
