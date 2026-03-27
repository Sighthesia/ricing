# Error Handling

> How errors are handled in this project.

---

## Overview

Errors are treated as recoverable unless the UI cannot continue safely. Services
should log a concise diagnostic, restore a consistent state, and fall back to
defaults or empty models.

---

## Error Types

Common failure classes in this repo:

- file IO failures,
- invalid or missing JSON,
- malformed compositor/process payloads,
- command/process exit failures,
- missing or incompatible keys in persisted state.

---

## Error Handling Patterns

Use `try/catch` around parsing, guard against missing values, and handle file
watcher/process failures by restoring defaults.

Examples:

- `services/SettingsService.qml` falls back to defaults and rewrites the file on load failure.
- `services/WidgetConfigService.qml` warns on parse failure and keeps the last good store.
- `services/NiriService.qml` guards unexpected compositor payload shapes.

---

## API Error Responses

There is no HTTP API layer. Service methods typically return `true` / `false`,
`""`, `null`, or an empty model/array when an operation cannot complete.

---

## Common Mistakes

- Letting malformed JSON break the UI instead of falling back.
- Leaving a service in a partially updated state after a failure.
- Swallowing failures without logging a useful diagnostic.
- Assuming external process output is always valid.
