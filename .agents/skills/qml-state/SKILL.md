---
name: qml-state
description: Guidelines for managing Settings, Shared State, Component States, Error Handling, and Logging in DymicShell. Use when modifying services or component behavior.
---

# State, Persistence & Error Handling

## Settings and Persistence
- Read settings only through `SettingsService.data.<section>.<key>`.
- Write settings by mutating `SettingsService.data.*`; persistence is already debounced.
- Log all persistence lifecycle events at INFO level with a host prefix (e.g. `[DymicShell:SettingsService]`) for reliable production visibility.
- Do not add ad-hoc save timers in UI code unless you are changing persistence semantics.
- When adding a setting, update both `config/settings-default.json` and `services/SettingsService.qml` to keep the schema/defaults aligned.
- Do not treat `null/dymicshell/*.json` as the live runtime source of truth.

## State Management
- Shared cross-window state belongs in a singleton service.
- Animated panels/windows should use `_state: "closed" | "opening" | "open" | "closing"` instead of toggling `visible` directly.
- Use guard clauses and early returns in JS helpers.
- Keep component-local JS small; move reusable behavior into services or base components.

## Error Handling
- Treat file IO, JSON parsing, compositor data, and external process output as recoverable failures.
- Log concise diagnostics and fall back to default or empty state instead of breaking the UI.
- Restore a consistent service state before returning from recoverable failures.
- Clamp untrusted numeric input and guard against missing object keys.