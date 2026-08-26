# Project lenses — plan-critic

Project-specific extension of the `plan-critic` skill
(`plugins/ai-workflow/skills/plan-critic/SKILL.md`), for changes to this
repo itself — the AI workflow template.

## Lenses

When applying the four methods, give explicit attention to:

- **Blast radius of `templates/` changes.** Anything under
  `plugins/ai-workflow/skills/init-workflow/templates/` ripples into every
  downstream project that scaffolds from it — a plan touching this
  directory needs to consider what breaks for a project that already
  scaffolded, not just a fresh one.
- **Unverified packaging assumptions.** `plugin.json`/`marketplace.json`
  exist now, but the actual `/plugin marketplace add`/`/plugin install`
  flow has never been exercised end-to-end (it requires an interactive
  step only a human can drive). A plan should not assume that flow works
  as designed without flagging it as unverified until someone actually
  runs it.
- **Breaking changes to slash commands.** Renaming or removing a skill or
  sub-agent changes its slash-command name and breaks any project already
  using it. Flag compatibility impact explicitly.
- **Undocumented or version-gated harness behaviour.** A plan that depends
  on how Claude Code's harness behaves (sub-agent nesting, worktree
  isolation, `SendMessage`/resume semantics, permission-prompt propagation,
  and similar) must flag any such dependency as unverified and name the
  concrete smoke test that would confirm it, rather than asserting the
  behaviour as settled fact from documentation alone — this plugin's own
  multi-task `/feature` design rested on exactly this kind of assumption,
  and treating it as verified rather than flagged nearly shipped a design
  with real gaps.
