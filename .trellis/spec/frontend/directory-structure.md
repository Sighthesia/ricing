# Directory Structure

> How frontend code is organized in this project.

---

## Overview

Quickshell UI code in this project is organized around a thin shell entry point, feature-scoped QML modules, and shared singleton services.

---

## Directory Layout

```
./
├── shell.qml
├── modules/
│   ├── background/
│   └── bar/
└── services/
    ├── qmldir
    └── barlayout/
```

---

## Module Organization

### Convention: Keep `shell.qml` as a top-level composition root

**What**: `shell.qml` should instantiate only top-level shell surfaces and reusable feature entry modules.

**Why**: This keeps screen/window ownership obvious and prevents feature logic from being trapped in the shell root.

**Example**:
```qml
ShellRoot {
    Background.ScreenCornerWindow {
    }

    Bar.BarWindow {
    }
}
```

### Convention: Group reusable UI by feature under `modules/`

**What**: Put feature-specific QML under `modules/<feature>/`, and keep each feature split by responsibility when it starts owning multiple declarations.

**Why**: This makes later growth incremental instead of forcing a rewrite when a single-file prototype turns into a subsystem.

**Example**:
```text
modules/bar/
├── BarWindow.qml
├── BarContent.qml
├── BarSection.qml
└── BarWidgetWrapper.qml
```

### Convention: Put shared singleton state under `services/`

**What**: Shared layout/state objects belong in `services/` and must be exported through `services/qmldir` when they are imported as singletons.

**Why**: This creates a clear contract between visual modules and stateful services, and keeps cross-module dependencies explicit.

**Example**:
```text
services/
├── BarLayoutService.qml
├── qmldir
└── barlayout/
    ├── BarLayoutLayoutModel.js
    └── BarLayoutSections.js
```

---

## Naming Conventions

* Use `PascalCase.qml` for reusable QML components and singleton service files.
* Use lowercase feature folders such as `modules/bar/` and `modules/background/`.
* Use `PascalCase.js` for feature-scoped helper modules that back a QML service.

---

## Examples

* `shell.qml` — top-level shell composition only
* `modules/background/` — reusable screen overlay surfaces
* `modules/bar/` — bar window/content/section composition
* `services/BarLayoutService.qml` — shared layout state for the bar feature
