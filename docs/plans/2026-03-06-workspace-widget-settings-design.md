# Workspace Widget Settings — Design Document

**Date:** 2026-03-06  
**Status:** Approved

## Overview

Expose four WorkspaceWidget runtime parameters as user-configurable settings:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `defaultMode` | `"focus"` \| `"overview"` | `"focus"` | Which mode is active when a window is focused |
| `titleMaxWidth` | integer (px) | `240` | Maximum rendered title width before ElideRight |
| `revertDelay` | integer (ms) | `1500` | Duration of overview flash (workspace switch / hover exit) |
| `hoverEnabled` | boolean | `true` | Whether hovering the widget temporarily switches mode |

Settings are stored in `settings-default.json` under a new `"workspaceWidget"` section, read via the existing `SettingsService` singleton.

## Architecture

### Files Changed

| File | Change |
|------|--------|
| `config/settings-default.json` | Add `"workspaceWidget"` section with 4 keys |
| `modules/bar/widgets/WorkspaceWidget.qml` | Replace 4 hardcoded constants with `SettingsService.data.workspaceWidget.*` bindings; update `_showOverview` to respect `defaultMode` |
| `modules/bar/widget-settings/WorkspaceWidgetSection.qml` | New file — functional settings UI for workspaceWidget |
| `modules/bar/WidgetSettingsPanel.qml` | Show `WorkspaceWidgetSection` in the "功能" group when `_widgetId === "workspaceWidget"` |

### SettingsService access pattern

```qml
SettingsService.data.workspaceWidget.defaultMode    // "focus" | "overview"
SettingsService.data.workspaceWidget.titleMaxWidth  // int px
SettingsService.data.workspaceWidget.revertDelay    // int ms
SettingsService.data.workspaceWidget.hoverEnabled   // bool
```

## WorkspaceWidget State Machine Update

`defaultMode` changes the meaning of `_modeOverride = ""` (natural/unforced state).

```qml
// Before:
readonly property bool _showOverview:
    _modeOverride === "overview" ||
    (_modeOverride !== "focus" && _focusedTitle.length === 0)

// After:
readonly property bool _showOverview: {
    if (_modeOverride === "overview") return true
    if (_modeOverride === "focus")    return false
    // Natural state — use defaultMode setting
    if (SettingsService.data.workspaceWidget.defaultMode === "overview") return true
    return _focusedTitle.length === 0
}
```

The four hardcoded readonly properties become reactive bindings:

```qml
readonly property int _titleMaxW:    SettingsService.data.workspaceWidget.titleMaxWidth
readonly property int _revertDelay:  SettingsService.data.workspaceWidget.revertDelay
readonly property bool _hoverActive: SettingsService.data.workspaceWidget.hoverEnabled
```

`_hoverActive` gates the `_hoverArea.onEntered` handler:

```qml
onEntered: {
    if (!root._hoverActive || root._justReverted) return
    _revertTimer.stop()
    root._modeOverride = "overview"
}
```

## WorkspaceWidgetSection Component

```
WorkspaceWidgetSection (Column)
├── SliderSection — "标题宽度"   (titleMaxWidth, 60–400 px, step 10)
├── SliderSection — "切换延迟"   (revertDelay,  300–5000 ms, step 100)
├── Row — "默认形态" + segmented button pair (focus | overview)
└── Row — "悬浮切换" + toggle switch (hoverEnabled)
```

For the "默认形态" segmented buttons, follow the BehaviorSection position-selector pattern (two `Rectangle` pills driven by a `Repeater`).

For the "悬浮切换" toggle, reuse the switch pattern already present in `BarBehaviorSection.qml`.

## WidgetSettingsPanel Wiring

The "功能" ExpandableGroup currently shows a placeholder `Text`. Replace it with:

```qml
Loader {
    width: parent.width
    active: root._widgetId === "workspaceWidget"
    sourceComponent: WorkspaceWidgetSection { width: parent.width }
}

Text {
    visible: root._widgetId !== "workspaceWidget"
    // placeholder text (暂无可用设置)
    ...
}
```

This ensures other widgets still see the placeholder while workspaceWidget gets its settings.
