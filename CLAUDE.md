Read [AGENTS.md](AGENTS.md) before starting any task.

## Skills

Load these for detailed context on specific topics. See `.agents/skills/README.md` for grouped navigation.

### Architecture

| Skill | When to use |
| --- | --- |
| [qml-architecture](.agents/skills/qml-architecture/SKILL.md) | Use when working on QML architecture, file structure, naming conventions, imports, or module layout. |
| [qml-state](.agents/skills/qml-state/SKILL.md) | Use when modifying settings, shared state, persistence, error handling, logging, or service-driven component behavior. |

### Visual System

| Skill | When to use |
| --- | --- |
| [attached-expansion-geometry](.agents/skills/attached-expansion-geometry/SKILL.md) | Use when modifying SuperIsland or media attached panel bridge geometry, especially if the bridge-to-panel corner looks bulged, notched, or overly wide. |
| [qml-components](.agents/skills/qml-components/SKILL.md) | Use when building UI elements with DymicShell tokens, semantic colors, theme values, base components, or interactive surface patterns. |
| [qml-context-menu](.agents/skills/qml-context-menu/SKILL.md) | Use when creating, refactoring, or visually aligning bar-style context menus, tray menus, and submenus. |
| [qml-token-cleanup](.agents/skills/qml-token-cleanup/SKILL.md) | Use when consolidating visual tokens, extracting repeated QML geometry into `Theme*` singletons, or cleaning hardcoded spacing, radius, widths, and panel dimensions across related UI families. |
| [qml-visual-language](.agents/skills/qml-visual-language/SKILL.md) | Use when defining or enforcing visual identity, motion language, and cross-component consistency. |
| [superisland-window-hint-semantic-ownership](.agents/skills/superisland-window-hint-semantic-ownership/SKILL.md) | Use when changing SuperIsland window-hint geometry or layout and you need to separate the bar host, hint presentation root, attached shell, and detached lower content ownership. |

### Motion

| Skill | When to use |
| --- | --- |
| [attached-expansion-motion](.agents/skills/attached-expansion-motion/SKILL.md) | Use when reusing SuperIsland-style attached panel motion in standalone widgets, especially if pill and panel feel detached, throw/catch affects the wrong layer, or the motion becomes janky. |
| [qml-indicator-motion](.agents/skills/qml-indicator-motion/SKILL.md) | Use when building or debugging moving active indicators, sliding highlights, or stretch-then-settle pills behind workspace tabs, icon rows, or segmented controls. |
| [qml-motion-debug](.agents/skills/qml-motion-debug/SKILL.md) | Use when debugging Quickshell or QML motion bugs where state updates occur but the visual transition looks static, too subtle, or wrong. |
| [superisland-window-hint-exit-timing](.agents/skills/superisland-window-hint-exit-timing/SKILL.md) | Use when bar-expanded window-hint title/workspace exit timing splits, width targets seem ignored, or changing exit timing breaks throw/catch alignment. |
| [list-transition-handoffs](.agents/skills/list-transition-handoffs/SKILL.md) | Use when modifying animated list filtering or replacement transitions that mix live delegates with detached layers, especially when rapid updates cause blank frames, overlap, or ghosts. |

### Performance

| Skill | When to use |
| --- | --- |
| [qml-performance-debug](.agents/skills/qml-performance-debug/SKILL.md) | Use when debugging DymicShell or Quickshell jank, frame drops, layout thrash, layer-shell resize churn, or slow widget transitions. |

### Media

| Skill | When to use |
| --- | --- |
| [lyrics-display-stability](.agents/skills/lyrics-display-stability/SKILL.md) | Use when lyric text, media metadata, or announcement pulses flicker during sparse lyric timing or weak source updates. |
| [netease-web-lyrics-stability](.agents/skills/netease-web-lyrics-stability/SKILL.md) | Use when debugging or modifying the NetEase web lyrics bridge, especially if track changes lose `songId`, bridge payloads leak placeholder metadata, or NetEase lyric recovery stops after weak browser payloads. |

### Workflow

| Skill | When to use |
| --- | --- |
| [reference-attribution](.agents/skills/reference-attribution/SKILL.md) | Use when adapting code, templates, config patterns, or architecture from another repository and attribution must be documented consistently. |
