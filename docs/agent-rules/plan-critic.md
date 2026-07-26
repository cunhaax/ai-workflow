# Project lenses — plan-critic

Project-specific extension of the `plan-critic` skill
(`.claude/skills/plan-critic/SKILL.md`), for changes to this repo itself —
the AI workflow template.

## Lenses

When applying the four methods, give explicit attention to:

- **Blast radius of `templates/` changes.** Anything under
  `.claude/skills/init-workflow/templates/` ripples into every downstream
  project that scaffolds from it — a plan touching this directory needs to
  consider what breaks for a project that already scaffolded, not just a
  fresh one.
- **Unverified packaging assumptions.** The plugin's actual packaging
  (`plugin.json`/`marketplace.json`) doesn't exist yet. A plan should not
  assume packaging-specific behavior (e.g. how symlinks or nested
  directories survive publishing) without flagging that assumption
  explicitly — it's unverified.
- **Breaking changes to slash commands.** Renaming or removing a skill or
  sub-agent changes its slash-command name and breaks any project already
  using it. Flag compatibility impact explicitly.
