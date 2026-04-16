# DymicShell Agent Guide

Wayland shell built with Quickshell. Prefer small, layered changes that stay safe under hot reload.

## Commands

- Use `qs`, not `quickshell`, unless the user explicitly asks otherwise.
- Full-shell validation: `timeout 5 qs --path .`
- There is no verified repo-local `npm`, `pnpm`, `yarn`, `make`, `just`, `pytest`, `qmllint`, `qmlformat`, or CI command. Do not invent them.

## Structure

- `shell.qml` is the entry point; keep it to top-level window instantiation only.
- `services/` owns persistence, external processes, compositor integration, and shared cross-window state.
- `config/Theme.qml` and `config/Colors.qml` are derived tokens; UI should consume these instead of hardcoding sizes, timing, or colors.
- `modules/` renders UI and forwards behavior back into services.
- `modules/bar/BarContent.qml` is the bar composition root.
- `services/BarLayoutService.qml` is a facade; most bar layout logic lives in `services/barlayout/*.js`.

## QML Style

- For QML element declarations, add a short English comment immediately before each element that explains its name, effect, or role.
- Keep these comments concise and avoid repeating obvious property names or implementation details.

## State And Generated Outputs

- User settings live in `~/.config/dymicshell/settings.json`; defaults live in `config/settings-default.json`.
- When adding or renaming a setting, update both `config/settings-default.json` and `services/SettingsService.qml`.
- Dynamic theming is owned by `services/WallpaperService.qml` and the repo-local `matugen/config.toml`, not the user's global `matugen` config.
- Matugen writes shell colors to `~/.local/state/quickshell/user/generated/colors.json`; `config/Colors.qml` watches that file.
- Keep repo runtime artifacts in `.cache/DymicShell/`; do not introduce new writes under `null/dymicshell/`.

## Workflow Notes

- Do not remove `docs/plans/` references when files or commands move.
- Do not proactively use ad-hoc smoke or harness runners; the verified validation path is the full-shell `qs --path .` load check.

## Skills

Load these for detailed context on specific topics. See `.agents/skills/README.md` for grouped navigation.

### Architecture

| Skill                                                        | When to use                                                                                                            |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| [qml-architecture](.agents/skills/qml-architecture/SKILL.md) | Use when working on QML architecture, file structure, naming conventions, imports, or module layout.                   |
| [qml-state](.agents/skills/qml-state/SKILL.md)               | Use when modifying settings, shared state, persistence, error handling, logging, or service-driven component behavior. |

### Visual System

| Skill                                                              | When to use                                                                                                                                                                                      |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [attached-expansion-geometry](.agents/skills/attached-expansion-geometry/SKILL.md) | Use when modifying SuperIsland or media attached panel bridge geometry, especially if the bridge-to-panel corner looks bulged, notched, or overly wide.                                         |
| [qml-components](.agents/skills/qml-components/SKILL.md)           | Use when building UI elements with DymicShell tokens, semantic colors, theme values, base components, or interactive surface patterns.                                                           |
| [qml-context-menu](.agents/skills/qml-context-menu/SKILL.md)       | Use when creating, refactoring, or visually aligning bar-style context menus, tray menus, and submenus.                                                                                          |
| [qml-token-cleanup](.agents/skills/qml-token-cleanup/SKILL.md)     | Use when consolidating visual tokens, extracting repeated QML geometry into `Theme*` singletons, or cleaning hardcoded spacing, radius, widths, and panel dimensions across related UI families. |
| [qml-visual-language](.agents/skills/qml-visual-language/SKILL.md) | Use when defining or enforcing visual identity, motion language, and cross-component consistency.                                                                                                |

### Motion

| Skill                                                                        | When to use                                                                                                                                                                               |
| ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [qml-indicator-motion](.agents/skills/qml-indicator-motion/SKILL.md)         | Use when building or debugging moving active indicators, sliding highlights, or stretch-then-settle pills behind workspace tabs, icon rows, or segmented controls.                        |
| [qml-motion-debug](.agents/skills/qml-motion-debug/SKILL.md)                 | Use when debugging Quickshell or QML motion bugs where state updates occur but the visual transition looks static, too subtle, or wrong.                                                  |
| [list-transition-handoffs](.agents/skills/list-transition-handoffs/SKILL.md) | Use when modifying animated list filtering or replacement transitions that mix live delegates with detached layers, especially when rapid updates cause blank frames, overlap, or ghosts. |

### Performance

| Skill                                                                  | When to use                                                                                                                         |
| ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| [qml-performance-debug](.agents/skills/qml-performance-debug/SKILL.md) | Use when debugging DymicShell or Quickshell jank, frame drops, layout thrash, layer-shell resize churn, or slow widget transitions. |

### Workflow

| Skill                                                                  | When to use                                                                                                                                  |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| [reference-attribution](.agents/skills/reference-attribution/SKILL.md) | Use when adapting code, templates, config patterns, or architecture from another repository and attribution must be documented consistently. |

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
