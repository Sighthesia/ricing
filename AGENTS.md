# DymicShell Agent Guide

Wayland shell built with Quickshell. Keep the repo layered, token-driven, and safe for hot-reload.

## Repository Layout
```text
shell.qml                  # Entry point; instantiate top-level windows only
config/                    # Semantic colors + structural theme tokens
services/                  # Singleton state, persistence, compositor/process integration
modules/                   # UI windows, panels, and reusable module-local components
  tests/
docs/plans/               # Design and implementation history
null/dymicshell/          # Checked-in sample/runtime artifacts; not the canonical live config
```
Key entry points: `shell.qml`, `config/Theme.qml`, `config/Colors.qml`, `services/SettingsService.qml`, `services/BarLayoutService.qml`, `modules/bar/BarContent.qml`.

## Build, Lint, and Test Commands

Use `qs` unless the user explicitly asks for `quickshell`.

### Whole-Shell Validation
```bash
timeout 5 qs --path .
timeout 5 qs -p .
```
Prefer `qs --path .` for a full-shell load check.

## Skills

Load these for detailed context on specific topics:

| Skill                                                        | When to use                                                                                     |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| [qml-architecture](skills/qml-architecture/SKILL.md)         | QML architecture rules, file structure, naming conventions, and imports.                        |
| [qml-components](skills/qml-components/SKILL.md)             | Token system, semantic colors, theme values, base components, and interactive surface patterns. |
| [qml-state](skills/qml-state/SKILL.md)                       | Guidelines for managing settings, state, persistence, and error handling.                       |
| [qml-testing-strategy](skills/qml-testing-strategy/SKILL.md) | QML bug fixes, behavioral testing, regressions, or behavior modifications.                      |

## Miscellaneous
- The repo does not define `npm`, `pnpm`, `yarn`, `make`, `just`, `pytest`, `qmllint`, `qmlformat`, or CI workflow commands. Do not invent those commands unless you verify local availability.
- Don't remove `docs/plans/` references even when files or commands move.
