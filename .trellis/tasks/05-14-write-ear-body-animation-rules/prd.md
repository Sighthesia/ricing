# Write unified ear-body animation rules into skill

## Goal

Document the dockzone ear/body unified animation rules in project skills, while also extracting project-wide visual transition rules into a separate must-read styling skill.

## Confirmed Facts

- `.agents/skills/glass-liquid-design/SKILL.md` already owns the project's dockzone, attached-surface, and motion-language guidance.
- The new ear/body rules belong there because they are specific to dockzone surfaces and their animation semantics.
- The user also wants broader, reusable transition rules such as "every perceptible color variable change must transition" to live in a separate skill rather than being buried inside the dockzone-specific skill.
- This repo currently has very few project-local skills, so adding a dedicated styling-transition skill keeps concerns clearer than overloading `glass-liquid-design`.
- The repo has no root `CLAUDE.md`, and `AGENTS.md` does not currently maintain a detailed local-skill index table, so the primary documentation surface is the skill files themselves.

## Requirements

- Update `glass-liquid-design` with strong project-level rules about ear/body animation unity.
- Create a separate project-local skill for general visual transition rules that must be read when adjusting styles.
- Keep the two skills clearly separated:
  - dockzone / ear / surface ownership rules in `glass-liquid-design`
  - global transition hygiene rules in the new styling skill
- Make both rule sets actionable and specific enough for future implementation work.

## Acceptance Criteria

- [ ] `glass-liquid-design` explicitly states that ear is subordinate geometry of the body and must inherit the body's global motion.
- [ ] `glass-liquid-design` explains when ear may apply local exit/morph transitions without breaking overall object continuity.
- [ ] A new project-local skill exists for style-adjustment transition rules.
- [ ] The new style-transition skill explicitly requires transitions for perceptible style variable changes such as color, radius, opacity, blur, shadow, spacing, and scale.
- [ ] The split between domain-specific motion rules and project-wide styling rules is clear.

## Out of Scope

- Implementing the dockzone refactor itself.
- Rewriting unrelated AI documentation files unless required to make the new skill discoverable.

## Decision

- Accepted scope: use two skills, not one overloaded skill.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
