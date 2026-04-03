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

## Theme Export and Reload
- Keep theme generation in one service-owned pipeline; UI toggles should choose one entrypoint instead of mixing `apply-only` and full regeneration in the same interaction.
- When chaining `Process.onExited` into another `Process`, defer the follow-up with `Qt.callLater(...)` to avoid reading stale `running` state in the same event tick.
- If a service queues follow-up reloads while a process is running, queue the exact pending scope (`full` vs `system-only`) instead of falling back to a generic timer that can rerun the wrong pipeline.
- Validate wallpaper/theme source inputs before persisting them. Empty or missing source files must not silently reuse stale generated theme outputs.
- Keep generated scheme names and activation commands identical across export and apply layers. A file named `Matugen.colors` must not be activated as `DymicShellMatugen`.
- Prefer application-native live reload commands over generic signals when updating external themes. For kitty, prefer remote control or `reload_conf_in_all_kitties()` before signal-based fallbacks.
- Log stdout/stderr for theme generator and apply helper processes so template failures, bad paths, and permission issues are diagnosable from shell logs.
