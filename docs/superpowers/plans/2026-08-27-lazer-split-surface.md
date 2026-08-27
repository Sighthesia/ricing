# Lazer Split Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make settings and bar popups reveal two independently animated background surfaces, with content moving together with the second surface.

**Architecture:** Add `LazerSplitSurface.qml` as the shared owner of header surface, divider, content surface, progress splitting, and interaction gating. `BarPopupFrame` becomes the titled adapter around it; tray/context menus use the shared surface directly or through the adapter. `LazerSettingsPanel` adopts the same surface contract without changing its navigation and scrolling ownership.

**Tech Stack:** Quickshell, QtQuick/QML, `MotionTokens`, `LazerTheme`, Qt6 `qmllint`, `qmltestrunner`, `qs`.

## Global Constraints

- Major surfaces remain sharp rectangular surfaces with `radius: 0`; rounded corners are limited to controls and icons.
- All durations, easing, offsets, and reduced-motion behavior use `MotionTokens`.
- The outer Loader/layer-shell geometry remains fixed during reveal; only inner owner layers animate.
- Content is mounted inside `contentSurface`, not directly on the root shell.
- QML changes require relevant `qmllint`, QML tests, and `qs -p` verification with no WARN/ERROR output.
- Each completed functional change is committed with a conventional commit message.

---

### Task 1: Build the shared split surface

**Files:**
- Create: `modules/lazerbar/LazerSplitSurface.qml`
- Modify: `modules/lazerbar/qmldir`
- Test: `tests/qml/tst_lazer_split_surface.qml`

**Interfaces:**
- Consumes: `revealProgress`, `interactive`, `headerHeight`, `contentColor`, and default `contentData`.
- Produces: `headerSurfaceItem`, `contentSurfaceItem`, `dividerItem`, `headerProgress`, `contentProgress`, `interactable`.

- [ ] **Step 1: Add the QML logic test for progress and ownership contracts**

Test the pure timing contract through a small QML harness or exposed read-only properties: progress `0` hides both layers, progress `1` shows both layers, content progress starts after the configured delay, and content children are parented below `contentSurfaceItem`.

- [ ] **Step 2: Run the new test before implementation**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_split_surface.qml -o -,txt`

Expected: FAIL because `LazerSplitSurface` and its contract do not exist yet.

- [ ] **Step 3: Implement the shared component**

Use the existing `BarPopupMotion.js` functions and expose the following structure:

```qml
property real revealProgress: 0
property bool interactive: true
property int headerHeight: 48
property color contentColor: LazerTheme.settingsPanel
readonly property real headerProgress: PopupMotion.headerProgress(...)
readonly property real contentProgress: PopupMotion.contentProgress(...)
readonly property bool interactable: interactive && contentProgress > 0.99
default property alias contentData: contentSurface.data
readonly property alias headerSurfaceItem: headerSurface
readonly property alias contentSurfaceItem: contentSurface
readonly property alias dividerItem: divider
```

Create sibling `Rectangle` elements for header, divider, and content. Apply opacity and `Translate` independently to header/content, and keep `contentSurface` sized by its children. Use `enabled: root.interactable` for the content layer. Add brief English comments before each major declaration.

- [ ] **Step 4: Register and run the test**

Run the qmltestrunner command from Step 2 and then:

```bash
qmllint modules/lazerbar/LazerSplitSurface.qml
```

Expected: PASS with no QML warnings or errors.

- [ ] **Step 5: Commit the shared component**

```bash
git add modules/lazerbar/LazerSplitSurface.qml modules/lazerbar/qmldir tests/qml/tst_lazer_split_surface.qml
git commit -m "feat(lazerbar): add reusable split surface"
```

### Task 2: Migrate BarPopupFrame and simple popups

**Files:**
- Modify: `modules/bar/BarPopupFrame.qml`
- Modify: `modules/bar/BarSliderPopup.qml`
- Modify: `modules/bar/BarCalendarPopup.qml`
- Modify: `modules/bar/BarMediaPopup.qml`
- Modify: `modules/bar/BarNotificationsPopup.qml`
- Test: `tests/qml/tst_bar_popup_frame.qml` if present, otherwise a focused `qmllint`/`qs` harness

**Interfaces:**
- Consumes: `LazerSplitSurface.contentData` and the existing title/icon/extra text properties.
- Produces: unchanged popup properties and aliases used by `BarPopupHost`.

- [ ] **Step 1: Replace the duplicated frame surfaces with `LazerSplitSurface`**

Make `BarPopupFrame` use the shared component as its root or direct visual owner. Keep title content in `headerSurfaceItem` and popup children in `contentSurfaceItem`. Preserve `implicitWidth`, `implicitHeight`, `contentItem`, `headerCard`, and `revealProgress` compatibility for existing callers.

- [ ] **Step 2: Keep simple popup content anchored to the content surface**

Update the four simple popup columns so their anchors target `contentSurfaceItem`, with margins inside that card. Do not add a second background or independent animation in these consumers.

- [ ] **Step 3: Run validation**

Run:

```bash
qmllint modules/bar/BarPopupFrame.qml modules/bar/BarSliderPopup.qml modules/bar/BarCalendarPopup.qml modules/bar/BarMediaPopup.qml modules/bar/BarNotificationsPopup.qml
qs -p .
```

Expected: no WARN/ERROR output and all popup backgrounds participate in reveal.

- [ ] **Step 4: Commit the frame migration**

```bash
git add modules/bar/BarPopupFrame.qml modules/bar/BarSliderPopup.qml modules/bar/BarCalendarPopup.qml modules/bar/BarMediaPopup.qml modules/bar/BarNotificationsPopup.qml
git commit -m "fix(bar): animate popup backgrounds with shared surface"
```

### Task 3: Migrate tray and context menus

**Files:**
- Modify: `modules/bar/BarTrayMenu.qml`
- Modify: `modules/bar/BarContextMenu.qml`
- Modify: `modules/bar/BarPopupHost.qml` only if the shared progress alias requires an adapter

**Interfaces:**
- Consumes: `LazerSplitSurface.revealProgress`, `contentSurfaceItem`, and `interactable`.
- Produces: existing `submenuSurfaceItem`, `submenuBridgeItem`, menu callbacks, and settings actions.

- [ ] **Step 1: Move menu content into the shared content owner**

Remove local background/progress layers that duplicate the shared frame. Mount tray rows, submenu content, context rail, and context actions beneath `contentSurfaceItem`; preserve the submenu geometry aliases consumed by the host.

- [ ] **Step 2: Preserve menu-specific layer relationships**

Keep submenu and bridge above the content surface where required for pointer traversal. Ensure menu catchers use the existing non-starving input behavior and are disabled when `interactable` is false.

- [ ] **Step 3: Validate menu loading and reveal**

Run:

```bash
qmllint modules/bar/BarTrayMenu.qml modules/bar/BarContextMenu.qml modules/bar/BarPopupHost.qml
qs -p .
```

Expected: tray/context menus load without warnings, background colors reveal and retreat with their content, and submenu pointer transitions remain functional.

- [ ] **Step 4: Commit menu migration**

```bash
git add modules/bar/BarTrayMenu.qml modules/bar/BarContextMenu.qml modules/bar/BarPopupHost.qml
git commit -m "fix(bar): reuse split surface for menus"
```

### Task 4: Adopt the shared surface in settings

**Files:**
- Modify: `modules/lazerbar/LazerSettingsPanel.qml`
- Modify: `modules/lazerbar/LazerSettingsSidebar.qml` only if required to expose its surface through the shared owner
- Modify: `modules/lazerbar/LazerSettingsContent.qml` only if required to mount content below `contentSurface`

**Interfaces:**
- Consumes: current `sidebarLayerX`, `contentLayerX`, `progress`, `sidebarWidth`, and `contentWidth` geometry contracts.
- Produces: unchanged `sidebar`, `content`, `sections`, nav aliases, search aliases, and settings behavior.

- [ ] **Step 1: Wrap existing settings owners with the shared layer contract**

Use `LazerSplitSurface` for the settings panel’s background ownership while leaving `LazerSettingsSidebar` and `LazerSettingsContent` as functional children. Preserve the current independently translated sidebar/content layers and prevent the new wrapper from changing panel width or height.

- [ ] **Step 2: Map the existing progress to the shared surface**

Bind the shared `revealProgress` to `root.progress`; do not introduce a second settings state machine. Keep the existing collapse and category scroll behavior unchanged.

- [ ] **Step 3: Run settings tests and harness**

Run:

```bash
qmllint modules/lazerbar/LazerSplitSurface.qml modules/lazerbar/LazerSettingsPanel.qml modules/lazerbar/LazerSettingsSidebar.qml modules/lazerbar/LazerSettingsContent.qml
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_settings_logic.qml -o -,txt
qs -p .
```

Expected: existing settings navigation, search, scrolling, focus, and sidebar collapse behavior remain intact with no warnings.

- [ ] **Step 4: Commit settings adoption**

```bash
git add modules/lazerbar/LazerSettingsPanel.qml modules/lazerbar/LazerSettingsSidebar.qml modules/lazerbar/LazerSettingsContent.qml
git commit -m "refactor(settings): share split surface ownership"
```

### Task 5: Full verification and cleanup

**Files:**
- Modify: only files required by verification failures
- Test: all affected QML test files and root harnesses

- [ ] **Step 1: Check the complete changed surface**

Run `git diff --check` and inspect `git status --short`; leave unrelated worktree changes untouched.

- [ ] **Step 2: Run focused QML validation**

Run `qmllint` across every modified QML file and execute the focused popup/settings qmltestrunner inputs. Fix every WARN/ERROR before proceeding.

- [ ] **Step 3: Run the shell harness**

Run `qs -p .` from the repository root. Confirm popup open, close, content swap, reduced-motion, and settings-panel startup produce no load or binding errors.

- [ ] **Step 4: Commit verification fixes**

```bash
git add <only-files-fixed-by-verification>
git commit -m "fix(bar): resolve split surface validation issues"
```

## Self-Review

- Spec coverage: shared component, independent layer animation, content ownership, settings adoption, popup migration, fixed host geometry, reduced-motion, and verification are covered by Tasks 1-5.
- Placeholder scan: no `TBD`, `TODO`, or unspecified implementation step is required.
- Interface consistency: `revealProgress`, `contentData`, `contentSurfaceItem`, `headerSurfaceItem`, `headerProgress`, `contentProgress`, and `interactable` are introduced in Task 1 and consumed consistently later.
