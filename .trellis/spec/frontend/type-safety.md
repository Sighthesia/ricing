# Type Safety

> Type safety patterns in this project.

---

## Overview

The project uses QML typing discipline rather than a separate schema system.
Prefer typed properties, explicit guards, and safe conversions over broad
`var` usage.

---

## Type Organization

Keep public API on the root item, derived values as `readonly property`, and
dynamic collections in `ListModel`, arrays, or service-owned maps.

Use `config/settings-default.json` plus `services/SettingsService.qml` as the
authoritative shape for persisted settings.

---

## Validation

Validate external input at the boundary:

- wrap `JSON.parse` in `try/catch`,
- clamp numeric values with `Math.max` / `Math.min`,
- check arrays with `Array.isArray`,
- coerce IDs with `String(...)`,
- treat missing keys as defaults rather than failures.

Examples: `services/NiriService.qml`, `services/SettingsService.qml`,
`config/Colors.qml`.

---

## Common Patterns

- `required property string wsId` in delegates with service-fed models.
- `readonly property bool _enabled: SettingsService.data.systemTray.enabled` for
  derived flags.
- Sentinel values such as `-1`, `""`, or `null` for missing external data.
- Explicit object copies with `Object.assign({}, source)` before mutation.

---

## Forbidden Patterns

- Assuming compositor/process payloads always match the current shape.
- Using `property var` when a concrete type is known.
- Accessing nested object keys without null checks.
- Relying on truthiness where `null` / `""` / `0` need different handling.
