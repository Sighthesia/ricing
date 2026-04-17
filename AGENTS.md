# DymicShell Agent Guide

**DymicShell** is a Quickshell-based Wayland shell.

## Commands

- Run the shell with `qs`.
- Full-shell validation: `timeout 5 qs --path .`
- No repo-local `npm`, `pnpm`, `yarn`, `make`, `just`, `pytest`, `qmllint`, or `qmlformat` command is verified here; do not invent one.

## Structure

- `shell.qml` is the boot entrypoint; keep it to top-level window wiring.
- `modules/` renders UI; `services/` owns shared state, persistence, compositor/process integration, and layout logic.
- `modules/bar/BarContent.qml` is the bar composition root.
- `services/BarLayoutService.qml` is the bar-layout facade; most layout logic lives in `services/barlayout/*.js`.
- `config/Theme.qml`, `config/Colors.qml`, and `config/settings-default.json` are derived/shared inputs; prefer them over hardcoded sizes, colors, and defaults.
- `matugen/config.toml` and `services/WallpaperService.qml` own wallpaper-driven theming.
- `scripts/tampermonkey/netease-web-lyrics.user.js` is the persistent NetEase lyrics path; `scripts/firefox-extensions/netease-web-lyrics/README.md` documents the temporary Firefox fallback.

## Workflow

- Keep runtime writes under `.cache/DymicShell/`.
- When adding or renaming a setting, update both `config/settings-default.json` and `services/SettingsService.qml`.
- `config/Colors.qml` watches `~/.local/state/quickshell/user/generated/colors.json`.
- Prefer the repo-owned matugen config over the user’s global matugen setup.

## QML

- Add a short English comment immediately before each QML element declaration.

## Skills

Load skills on demand; see `.agents/skills/README.md` for grouping.

| Skill                                                                                | When to use                                               |
| ------------------------------------------------------------------------------------ | --------------------------------------------------------- |
| [qml-architecture](.agents/skills/qml-architecture/SKILL.md)                         | QML file layout, imports, and module boundaries           |
| [qml-state](.agents/skills/qml-state/SKILL.md)                                       | Settings, persistence, shared state, and service behavior |
| [qml-components](.agents/skills/qml-components/SKILL.md)                             | Tokens, semantic colors, and base surface patterns        |
| [qml-context-menu](.agents/skills/qml-context-menu/SKILL.md)                         | Bar, tray, and submenu menus                              |
| [qml-token-cleanup](.agents/skills/qml-token-cleanup/SKILL.md)                       | Replacing hardcoded geometry with shared tokens           |
| [qml-visual-language](.agents/skills/qml-visual-language/SKILL.md)                   | Visual identity and cross-component consistency           |
| [qml-indicator-motion](.agents/skills/qml-indicator-motion/SKILL.md)                 | Active indicators and sliding highlights                  |
| [attached-expansion-motion](.agents/skills/attached-expansion-motion/SKILL.md)       | Reusing SuperIsland attached panel motion in widgets      |
| [qml-motion-debug](.agents/skills/qml-motion-debug/SKILL.md)                         | Motion looks wrong even though state changes              |
| [bar-widget-width-ownership](.agents/skills/bar-widget-width-ownership/SKILL.md)     | Widget-local width ownership vs bar reserved width        |
| [list-transition-handoffs](.agents/skills/list-transition-handoffs/SKILL.md)         | Animated list replacement and filter handoffs             |
| [qml-performance-debug](.agents/skills/qml-performance-debug/SKILL.md)               | Jank, frame drops, and layout thrash                      |
| [lyrics-display-stability](.agents/skills/lyrics-display-stability/SKILL.md)         | Lyric display latching, sparse-line stability, and media text flash prevention |
| [netease-web-lyrics-stability](.agents/skills/netease-web-lyrics-stability/SKILL.md) | NetEase web lyrics bridge weak-payload and source-latch debugging |
| [reference-attribution](.agents/skills/reference-attribution/SKILL.md)               | Adapting patterns from another repo                       |
| [attached-expansion-geometry](.agents/skills/attached-expansion-geometry/SKILL.md)   | SuperIsland or media attached-panel bridge geometry       |
| [qml-workspace-overview-model](.agents/skills/qml-workspace-overview-model/SKILL.md) | Workspace tabs showing per-workspace windows or icons     |
