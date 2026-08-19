# Settings Sidebar Action Buttons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the settings sidebar back and collapse actions visually compact, centered, focus-safe, and synchronized with the sidebar collapse transition while preserving full-width activation areas.

**Architecture:** Keep each action `Item` full width for pointer and keyboard activation. Add a separate 40px visual surface inside each action item; drive its position, icon position, and contracted/expanded alignment from the shared `expansionProgress` value. Remove `activeFocus` from visual background state and remove action-local width animations so the parent sidebar width remains the single geometry owner.

**Tech Stack:** Quickshell QML, QtQuick, `MotionTokens`, existing `LazerSettingsSidebar`, `LazerSettingsNavItem`, and QML tests.

## Global Constraints

- Preserve the osu!lazer sharp language: major surfaces are rectangular/geometric; do not add a sidebar-wide rounded surface.
- Keep the outer action hit areas full width.
- Use the existing `expansionProgress` and `MotionTokens.settingsSidebarCollapse`; do not add a second width animation.
- `activeFocus` must remain keyboard-accessible but must not create a persistent background or white focus frame.
- Action icons use the same `20px` visual size and expanded left alignment as category icons.
- Reduced-motion mode must switch geometry directly without independent action motion.
- After QML changes run `qmllint`, `pytest -q`, and `qs -p .`; QML tests may be blocked by the known missing `qrc:/qs-blackhole` resource.

---

### Task 1: Add Regression Coverage For Action Geometry And States

**Files:**
- Modify: `tests/qml/tst_lazer_settings_panel.qml`
- Test: `tests/qml/tst_lazer_settings_panel.qml`

**Interfaces:**
- Consumes: `panel.sidebar`, `panel.sidebar.collapseButton`, `panel.sidebar.backButton`, `panel.appearanceNav`, and `panel.sidebar.expansionProgress`.
- Produces: assertions covering full-width hit areas, centered icon geometry, no focus border, and shared transition progress.

- [ ] **Step 1: Add assertions for full-width action ownership**

Add a test near the existing sidebar geometry tests:

```qml
function test_sidebarActionsUseFullWidthHitAreas() {
    compare(panel.sidebar.collapseButton.x, 0)
    compare(panel.sidebar.backButton.x, 0)
    compare(panel.sidebar.collapseButton.width, panel.sidebar.width)
    compare(panel.sidebar.backButton.width, panel.sidebar.width)
}
```

- [ ] **Step 2: Add assertions for centered icons and compact visual surfaces**

Expose aliases for the action visual rectangles and icon items if they are not already public, then assert:

```qml
function test_sidebarActionIconsAndSurfacesAlignWithRail() {
    var sidebar = panel.sidebar
    verify(Math.abs(sidebar.collapseIconItem.x + sidebar.collapseIconItem.width / 2
                    - sidebar.width / 2) < 0.1)
    verify(Math.abs(sidebar.backIconItem.x + sidebar.backIconItem.width / 2
                    - sidebar.width / 2) < 0.1)
    verify(sidebar.collapseSurfaceItem.width <= 40)
    verify(sidebar.backSurfaceItem.width <= 40)
}
```

The test should use the expanded sidebar fixture; for the contracted case set `panel.sidebarExpanded = false`, wait for the reduced-motion or settled state, and repeat the center assertions.

- [ ] **Step 3: Add assertions for focus-safe visual state**

Add a test that activates the collapse button and verifies keyboard focus does not create a border:

```qml
function test_collapseFocusDoesNotCreatePersistentFrame() {
    var button = panel.sidebar.collapseButton
    button.forceActiveFocus()
    verify(button.activeFocus)
    compare(panel.sidebar.collapseSurfaceItem.border.width, 0)
    compare(panel.sidebar.collapseSurfaceItem.border.color, "transparent")
}
```

- [ ] **Step 4: Add a shared-progress assertion**

During reduced motion, toggle the panel and assert both action icon positions use the same contracted/expanded state. With normal motion, assert the exposed `expansionProgress` property is the value consumed by the sidebar action bindings rather than a separate action animation property.

- [ ] **Step 5: Run the focused test to establish the expected failure**

Run:

```bash
timeout 20 qs -p tests/qml/tst_lazer_settings_panel.qml
```

Expected: the test may fail at QML startup because `qrc:/qs-blackhole` is unavailable; if so, retain the test and record the environment blocker instead of weakening the assertions.

### Task 2: Separate Full-Width Hit Areas From Compact Visual Surfaces

**Files:**
- Modify: `modules/lazerbar/LazerSettingsSidebar.qml`

**Interfaces:**
- Consumes: `root.width`, `root.expansionProgress`, `MotionTokens.settingsSidebarCollapse`, `HoverHandler`, and `TapHandler`.
- Produces: full-width `collapseButton` and `backButton` with compact `collapseSurface` and `backSurface` children, plus public aliases for tests.

- [ ] **Step 1: Keep both outer action items full width**

Keep the following geometry on both action items:

```qml
x: 0
width: root.width
```

Do not add `Behavior on width` or `Behavior on x` to either action item; their parent sidebar already owns width motion.

- [ ] **Step 2: Add compact visual surfaces**

Replace each action item's full-parent visual `Rectangle` with an inner visual surface:

```qml
Rectangle {
    id: collapseSurface
    x: root.expanded ? 10 : Math.max(0, (root.width - width) / 2)
    width: 40
    height: 40
    color: collapseHover.hovered ? LazerTheme.settingsRowHover : "transparent"
    border.width: 0
    border.color: "transparent"
}
```

Use the same structure for `backSurface`. Prefer an expression driven by `expansionProgress` rather than a boolean jump, for example:

```qml
x: 10 + Math.max(0, (root.width - width) / 2 - 10) * (1 - root.expansionProgress)
```

Tune the expanded baseline to match `LazerSettingsNavItem`'s icon alignment and keep the surface rectangular or minimally detailed according to the sharp design rules.

- [ ] **Step 3: Move icon ownership into the compact surfaces**

Anchor each action icon to its surface center:

```qml
anchors.centerIn: collapseSurface
```

Set both action icon sizes to `20px`, matching category icons. Keep the existing `MultiEffect`, hover colorization, `TapHandler`, and keyboard activation behavior.

- [ ] **Step 4: Add public aliases used by tests**

Expose:

```qml
readonly property alias collapseSurfaceItem: collapseSurface
readonly property alias collapseIconItem: collapseIcon
readonly property alias backSurfaceItem: backSurface
readonly property alias backIconItem: backIcon
```

Keep the existing `collapseButton` and `backButton` aliases unchanged.

### Task 3: Remove Persistent Focus Highlight And Synchronize Motion

**Files:**
- Modify: `modules/lazerbar/LazerSettingsSidebar.qml`
- Modify: `modules/lazerbar/LazerSettingsPanel.qml` only if the final binding needs a named shared progress property

**Interfaces:**
- Consumes: `root.expansionProgress` supplied from `LazerSettingsPanel.collapseProgress`.
- Produces: action surface position and icon geometry that update from the first collapse frame, with no focus-frame persistence.

- [ ] **Step 1: Make hover the only visual background trigger**

For both action surfaces, use:

```qml
color: actionHover.hovered ? LazerTheme.settingsRowHover : "transparent"
border.width: 0
border.color: "transparent"
```

Do not include `activeFocus` in color or border expressions. Retain `activeFocusOnTab`, `forceActiveFocus()`, `Accessible.role`, and keyboard handlers.

- [ ] **Step 2: Drive surface positions from the shared progress**

Use the sidebar's `expansionProgress` to interpolate the compact surface between the expanded alignment and contracted center. Do not use a new `NumberAnimation` on the action item width or position.

- [ ] **Step 3: Verify reduced-motion behavior**

When `MotionTokens.reducedMotion` is enabled, the `expansionProgress` binding must switch directly between `0` and `1`, and the action surfaces must follow immediately without their own animation.

- [ ] **Step 4: Run QML lint and the available tests**

Run:

```bash
qmllint modules/lazerbar/LazerSettingsSidebar.qml modules/lazerbar/LazerSettingsPanel.qml
pytest -q
timeout 12 qs -p .
```

Expected: lint is silent, Python tests pass, and the main config reaches `Configuration Loaded`; the notification registration warning is unrelated.

### Task 4: Final Review And Commit

**Files:**
- Review: `modules/lazerbar/LazerSettingsSidebar.qml`
- Review: `modules/lazerbar/LazerSettingsNavItem.qml`
- Review: `modules/lazerbar/LazerSettingsPanel.qml`
- Review: `tests/qml/tst_lazer_settings_panel.qml`

- [ ] **Step 1: Check the visual contract**

Confirm expanded and contracted states manually or from QML snapshots:

- Both action hit areas span the sidebar width.
- Visual surfaces remain compact and do not become sidebar-wide rounded blocks.
- Both icons are `20px`, centered in their compact surfaces, and aligned with category icons when expanded.
- Contracted icons are centered in the contracted sidebar.
- Hover feedback works; focus alone does not create a background or border.
- Collapse motion begins for icons and visual surfaces with the sidebar transition.

- [ ] **Step 2: Run the complete available verification set**

Run:

```bash
git diff --check
qmllint modules/lazerbar/LazerSettingsSidebar.qml modules/lazerbar/LazerSettingsPanel.qml modules/lazerbar/LazerSettingsNavItem.qml tests/qml/tst_lazer_settings_panel.qml
pytest -q
timeout 12 qs -p .
```

- [ ] **Step 3: Commit the implementation**

```bash
git add modules/lazerbar/LazerSettingsSidebar.qml modules/lazerbar/LazerSettingsPanel.qml modules/lazerbar/LazerSettingsNavItem.qml tests/qml/tst_lazer_settings_panel.qml
git commit -m "fix: refine settings sidebar action controls"
```
