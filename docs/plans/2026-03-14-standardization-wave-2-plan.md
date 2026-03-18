# Standardization Wave 2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.


**Architecture:** Keep this wave behavior-preserving. Add coverage first under `tests/qml/`, then apply narrow mechanical edits to settings-side components and a few low-risk presentation files. Avoid large service refactors, token migrations that need design work, or broad declaration reordering in complex files.


---


**Files:**
- Modify: `AGENTS.md`

**Step 1: Write the failing harness command**

Run:

```bash
```




```qml
import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.modules.bar
import "modules/bar/settings" as SettingsParts

ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    SettingsParts.ToggleSection {
        id: toggleSection
        visible: false
        label: "Toggle"
    }

    SettingsParts.ExpandableGroup {
        id: expandableGroup
        visible: false
        title: "Group"
        Text { text: "Body" }
    }

    SettingsParts.FontPickerSection {
        id: fontPicker
        visible: false
        label: "Font"
        value: Theme.fontFamily
    }

    SettingsParts.BehaviorSection {
        id: behaviorSection
        visible: false
    }

    SettingsParts.AppearancePage {
        id: appearancePage
        visible: false
    }

    SettingsParts.AboutPage {
        id: aboutPage
        visible: false
    }

    SettingsParts.SettingsSidebar {
        id: sidebar
        visible: false
    }

    Component.onCompleted: {
        root._assert(toggleSection.implicitHeight > 0,
            "ToggleSection should expose a positive implicit height")
        root._assert(expandableGroup.implicitHeight >= Theme.settingsGroupHeaderHeight,
            "ExpandableGroup should include at least its header height")
        root._assert(fontPicker.implicitHeight >= Theme.settingsRowHeight,
            "FontPickerSection should expose a collapsed row height")
        root._assert(behaviorSection.implicitHeight > 0,
            "BehaviorSection should render a positive implicit height")
        root._assert(appearancePage.implicitHeight > 0,
            "AppearancePage should render a positive implicit height")
        root._assert(aboutPage.implicitHeight > 0,
            "AboutPage should render a positive implicit height")
        root._assert(sidebar.implicitHeight > 0,
            "SettingsSidebar should render a positive implicit height")
        root._assert(typeof sidebar.runEnterAnimation === "function",
            "SettingsSidebar should expose runEnterAnimation()")
        root._assert(typeof aboutPage.runEnterAnimation === "function",
            "AboutPage should expose runEnterAnimation()")
        Qt.callLater(Qt.quit)
    }
}
```

**Step 3: Create the dedicated runner**


```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
```

**Step 4: Update agent guidance**


```bash
```

Also state that `tests/qml/{config,services,modules}` must remain intact for all harnesses.

**Step 5: Run the new harness**

Run:

```bash
```


---

### Task 2: Standardize easing token usage in settings primitives and bar wrapper

**Files:**
- Modify: `modules/bar/settings/ToggleSection.qml`
- Modify: `modules/bar/settings/SettingsSidebar.qml`
- Modify: `modules/bar/settings/ExpandableGroup.qml`
- Modify: `modules/bar/settings/FontPickerSection.qml`
- Modify: `modules/bar/settings/AppearancePage.qml`
- Modify: `modules/bar/settings/BehaviorSection.qml`
- Modify: `modules/bar/BarWidgetWrapper.qml`

**Step 1: Confirm the new baseline test is green before refactoring**

Run:

```bash
```

Expected: PASS.

**Step 2: Apply the exact easing substitutions**

Use these file-scoped replacements only:

```text
ToggleSection.qml:       Easing.InOutCubic -> Theme.anim.moveType
SettingsSidebar.qml:     Easing.InOutCubic -> Theme.anim.moveType
ExpandableGroup.qml:     Easing.InOutCubic -> Theme.anim.moveType
FontPickerSection.qml:   Easing.InOutCubic -> Theme.anim.moveType
AppearancePage.qml:      Easing.InOutCubic -> Theme.anim.moveType
BehaviorSection.qml:     Easing.InOutCubic -> Theme.anim.moveType
BarWidgetWrapper.qml:    Easing.OutQuad    -> Theme.anim.highlightType
```

Do not change durations, overshoot values, or unrelated animation blocks in this task.

**Step 3: Re-run focused verification**

Run:

```bash
timeout 10 qs --path .
```

Expected: both commands PASS; no new settings-related load errors.

---

### Task 3: Normalize low-risk headers, imports, and declaration ordering

**Files:**
- Modify: `modules/bar/widgets/Clock.qml`
- Modify: `modules/bar/widgets/SuperIslandWidget.qml`
- Modify: `modules/bar/settings/AboutPage.qml`
- Modify: `modules/notifications/NotificationCard.qml`

**Step 1: Normalize `Clock.qml`**

Apply these exact edits:

```text
- Reorder imports to Quickshell -> Qt -> qs.config
- Add a top-level English purpose comment above Rectangle
```

**Step 2: Normalize `SuperIslandWidget.qml`**

Apply these exact edits:

```text
- Reorder imports to Quickshell -> Qt -> qs.config -> qs.services -> relative
- Add a top-level English purpose comment above Item
- Do not reorder the large property block beyond obvious header normalization
```

**Step 3: Normalize `AboutPage.qml` and `NotificationCard.qml`**

Apply these exact edits:

```text
AboutPage.qml:
- Reorder imports to Quickshell -> Qt -> qs.config -> qs.services -> relative

NotificationCard.qml:
- Reorder imports to Quickshell -> Qt -> qs.config -> qs.services
- Keep required properties together before mutable properties/signals
- Do not change animation behavior or card layout
```

**Step 4: Run targeted verification**

Run:

```bash
timeout 10 qs --path .
```

Expected: PASS; `SuperIslandWidget` still loads and the shell still parses cleanly.

---

### Task 4: Final verification sweep

**Files:**
- Verify: `AGENTS.md`
- Verify: all files touched above


```bash
```

Expected: all PASS.

**Step 2: Run full-shell load check**

```bash
timeout 10 qs --path .
```

Expected: PASS. Existing environment warnings may remain, but there should be no new load failures.

**Step 3: Review diff scope**

Confirm the diff stays within:

```text
- AGENTS.md command updates
- easing token substitutions
- import/comment/order-only normalization
```

Avoid sneaking in unrelated refactors.
