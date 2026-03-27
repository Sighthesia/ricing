# Database Guidelines

> Database patterns and conventions for this project.

---

## Overview

This repo does not use an SQL database or ORM. Persistent data is stored as JSON
files owned by QML services, with `config/settings-default.json` as the schema
and default-source of truth.

---

## Query Patterns

Read state through singleton properties and service accessors. Write by
mutating the service-owned model or adapter, then let the service serialize a
complete JSON snapshot.

Examples:

- `services/SettingsService.qml` uses `JsonAdapter` and writes a full settings snapshot.
- `services/BarLayoutService.qml` serializes `layoutModel` to disk.
- `services/WidgetConfigService.qml` persists a per-instance store map.

---

## Migrations

There are no migrations. Schema changes must be handled by updating both the
service defaults and the serializer so older files still load with fallback
values.

When a setting is added or renamed, update:

- `config/settings-default.json`
- `services/SettingsService.qml`

For file-backed state, preserve missing keys by merging loaded JSON into the
current adapter/model instead of replacing it wholesale.

---

## Naming Conventions

Use camelCase for JSON keys and service properties. File names should describe
the payload, not the implementation detail.

- `settings.json`
- `layout.json`
- `widget-config.json`

---

## Common Mistakes

- Writing partial JSON from the UI layer instead of a service.
- Forgetting to update defaults when adding a setting.
- Overwriting old state without merge/fallback handling.
- Treating checked-in `null/dymicshell/*.json` artifacts as live state.
