# Directory Structure

> How frontend code is organized in this project.

---

## Overview

Frontend code is organized by responsibility, not by framework artifact type.
`shell.qml` wires top-level windows only; feature behavior lives in `modules/`,
shared tokens live in `config/`, and singleton state/persistence lives in
`services/`.

---

## Directory Layout

```
shell.qml
config/
├── Colors.qml
└── Theme.qml
services/
├── SettingsService.qml
├── BarLayoutService.qml
└── NiriService.qml
modules/
├── bar/
├── background/
├── launcher/
└── notifications/
```

---

## Module Organization

Use one folder per feature area under `modules/` and keep local helpers next to
the feature that uses them. Window roots live beside their subcomponents.

- `modules/bar/` contains bar windows, panels, widgets, and bar-local shared components.
- `modules/background/` contains wallpaper windows and wallpaper picker UI.
- `modules/launcher/` contains launcher shell UI and providers.
- `modules/notifications/` contains notification window and card UI.

---

## Naming Conventions

Use descriptive domain names and suffix by role:

- `*Window.qml` for top-level panels/windows.
- `*Panel.qml` for transient sheets and popovers.
- `*Widget.qml` for bar items.
- `*Service.qml` for singletons with shared state or IO.
- `Theme.qml` and `Colors.qml` for shared design tokens.

---

## Examples

- `shell.qml` - top-level window wiring only.
- `modules/bar/BarContent.qml` - feature root that composes sections and overlays.
- `modules/bar/widgets/SystemTrayWidget.qml` - widget-local state and service-driven data.
- `services/SettingsService.qml` - singleton persistence and settings schema owner.
