# DymicShell Agent Guide

Wayland shell built with Quickshell. Keep the repo layered, token-driven, and safe for hot-reload.

## Repository Layout
```text
shell.qml                  # Entry point; instantiate top-level windows only
config/                    # Semantic colors + structural theme tokens
services/                  # Singleton state, persistence, compositor/process integration
modules/                   # UI windows, panels, and reusable module-local components
docs/plans/                # Design and implementation history
.cache/DymicShell/         # Runtime artifacts and transient shell data; not checked in
```
Key entry points: `shell.qml`, `config/Theme.qml`, `config/Colors.qml`, `services/SettingsService.qml`, `services/BarLayoutService.qml`, `modules/bar/BarContent.qml`.

## Build and Validation

Use `qs` unless the user explicitly asks for `quickshell`.

### Whole-Shell Validation
```bash
timeout 5 qs --path .
```
Prefer `qs --path .` for a full-shell load check.

## Skills

Load these for detailed context on specific topics. See `.agents/skills/README.md` for grouped navigation.

### Architecture

| Skill                                                        | When to use                                                                        |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| [qml-architecture](.agents/skills/qml-architecture/SKILL.md) | Use when working on QML architecture, file structure, naming conventions, imports, or module layout. |
| [qml-state](.agents/skills/qml-state/SKILL.md)               | Use when modifying settings, shared state, persistence, error handling, logging, or service-driven component behavior. |

### Visual System

| Skill                                                        | When to use                                                                        |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| [qml-components](.agents/skills/qml-components/SKILL.md)     | Use when building UI elements with DymicShell tokens, semantic colors, theme values, base components, or interactive surface patterns. |
| [qml-context-menu](.agents/skills/qml-context-menu/SKILL.md) | Use when creating, refactoring, or visually aligning bar-style context menus, tray menus, and submenus. |
| [qml-visual-language](.agents/skills/qml-visual-language/SKILL.md) | Use when defining or enforcing visual identity, motion language, and cross-component consistency. |

### Motion

| Skill                                                        | When to use                                                                        |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| [qml-indicator-motion](.agents/skills/qml-indicator-motion/SKILL.md) | Use when building or debugging moving active indicators, sliding highlights, or stretch-then-settle pills behind workspace tabs, icon rows, or segmented controls. |
| [qml-motion-debug](.agents/skills/qml-motion-debug/SKILL.md) | Use when debugging Quickshell or QML motion bugs where state updates occur but the visual transition looks static, too subtle, or wrong. |

### Performance

| Skill                                                        | When to use                                                                        |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| [qml-performance-debug](.agents/skills/qml-performance-debug/SKILL.md) | Use when debugging DymicShell or Quickshell jank, frame drops, layout thrash, layer-shell resize churn, or slow widget transitions. |

### Workflow

| Skill                                                        | When to use                                                                        |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| [reference-attribution](.agents/skills/reference-attribution/SKILL.md) | Use when adapting code, templates, config patterns, or architecture from another repository and attribution must be documented consistently. |

## Miscellaneous
- The repo does not define `npm`, `pnpm`, `yarn`, `make`, `just`, `pytest`, `qmllint`, `qmlformat`, or CI workflow commands. Do not invent those commands unless you verify local availability.
- Do not proactively use harness, smoke, or other targeted test runners; keep validation to the whole-shell load check unless the user explicitly asks for a different approach.
- Don't remove `docs/plans/` references even when files or commands move.
- Keep runtime artifacts in `.cache/DymicShell/`; do not write new files under `null/dymicshell/`.
<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

Use the `/trellis:start` command when starting a new session to:
- Initialize your developer identity
- Understand current project context
- Read relevant guidelines

Use `@/.trellis/` to learn:
- Development workflow (`workflow.md`)
- Project structure guidelines (`spec/`)
- Developer workspace (`workspace/`)

Keep this managed block so 'trellis update' can refresh the instructions.

<!-- TRELLIS:END -->
