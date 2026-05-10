# State Management

> How state is managed in this project.

---

## Overview

This project uses QML singleton services for shared shell state and keeps rendering modules focused on presentation.

---

## State Categories

### Local visual state

Keep purely visual or short-lived state inside the owning QML component.

Examples:

* hover state inside a widget
* temporary geometry bindings inside a layout container

### Shared shell state

Promote cross-module shell state into a singleton under `services/` and export it through `services/qmldir`.

Examples:

* `BarLayoutService.qml` owns shared bar layout state
* helper logic that transforms persisted layout data lives under `services/barlayout/`
* picker visibility / target-section mode lives in the same service as the layout model so UI entry points can stay thin

### Persisted local state

When shell state should survive restart, the service that owns the state is also responsible for persistence and restore.

Examples:

* `BarLayoutService.qml` stores the normalized layout model through a `FileView` + `JsonAdapter`


---

## When to Use Global State

### Convention: Promote shell-wide layout state into a singleton service

**What**: If multiple QML modules need the same shell state, move that state into a singleton service instead of duplicating it across renderers.

**Why**: This keeps the data contract in one place and prevents the shell root, sections, and widgets from drifting apart.

**Example**:
```qml
pragma Singleton

QtObject {
    readonly property var layoutModel: layoutAdapter.layoutModel

    function sectionWidgets(sectionName) {
        return BarLayoutModel.sectionWidgets(layoutModel, sectionName)
    }
}
```

### Convention: Keep renderers read-only over shared layout data

**What**: Rendering modules such as `modules/bar/BarSection.qml` should read normalized section data from the service and avoid owning persistence rules themselves.

**Why**: This creates a narrow boundary between state mutation and view rendering, which makes later editing features easier to add safely.

**Example**:
```qml
readonly property var sectionModel: Services.BarLayoutService.sectionWidgets(sectionName)
```

### Convention: Keep shared picker mode in the layout service

**What**: Temporary UI mode flags that affect the whole bar, such as picker visibility and target section, belong in `BarLayoutService` rather than in the picker window or shell root.

**Why**: The service already owns the layout model and persistence, so keeping mode flags there preserves a single mutation boundary and makes the picker a thin view layer.

**Example**:
```qml
property bool widgetPickerVisible: false
property string widgetPickerSection: "center"

function openWidgetPicker(sectionName) {
    widgetPickerSection = typeof sectionName === "string" && sectionName ? sectionName : "center"
    widgetPickerVisible = true
}
```

---

## Persistence Pattern

### Convention: The owning service persists normalized data, not ad-hoc view state

**What**: Persist the normalized service model rather than raw renderer buckets or transient visual bindings.

**Why**: Stable persisted contracts make schema upgrades and startup restore much safer.

**Example**:
```qml
function saveLayoutModel(nextLayoutModel) {
    layoutAdapter.layoutModel = BarLayoutModel.normalizeLayoutModel(nextLayoutModel)
    layoutFile.writeAdapter()
}
```

### Convention: Restore inside the service boundary

**What**: Startup restore should happen inside the singleton service that owns the state, using Quickshell IO primitives.

**Why**: This keeps persistence behavior out of `shell.qml` and the rendering modules.

**Example**:
```qml
property FileView layoutFile: FileView {
    path: Quickshell.statePath(BarLayoutPersistence.defaultLayoutPath())
}
```

---

## Common Mistakes

### Common Mistake: Letting renderers define the data contract

**Symptom**: A view component starts deciding schema defaults, persistence behavior, or instance identity.

**Cause**: Shared state logic was left near the rendering layer instead of being centralized.

**Fix**: Move normalization, defaults, and persistence into the owning singleton service or its helper modules.

**Prevention**: If more than one module needs the same shell data, define the contract in `services/` first and let views consume it.
