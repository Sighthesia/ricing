---
name: qml-architecture
description: QML architecture rules, file structure, naming conventions, and imports. Use when creating or modifying QML files and learning about module layout.
---

# QML Architecture Rules

## Architecture Rules
- Preserve the three-layer flow: `services/` -> `config/` -> `modules/`.
- `shell.qml` stays declarative and only wires top-level windows together.
- `services/` own IO, persistence, timers, process integration, and shared state.
- `config/` derives semantic tokens from settings and service-backed data.
- `modules/` render UI and forward actions back into services instead of duplicating state.
- Promote reused behavior into services or shared base components.

## QML File Structure
Keep each QML file ordered as:
1. imports
2. top-level English comment explaining purpose/usage
3. root `id`
4. `required property`
5. public mutable `property`
6. `readonly property`
7. private `property _...`
8. `signal`
9. child declarations
10. functions
11. `Component.onCompleted`
12. `Connections`

## Import, Naming, and Formatting
- Import order: `Quickshell*` -> `Qt*` -> `qs.config` -> `qs.services` -> `qs.modules` -> relative imports.
- Use 4-space indentation and multiline bindings when one line becomes hard to scan.
- Use typed properties (`bool`, `int`, `real`, `string`, `color`) when the type is known; reserve `var` for dynamic payloads.
- Private members must start with `_`; public API must not.
- Prefer descriptive domain names such as `MediaControlService`, `WidgetSettingsPanel`, or `NotificationHistoryPanel`.
- Avoid grab-bag files named `utils`, `helpers`, `common`, or `shared`.
- Add short English comments only where the role of a layout, visual, or input element is not obvious.