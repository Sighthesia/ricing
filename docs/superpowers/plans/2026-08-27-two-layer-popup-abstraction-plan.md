# 双层弹出菜单抽象 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增稳定的双层弹出容器，迁移设置面板使用它，并为 bar 与右键菜单提供可向上或向下复用的方向接口。

**Architecture:** `TwoLayerPopup.qml` 是无业务状态的固定 owner 容器，内部维护 sidebar/content 两个独立 host。横向模式用于设置面板，保留两层现有 x 几何；纵向模式按照 `direction` 将两层从上或下排列。`revealProgress` 只驱动内部透明度与位移，内容层通过 delay 形成 stagger，不改变根尺寸。

**Tech Stack:** QML QtQuick、Afloat `LazerTheme`/`MotionTokens`、QtTest/qmltestrunner。

## Global Constraints

- 根节点固定为 `Item`，不因动画修改自身尺寸。
- 通过 `sidebarData` 和 `contentData` 注入内容，并暴露 `sidebarLayer`、`contentLayer` host。
- `orientation` 支持横向 `Horizontal` 与纵向 `Vertical`；纵向 `direction` 支持 `Up` 与 `Down`。
- 标题层立即进入，主栏使用 `contentDelay` 延迟进入；默认延迟引用 `MotionTokens.settingsContentDelay`。
- 所有动画使用 `MotionTokens`，并受 `MotionTokens.reducedMotion` 门控。
- 组件不处理 pointer 事件、不持有菜单数据、不恢复旧 bar popup 状态机。
- QML 主元素声明前添加简短英文注释；新建文件默认 ASCII。

---

### Task 1: Add TwoLayerPopup and its QtTest

**Files:**
- Create: `modules/lazerbar/TwoLayerPopup.qml`
- Modify: `modules/lazerbar/qmldir`
- Create: `tests/qml/tst_two_layer_popup.qml`

**Interfaces:**
- Consumes: `LazerTheme`, `MotionTokens`。
- Produces: `TwoLayerPopup { orientation, direction, revealProgress, sidebarOffset, contentOffset, contentDelay, horizontalSidebarX, horizontalContentX, sidebarData, contentData, beginReveal(), endReveal() }`。

- [ ] **Step 1: Write the failing QtTest**

```qml
function test_downDirectionStacksSidebarBeforeContent() {
    popup.orientation = Lazer.TwoLayerPopup.Vertical
    popup.direction = Lazer.TwoLayerPopup.Down
    compare(popup.sidebarLayer.y, 0)
    compare(popup.contentLayer.y, popup.sidebarLayer.height + 1)
}

function test_upDirectionStacksContentBeforeSidebar() {
    popup.orientation = Lazer.TwoLayerPopup.Vertical
    popup.direction = Lazer.TwoLayerPopup.Up
    compare(popup.contentLayer.y, 0)
    compare(popup.sidebarLayer.y, popup.contentLayer.height + 1)
}

function test_contentRevealWaitsForDelay() {
    popup.orientation = Lazer.TwoLayerPopup.Vertical
    popup.revealProgress = 0.2
    verify(popup.sidebarRevealProgress > popup.contentRevealProgress)
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_two_layer_popup.qml -o -,txt`

Expected: component/type or property failures because `TwoLayerPopup` does not exist yet.

- [ ] **Step 3: Implement the fixed host and direction geometry**

Use a root `Item` with `sidebarSlot` and `contentSlot`. Expose their `data` aliases, keep the hosts as fixed siblings, and calculate geometry as follows:

```qml
readonly property int Horizontal: 0
readonly property int Vertical: 1
readonly property int Up: 0
readonly property int Down: 1
property int orientation: TwoLayerPopup.Horizontal
property int direction: TwoLayerPopup.Down
property real revealProgress: 1
property int contentDelay: MotionTokens.settingsContentDelay
readonly property real sidebarRevealProgress: root.revealProgress
readonly property real contentRevealProgress: root.contentDelay <= 0
    ? root.revealProgress
    : Math.max(0, Math.min(1, (root.revealProgress - root.contentDelay / root.revealDuration)
        / (1 - root.contentDelay / root.revealDuration)))
```

Use `Translate` on each host for the configured offset, `opacity` for reveal, `clip: true` only on the root, and keep `horizontalSidebarX`/`horizontalContentX` explicit so `LazerSettingsPanel` can preserve its current owner positions. `beginReveal()` sets progress to `1`; `endReveal()` sets it to `0`. Reduced motion binds both reveal progresses directly to `revealProgress` and removes transition animation.

- [ ] **Step 4: Register the component and run the focused test**

Add `TwoLayerPopup 1.0 TwoLayerPopup.qml` to `modules/lazerbar/qmldir`, then run the qmltestrunner command above. Expected: PASS with no `FAIL!`, `WARN`, or `ERROR` lines.

- [ ] **Step 5: Commit the component and test**

```bash
git add modules/lazerbar/TwoLayerPopup.qml modules/lazerbar/qmldir tests/qml/tst_two_layer_popup.qml
git commit -m "feat(lazer): add reusable two-layer popup container"
```

---

### Task 2: Migrate LazerSettingsPanel to the shared hosts

**Files:**
- Modify: `modules/lazerbar/LazerSettingsPanel.qml:213-289`
- Test: `tests/qml/tst_lazer_settings_panel.qml`

**Interfaces:**
- Consumes: `TwoLayerPopup` horizontal mode and its `sidebarData`/`contentData` aliases。
- Preserves: `panel.sidebar`, `panel.content`, `panel.sections`, navigation aliases, focus, signal, z-order and current width calculations。

- [ ] **Step 1: Add a regression assertion for shared ownership**

Extend the existing `LazerSettingsPanel` test with:

```qml
function test_usesSharedTwoLayerPopupGeometry() {
    compare(panel.sidebar.parent, panel.layerPopup.sidebarLayer)
    compare(panel.content.parent, panel.layerPopup.contentLayer)
    compare(panel.sidebar.x, panel.sidebarLayerX)
    compare(panel.content.x, panel.contentLayerX)
}
```

- [ ] **Step 2: Migrate the two layer declarations**

Create a `TwoLayerPopup` named `layerPopup` before the existing sidebar/content declarations. Set `orientation: TwoLayerPopup.Horizontal`, `revealProgress: root.progress`, and bind `horizontalSidebarX`/`horizontalContentX` to the existing calculated values. Put `LazerSettingsSidebar` and `LazerSettingsContent` into the corresponding data aliases, preserving their existing properties and handlers. Keep the existing `z: 1` on the sidebar host and `z: 0` on the content host.

- [ ] **Step 3: Update panel aliases and debug snapshots**

Point `appearanceNav`, `barNav`, `notificationNav`, `searchField`, `sidebar`, `content`, and `sections` at the same live objects. Update `debugSnapshot()` to report the shared hosts while leaving public result keys unchanged.

- [ ] **Step 4: Run the panel regression test and lint**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_settings_panel.qml -o -,txt`

Run: `/usr/lib/qt6/bin/qmllint modules/lazerbar/TwoLayerPopup.qml modules/lazerbar/LazerSettingsPanel.qml`

Expected: existing tests pass; no new QML errors or warnings.

- [ ] **Step 5: Commit the migration**

```bash
git add modules/lazerbar/LazerSettingsPanel.qml tests/qml/tst_lazer_settings_panel.qml
git commit -m "refactor(lazer): route settings panel through two-layer popup"
```

---

### Task 3: Verify reusable vertical API and repository health

**Files:**
- Modify: `tests/qml/tst_two_layer_popup.qml` only if test coverage needs correction。

- [ ] **Step 1: Cover reduced motion and lifecycle methods**

Add tests that set `Lazer.MotionTokens.reducedMotionOverride = true`, call `popup.endReveal()` and `popup.beginReveal()`, and compare both reveal progress properties with `0` and `1` respectively. Restore the override in `cleanup()`.

- [ ] **Step 2: Run all focused validation**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_two_layer_popup.qml -o -,txt`

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_settings_panel.qml -o -,txt`

Run: `/usr/lib/qt6/bin/qmllint modules/lazerbar/TwoLayerPopup.qml modules/lazerbar/LazerSettingsPanel.qml`

Run: `git diff --check`

Expected: zero test failures, no QML `ERROR`/`WARN`, and clean diff check. `qs -p shell.qml` is not a QtTest runner; only use it as an additional load smoke check if the local compositor session is available.

- [ ] **Step 3: Commit verification-only test changes**

```bash
git add tests/qml/tst_two_layer_popup.qml
git commit -m "test(lazer): cover two-layer popup directions and motion"
```

## Self-Review

- Spec coverage: component API, horizontal settings migration, vertical Up/Down geometry, stagger, reduced-motion, tests and lint are covered by Tasks 1-3.
- Placeholder scan: no TBD/TODO or unspecified implementation step remains.
- Type consistency: `sidebarData`/`contentData`, host aliases, constants and lifecycle methods are named consistently across all tasks.
- Scope check: no old bar popup files or service state machines are restored or modified.
