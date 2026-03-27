# State Management

> How state is managed in this project.

---

## Overview

State is split into component-local UI state, shared singleton state, and
persistent settings. The rule of thumb is simple: if more than one component
needs it, it belongs in a service.

---

## State Categories

- Local state: hover flags, animation state, drag state, cached measurements.
- Global/shared state: `SettingsService`, `BarLayoutService`, `NiriService`,
  `SystemTrayService`, `WallpaperService`.
- Persistent state: `config/settings-default.json`, layout JSON, widget config.
- External state: compositor and process output normalized by services.

---

## When to Use Global State

Promote state to a singleton when it is:

- shared across windows or widgets,
- needed by both config and UI layers,
- persisted to disk,
- or derived from an external process that should be read once and reused.

Examples: `SettingsService.data.*`, `BarLayoutService.geometryArrivals`,
`NiriService.workspaces`, `SystemTrayService.pinnedItems`.

---

## Server State

There is no server state layer. External compositor/process data is treated as
recoverable input and stored in singleton models after normalization.

---

## Common Mistakes

- Mutating `visible` directly instead of using the component state machine.
- Binding a widget to a raw file or process stream instead of service state.
- Keeping shared geometry, settings, or layout data in a local component.
- Adding ad-hoc persistence in the UI layer.
