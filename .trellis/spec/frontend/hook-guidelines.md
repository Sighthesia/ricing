# Hook Guidelines

> How hooks are used in this project.

---

## Overview

This project does not use React-style hooks. Reusable side effects live in
singleton services, `Connections`, timers, and small helper functions inside the
component that owns the lifecycle.

---

## Custom Hook Patterns

Prefer domain-specific helpers over generic utility layers. Good examples are
`_refreshFocus()` in `modules/bar/widgets/WorkspaceWidget.qml` and
`_recomputeGeometryContracts()` in `services/BarLayoutService.qml`.

Use `Connections` to react to singleton signals instead of polling state.

---

## Data Fetching

There is no query library. External data comes from `Process`, `FileView`, or
other service-owned IO, then gets normalized into singleton state.

Examples:

- `services/SettingsService.qml` - `FileView` + `Process` for JSON settings.
- `services/NiriService.qml` - `Process` + `SplitParser` for compositor data.
- `modules/background/BackgroundWindow.qml` - `Connections` to wallpaper updates.

---

## Naming Conventions

Do not invent `use*` names. Name helpers after the domain action they perform
(`_loadFromText`, `_sanitizeBarMotion`, `_enterHoverOpen`).

---

## Common Mistakes

- Duplicating the same `Connections` logic in multiple widgets.
- Moving IO or persistence into UI files instead of services.
- Adding a local timer for settings saves when the service already debounces.
- Reading raw JSON directly from components instead of through a singleton.
