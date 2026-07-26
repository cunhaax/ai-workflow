# Project lenses — plan-critic

Project-specific extension of the AI Workflow plugin's `plan-critic` skill.
The skill reads this file on every
critique and gives the areas below explicit attention while applying its four
methods (pre-mortem, inversion, load-bearing assumptions, consistency). The
skill itself is project-agnostic and template-owned; **this file is owned by
the project** (the installer never overwrites it).

These are NOT a checklist; they direct extra attention. Write 4–7 concrete
lenses — the places where generic plans regularly miss issues that matter for
*this* product. Good lenses name a concrete failure surface and why it is
easy to get wrong, e.g.:

- "[Sensitive-data category] must never leak into [context]; any plan
  touching [visibility / export / analytics] needs explicit consent
  consideration."
- "[State machine X] visibility/permission rules across [viewer types];
  the state space is non-obvious."
- "[Abuse vector] on [flow]: spam, enumeration, scraping, harassment."

## Lenses

When applying the four methods, give explicit attention to:

- [TODO: high-risk area 1 — what to watch and why it's easy to miss]
- [TODO: high-risk area 2]
- [TODO: high-risk area 3]
