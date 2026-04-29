# Generalize module-specific skills

## Goal

Replace overly module-specific skill names and triggers with reusable pattern-based skills, while preserving the debugging lessons as portable methodology.

## Requirements

* Rename strongly specific skills to generic pattern-oriented names.
* Rewrite each renamed skill so the primary framing is generic, with the original module only as a case study.
* Keep skill content actionable and repo-usable.
* Update `AGENTS.md`, `CLAUDE.md`, and `.agents/skills/README.md` to the new names and descriptions.

## Acceptance Criteria

* [ ] No renamed skill in the main index is framed around a single historical module name when a broader pattern exists.
* [ ] Each rewritten skill leads with reusable concepts, traps, rules, and verification.
* [ ] Root skill indexes point only at the new generic paths.

## Out Of Scope

* Rewriting already-generic skills.
* Changing runtime code behavior.
