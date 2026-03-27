# Directory Structure

> How backend code is organized in this project.

---

## Overview

There is no traditional backend service tree in this repo. The closest backend
layer is the singleton service layer in `services/`, which owns IO,
process integration, persistence, and shared state.

---

## Directory Layout

```
services/
├── SettingsService.qml
├── BarLayoutService.qml
├── WidgetConfigService.qml
├── NiriService.qml
└── SystemTrayService.qml
config/
└── settings-default.json
```

---

## Module Organization

Use one singleton per domain concern. Services should own the source of truth
for persisted or shared state and expose a minimal API to the UI layer.

- Settings and persistence: `SettingsService.qml`
- Layout and geometry: `BarLayoutService.qml`
- Compositor integration: `NiriService.qml`
- Widget-specific storage: `WidgetConfigService.qml`
- Wallpaper and tray state: `WallpaperService.qml`, `SystemTrayService.qml`

---

## Naming Conventions

Singletons end with `Service.qml`. Persistent data files use descriptive names
such as `settings.json`, `layout.json`, and `widget-config.json`.

---

## Examples

- `services/SettingsService.qml` - persisted settings schema and debounced writes.
- `services/BarLayoutService.qml` - shared geometry, drag state, and layout persistence.
- `services/NiriService.qml` - external compositor process integration.
- `services/WidgetConfigService.qml` - per-instance storage with local JSON file IO.
