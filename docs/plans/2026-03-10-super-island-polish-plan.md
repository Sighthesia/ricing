# Super Island Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix Super Island media layout polish issues, synchronize restore animation width/height timing, and expose widget-level visibility toggles for media, notifications, and workspace hints.

**Architecture:** Keep event arbitration in `SuperIslandService.qml` and limit this work to rendering, widget settings UI, and regression coverage. The animation fix should move restore width changes onto the same explicit timeline as pill height collapse instead of relying on delayed layout behavior.


---


**Files:**

**Step 1: Write failing assertions for media top padding and hint/source visibility toggles**


- media content in the main Pill keeps top padding from the widget edge
- disabling `showMedia` suppresses media event rendering
- disabling `showNotifications` suppresses notification event rendering
- disabling `showWorkspaceEvents` suppresses window/workspace hint rendering


Expected: FAIL on the newly added assertions before implementation.

### Task 2: Fix media card geometry and artwork shape

**Files:**
- Modify: `config/Theme.qml`
- Modify: `modules/bar/widgets/SuperIslandWidget.qml`
- Modify: `modules/bar/superisland/IslandMediaCard.qml`

**Step 1: Move any remaining vertical media inset values to shared `Theme.barWidget` tokens**

Ensure the main pill and media card use the same structural vertical spacing tokens instead of component-local math.

**Step 2: Keep the main pill visually padded from the widget top edge**

Adjust the main Pill clip/container so media content no longer sits against the component top boundary.

**Step 3: Render media artwork as a circular crop**

Use a circular mask/container so album art is shown as a round crop instead of a rounded rectangle.


Expected: media padding/artwork checks pass.

### Task 3: Synchronize restore width and height collapse

**Files:**
- Modify: `modules/bar/widgets/SuperIslandWidget.qml`

**Step 1: Add a failing regression assertion for restore timing**


**Step 2: Replace delayed width-only settle behavior with an explicit restore animation**

Make the returning phase animate width on the same timeline as `_pillCollapseAnim` so both axes contract together.


Expected: restore-timing assertion passes.

### Task 4: Add Super Island widget settings section

**Files:**
- Create: `modules/bar/widgetsettings/SuperIslandSection.qml`
- Modify: `modules/bar/WidgetSettingsPanel.qml`
- Modify: `services/SettingsService.qml`
- Modify: `config/settings-default.json`

**Step 1: Create a dedicated section component under the existing “功能” group**

Render three toggles bound to:

- `SettingsService.data.superIsland.showMedia`
- `SettingsService.data.superIsland.showNotifications`
- `SettingsService.data.superIsland.showWorkspaceEvents`

**Step 2: Wire the section into `WidgetSettingsPanel.qml`**

Show it when the active widget id is `superIsland`, matching the existing workspace widget pattern.

**Step 3: Validate defaults and persistence paths**

Confirm the settings adapter and defaults still serialize correctly.


Run: editor/QML error scan on touched files.

### Task 5: Sync docs with the final behavior

**Files:**
- Modify: `docs/plans/2026-03-09-super-island-plan.md`

**Step 1: Update the “Still open” and remaining-task sections**

Mark the settings work as completed or revised once implementation lands, and note the new polish fixes if needed.
