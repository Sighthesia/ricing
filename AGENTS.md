Quickshell config repo with project-local Trellis/OpenCode workflow customizations.

## Skills

| Skill | When to use |
|---|---|
| [comment-before-declarations](.agents/skills/comment-before-declarations/SKILL.md) | When editing QML modules that should stay self-documenting and easy to scan. |
| [glass-liquid-design](.agents/skills/glass-liquid-design/SKILL.md) | When designing or modifying visible QML/Quickshell surfaces, motion, states, or interaction feedback. |
| [surface-owner-split-debugging](.agents/skills/surface-owner-split-debugging/SKILL.md) | When a visible UI surface has been moved or split from its prior owners and regressions appear in hover, editing, real content rendering, or content-driven sizing. |
| [visual-transition-rules](.agents/skills/visual-transition-rules/SKILL.md) | When adjusting QML visual styles, colors, radii, opacity, blur, shadows, spacing, scale, or related presentation variables. |

## Structure

- `shell.qml` is the real app entrypoint. Keep it as a thin composition root that instantiates top-level surfaces only.
- `modules/` holds feature UI. Current features are `background/` and `bar/`.
- `services/` holds shared shell state. If multiple QML modules need the same state, promote it into a singleton here instead of duplicating logic in views.
- `services/qmldir` is part of the contract: update it when adding a new singleton service meant to be imported from QML.
- `.trellis/` is the workflow source of truth: tasks, specs, runtime session state, and the local Python scripts that drive them.
- `.opencode/` contains the OpenCode integration layer: plugins, slash commands, and Trellis agent definitions. The only `package.json` in this repo is here for plugin dependencies, not app/runtime commands.

## Quickshell Conventions

- Follow `.trellis/spec/frontend/directory-structure.md` before changing shell structure.
- Shared state belongs in `services/`; renderers under `modules/` should stay read-only over that state when possible.
- `services/BarLayoutService.qml` is the current pattern for owning normalized state plus persistence via Quickshell IO.
- Multi-screen shell windows are created with `Variants { model: Quickshell.screens }`; see `modules/bar/BarWindow.qml`.

## Workflow Commands

- Resume the current Trellis task with `/trellis:continue` when available; the command maps to `python3 ./.trellis/scripts/get_context.py` plus phase routing.
- Inspect workflow/phase guidance directly with `python3 ./.trellis/scripts/get_context.py --mode phase` or `--mode phase --step <step>`.
- Task lifecycle lives in `python3 ./.trellis/scripts/task.py` (`create`, `start`, `current`, `finish`, `archive`, `add-context`, `validate`).
- Wrap up after Phase 3.4 with `/trellis:finish-work`; do not use it before code commits are done.

## OpenCode/Trellis Gotchas

- Active tasks are session-scoped, not repo-global. `task.py start/current/finish` rely on session identity from the platform hook or `TRELLIS_CONTEXT_ID`.
- OpenCode injects SessionStart context from `.opencode/plugins/session-start.js` and per-turn workflow breadcrumbs from `.opencode/plugins/inject-workflow-state.js`.
- Workflow-state text is sourced from tagged blocks in `.trellis/workflow.md`; if breadcrumbs look wrong, fix `workflow.md` rather than hardcoding plugin fallbacks.
- For OpenCode sub-agents, task/spec/research context is injected from the current task jsonl manifests. Validate them with `python3 ./.trellis/scripts/task.py validate <task-dir>` if context loading seems off.

## Verified Absences

- No root `README`, CI workflow, or root build/test manifest is currently present.
- Do not invent lint/test/build commands; verify them from repo files before documenting or running them.
