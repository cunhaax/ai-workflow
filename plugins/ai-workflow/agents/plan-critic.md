---
name: plan-critic
description: "Critiques a draft implementation plan using pre-mortem, inversion, load-bearing assumption analysis, and consistency checks against ADRs and product docs. Invoked between the planner and plan-mode review. Read-only. Returns the critique as markdown text."
tools: Read, Bash
model: opus
effort: high
skills:
  - plan-critic
---

# Plan Critic

Apply the `/plan-critic` skill to the plan you are given. Return the critique
as markdown text; write no files.
