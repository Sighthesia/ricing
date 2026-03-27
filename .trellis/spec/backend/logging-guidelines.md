# Logging Guidelines

> How logging is done in this project.

---

## Overview

There is no dedicated logging library. Use QML's console methods with a stable
host prefix so logs are searchable across services.

---

## Log Levels

- `console.info` - lifecycle, save/load success, and expected state transitions.
- `console.warn` - recoverable failures, parse errors, and failed writes.
- `console.log` - avoid for new code; use only if the existing code path already
  relies on it and you are not changing the behavior.

---

## Structured Logging

Use a consistent prefix such as `[DymicShell:SettingsService]` and include the
relevant path, exit code, or state name in the message.

Examples:

- `services/SettingsService.qml` - load/save lifecycle logs.
- `services/WidgetConfigService.qml` - parse failure warnings.
- `services/BarLayoutService.qml` - layout parse and persistence messages.

---

## What to Log

- Service initialization and shutdown-adjacent lifecycle.
- File load/save attempts and outcomes.
- Recoverable parse failures and process exit codes.
- State transitions that help explain persistence or recovery.

---

## What NOT to Log

- Secrets or sensitive environment values.
- Full payload dumps unless they are the specific subject of debugging.
- Repetitive high-volume messages from frequent UI updates.
