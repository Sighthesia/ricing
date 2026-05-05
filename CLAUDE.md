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
| [contour-anchor-before-radius](.agents/skills/contour-anchor-before-radius/SKILL.md) | Use when a rounded bridge, shoulder, or corner still looks too wide, bulged, or notched and the real problem may be the contour anchor rather than the radius. |
| [qml-components](.agents/skills/qml-components/SKILL.md) | Use when building UI elements with DymicShell tokens, semantic colors, theme values, base components, or interactive surface patterns. |
| [qml-context-menu](.agents/skills/qml-context-menu/SKILL.md) | Use when creating, refactoring, or visually aligning bar-style context menus, tray menus, and submenus. |
| [qml-token-cleanup](.agents/skills/qml-token-cleanup/SKILL.md) | Use when consolidating visual tokens, extracting repeated QML geometry into `Theme*` singletons, or cleaning hardcoded spacing, radius, widths, and panel dimensions across related UI families. |
| [qml-visual-language](.agents/skills/qml-visual-language/SKILL.md) | Use when defining or enforcing visual identity, motion language, and cross-component consistency. |
| [multi-surface-semantic-ownership](.agents/skills/multi-surface-semantic-ownership/SKILL.md) | Use when one feature spans multiple roots or detached surfaces and geometry bugs stem from confusing host, shell, presentation, or content ownership. |
| [runtime-cleanup-chain-interruptions](.agents/skills/runtime-cleanup-chain-interruptions/SKILL.md) | Use when local state resets correctly but stale reservation/geometry/shared state survives because a runtime error interrupts the cleanup chain. |

### Motion

| Skill | When to use |
| --- | --- |
| [visual-vs-layout-motion-ownership](.agents/skills/visual-vs-layout-motion-ownership/SKILL.md) | Use when animation becomes janky because exported layout geometry and visible motion geometry are being animated by the same owner. |
| [qml-indicator-motion](.agents/skills/qml-indicator-motion/SKILL.md) | Use when building or debugging moving active indicators, sliding highlights, or stretch-then-settle pills behind workspace tabs, icon rows, or segmented controls. |
| [qml-motion-debug](.agents/skills/qml-motion-debug/SKILL.md) | Use when debugging Quickshell or QML motion bugs where state updates occur but the visual transition looks static, too subtle, or wrong. |
| [single-instance-handoff-motion](.agents/skills/single-instance-handoff-motion/SKILL.md) | Use when one visual element appears to move between hosts or states and the handoff causes teleporting, duplicate instances, early fade-out, or exit-phase reappearance. |
| [split-host-exit-synchronization](.agents/skills/split-host-exit-synchronization/SKILL.md) | Use when two visible regions should exit together but belong to different geometry owners, so one retreats early or timing fixes break unrelated motion. |
| [list-transition-handoffs](.agents/skills/list-transition-handoffs/SKILL.md) | Use when modifying animated list filtering or replacement transitions that mix live delegates with detached layers, especially when rapid updates cause blank frames, overlap, or ghosts. |

### Performance

| Skill | When to use |
| --- | --- |
| [qml-performance-debug](.agents/skills/qml-performance-debug/SKILL.md) | Use when debugging DymicShell or Quickshell jank, frame drops, layout thrash, layer-shell resize churn, or slow widget transitions. |

### Media

| Skill | When to use |
| --- | --- |
| [session-latched-display-state](.agents/skills/session-latched-display-state/SKILL.md) | Use when UI text or derived display state flickers because the source updates sparsely, emits temporary empties, or becomes briefly weaker than the current trusted session. |
| [weak-signal-bridge-normalization](.agents/skills/weak-signal-bridge-normalization/SKILL.md) | Use when a browser, extension, or cross-context bridge emits incomplete payloads, placeholder data, or late identifiers that must be normalized before entering app state. |

### Workflow

| Skill | When to use |
| --- | --- |
| [reference-attribution](.agents/skills/reference-attribution/SKILL.md) | Use when adapting code, templates, config patterns, or architecture from another repository and attribution must be documented consistently. |
