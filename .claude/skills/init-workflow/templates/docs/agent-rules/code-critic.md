# Project rules — code-critic

Project-specific extension of the `code-critic` skill
(`.claude/skills/code-critic/SKILL.md`). The skill reads this file on every
review — ad-hoc and in the `/feature` workflow — and applies each rule at the
severity it states, alongside its base standards. The skill itself is
project-agnostic and template-owned; **this file is owned by the project**
(the installer never overwrites it), and it is the file that accretes over
time: every time an agent produces bad output the base standards didn't
catch, add a rule here — or, better, encode it as a build-enforced test.

Guidance for good rules:

- One bullet per rule, each stating the rule AND its severity
  (`FAIL` / `NEEDS_DECISION`). Add subsections (Persistence, Security,
  Privacy, View Layer, …) as the list grows.
- Name the exact symbol/file/pattern, so the reviewer can grep for it.
- State the failure mode, not just the prohibition ("otherwise X is
  silently wrong").
- Scope to production code vs test code if the two differ.
- Say whether the rule is diff-scoped or repo-wide.

**Build-enforced rules.** When a rule is mechanically checkable, prefer
encoding it as an architecture/fitness test over prose here — tests don't
drift and the human never re-verifies them. For any rule that IS backed by a
test, the reviewer's job is only to check the diff does not WEAKEN the
enforcement (deleting/disabling the test, adding an unexplained exemption, or
restructuring code out of the test's scan scope) — a weakened enforcement is
`FAIL`. List which rules are build-enforced so the reviewer doesn't re-derive
them by hand.

## Rules

- [TODO: your rule 1 — the constraint, the symbol/file it applies to, and its severity]
- [TODO: your rule 2]

## Privacy anchors

The skill's base privacy rules (deletion by design, public-surface whitelist,
no personal data in logs/URLs) are generic; these anchors bind them to this
codebase. Fill per project:

- **Sensitive categories**: [TODO: which data categories are sensitive here
  (e.g. GDPR Art. 9: political views, religious views, orientation) and the
  doc that defines them ([COMPLIANCE_DOC path])]
- **Public surfaces**: [TODO: which views/endpoints are public/unauthenticated
  (name the controller/view the whitelist test covers)]
- **Identifier exemptions**: [TODO: identifiers that are public by design and
  exempt from the log/URL rules (e.g. public usernames)]
- **Privacy tests**: [TODO: which of the three privacy fitness tests exist,
  and where — so the reviewer knows which invariants are build-enforced and
  which still need the by-hand check]

## Checklist

One checklist item per rule in the *Rules* section above — keep the two in
sync. The reviewer evaluates these as part of the skill's Review Checklist.
Tag items "(if applicable)" when they only apply to certain diffs.

- [ ] [TODO: checklist item mirroring rule 1]
- [ ] [TODO: checklist item mirroring rule 2]
