# Lazer Top Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a multi-screen Quickshell top bar inspired by osu!lazer with bundled icons, real system uptime, coherent motion, accessible keyboard interaction, and reusable menu/modal primitives.

**Architecture:** Each screen receives one full-width layer-shell background that reserves 46px plus three content-width interactive windows for left, utility, and status zones. Focused QML components own visual and keyboard behavior, while a pure JS module owns deterministic formatting, responsive ordering, state composition, and anchor math for fast tests.

**Tech Stack:** Quickshell, Qt 6, QtQuick/QML, QtTest, Quickshell.Wayland, pure QML JavaScript, bundled SVG.

## Global Constraints

- Work on branch `lazer`, created from `backend-only`.
- Use Qt 6-compatible Quickshell/QML; do not introduce React, CSS, Tailwind, or icon-font dependencies.
- Use only the base durations 70/100/160/240/320ms, except the explicitly approved 120ms overlay-backdrop entrance.
- Use cubic-bezier `(0.22, 1, 0.36, 1)` as the primary easing; expose all four approved easing curves as centralized tokens.
- Hover uses background/foreground brightening plus scale `1.015` over 100ms.
- Press uses scale `0.985` plus Y offset `1px` over 70ms; release returns over 100ms.
- Dropdown opens with opacity `0 -> 1`, Y `-4 -> 0`, and scale `0.98 -> 1` over 160ms; close reverses over 100ms after interaction is disabled.
- Overlay backdrop enters over 120ms to opacity `0.55`; panel enters over 240ms and exits over 160ms; backdrop exits over 100ms.
- Reduced motion removes scale, translation, indicator sliding, and shadow-depth animation while retaining opacity and color feedback.
- All controls support `rest`, `hover`, `pressed`, `active`, and `disabled`; `active` is a persistent base state, `hover`/`pressed` layer over it, and `disabled` overrides them.
- Support Tab, Shift+Tab, Enter, Space, Escape, and Arrow navigation as specified.
- Use original generic bundled SVG icons, not copied osu! assets.
- Add a short English intent comment before major `Variants`, `Item`, `PanelWindow`, and reusable visual-component declarations.
- Use `implicitWidth` and `implicitHeight` for layer-shell `PanelWindow` sizing.
- After every QML change, run the relevant QML test and resolve all WARN/ERROR output before committing.
- Never stage or modify the unrelated untracked `docs/image.png` unless explicitly requested.

---

## File Map

- `shell.qml`: application entry point; mounts the multi-screen top bar.
- `modules/lazerbar/qmldir`: registers theme/motion singletons and reusable module types.
- `modules/lazerbar/LazerTheme.qml`: colors, typography, geometry, and dark-theme contrast tokens.
- `modules/lazerbar/MotionTokens.qml`: durations, easing curves, transform values, backdrop values, and reduced-motion override.
- `modules/lazerbar/LazerBarLogic.js`: uptime formatting, utility priorities, responsive visibility, fallback initials, state composition, and popup-origin math.
- `modules/lazerbar/IconButton.qml`: complete pointer/keyboard/focus state machine and icon tint surface.
- `modules/lazerbar/ModeSelector.qml`: four modes, Arrow navigation, and one persistent sliding indicator.
- `modules/lazerbar/MenuItem.qml`: reusable menu-row state and keyboard-facing properties.
- `modules/lazerbar/DropdownMenu.qml`: anchored single-level menu and lifecycle state.
- `modules/lazerbar/ContextMenu.qml`: context-positioned menu wrapper with screen clamping.
- `modules/lazerbar/ModalOverlay.qml`: focus-contained modal surface and asymmetric entrance/exit.
- `modules/lazerbar/ClockWidget.qml`: local clock and `/proc/uptime` reader.
- `modules/lazerbar/UserProfile.qml`: username, avatar, and local fallback.
- `modules/lazerbar/LeftZone.qml`: settings, home, and mode selector content.
- `modules/lazerbar/UtilityZone.qml`: priority-driven responsive utility content.
- `modules/lazerbar/StatusZone.qml`: profile, clock, and bell content.
- `modules/lazerbar/BarBackground.qml`: full-width exclusive-zone owner.
- `modules/lazerbar/TopBar.qml`: coordinates one background plus three interactive windows for one screen.
- `modules/lazerbar/icons/*.svg`: bundled monochrome and multicolor generic icons.
- `tests/qml/tst_lazer_bar_logic.qml`: pure helper tests.
- `tests/qml/tst_lazer_icon_button.qml`: button state and reduced-motion tests.
- `tests/qml/tst_lazer_mode_selector.qml`: mode navigation and persistent indicator tests.
- `tests/qml/tst_lazer_popups.qml`: dropdown, context menu, and modal lifecycle/focus tests.

---

### Task 1: Pure Logic And Token Foundation

**Files:**
- Create: `modules/lazerbar/qmldir`
- Create: `modules/lazerbar/LazerTheme.qml`
- Create: `modules/lazerbar/MotionTokens.qml`
- Create: `modules/lazerbar/LazerBarLogic.js`
- Create: `tests/qml/tst_lazer_bar_logic.qml`

**Interfaces:**
- Produces: `LazerBarLogic.formatDuration(seconds): string`
- Produces: `LazerBarLogic.parseUptime(text): number`
- Produces: `LazerBarLogic.fallbackInitial(username): string`
- Produces: `LazerBarLogic.visibleUtilityIds(availableWidth, itemWidth, spacing): string[]`
- Produces: `LazerBarLogic.visualState(enabled, active, hovered, pressed): string`
- Produces: `LazerBarLogic.popupOrigin(anchorCenterX, popupWidth, screenWidth): string`
- Produces: singleton properties `LazerTheme.*` and `MotionTokens.*` consumed by every later QML task.

- [ ] **Step 1: Write failing pure-logic tests**

Create `tests/qml/tst_lazer_bar_logic.qml` with QtTest cases that assert:

```qml
compare(Logic.formatDuration(0), "00:00:00")
compare(Logic.formatDuration(3661), "01:01:01")
compare(Logic.formatDuration(360005), "100:00:05")
compare(Logic.parseUptime("9876.54 1234.00\n"), 9876)
compare(Logic.parseUptime("not uptime"), -1)
compare(Logic.fallbackInitial(" Sighthesia "), "S")
compare(Logic.fallbackInitial(""), "?")
compare(Logic.visualState(true, true, true, true), "activePressed")
compare(Logic.visualState(false, true, true, true), "disabled")
compare(Logic.popupOrigin(40, 220, 1920), "topLeft")
compare(Logic.popupOrigin(1880, 220, 1920), "topRight")
compare(Logic.visibleUtilityIds(32, 32, 12), ["music"])
compare(Logic.visibleUtilityIds(340, 32, 12), ["news", "changelog", "wiki", "ranking", "library", "chat", "community", "music"])
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `qs -p tests/qml/tst_lazer_bar_logic.qml`

Expected: FAIL because `modules/lazerbar/LazerBarLogic.js` does not exist.

- [ ] **Step 3: Implement deterministic helpers**

Create `LazerBarLogic.js` as a pure module. Use this fixed utility priority order:

```javascript
var utilityOrder = ["news", "changelog", "wiki", "ranking", "library", "chat", "community", "music"]
var removalOrder = ["community", "chat", "ranking", "wiki", "changelog", "news", "library"]
```

`visibleUtilityIds()` must always retain `music`, remove entries in `removalOrder`, and return survivors in `utilityOrder`. `formatDuration()` floors finite non-negative seconds and allows hours above 99. `parseUptime()` parses the first whitespace-delimited `/proc/uptime` field or returns `-1`.

- [ ] **Step 4: Implement centralized QML tokens**

Register singleton types in `modules/lazerbar/qmldir`:

```text
module Afloat.LazerBar
singleton LazerTheme 1.0 LazerTheme.qml
singleton MotionTokens 1.0 MotionTokens.qml
```

`LazerTheme.qml` must expose exact requested colors, 46px height, 12px bottom radius, 20px icon size, 32px target size, high-contrast text colors, hover fills, active fills, and focus-ring values.

`MotionTokens.qml` must expose `instant: 70`, `fast: 100`, `medium: 160`, `slow: 240`, `page: 320`, `backdropEnter: 120`, all approved easing splines, all approved scale/translation/opacity constants, and writable `reducedMotionOverride: bool` for deterministic tests. A read-only `reducedMotion` resolves to the platform preference when safely available, otherwise the override/default `false`.

- [ ] **Step 5: Run logic tests until clean**

Run: `qs -p tests/qml/tst_lazer_bar_logic.qml`

Expected: PASS with no WARN or ERROR lines.

- [ ] **Step 6: Commit the foundation**

```bash
git add modules/lazerbar/qmldir modules/lazerbar/LazerTheme.qml modules/lazerbar/MotionTokens.qml modules/lazerbar/LazerBarLogic.js tests/qml/tst_lazer_bar_logic.qml
git commit -m "feat: add lazer bar tokens and logic"
```

---

### Task 2: Icon Button State Machine

**Files:**
- Create: `modules/lazerbar/IconButton.qml`
- Create: `tests/qml/tst_lazer_icon_button.qml`
- Modify: `modules/lazerbar/qmldir`

**Interfaces:**
- Consumes: `LazerTheme`, `MotionTokens`, `LazerBarLogic.visualState()`.
- Produces: `IconButton` properties `source`, `accessibleName`, `active`, `enabled`, `supportsHover`, `buttonState`, `foregroundColor`, `backgroundColor`.
- Produces: `IconButton.clicked()` and `IconButton.keyboardActivated()` signals.
- Produces: `IconButton.forceHoverForTest` and `forcePressForTest` test-only overrides, default `false` and inactive unless `testMode` is true.

- [ ] **Step 1: Write failing component tests**

Create a QtTest component test that instantiates `IconButton` and verifies:

```qml
compare(button.buttonState, "rest")
button.active = true
compare(button.buttonState, "active")
button.testMode = true
button.forceHoverForTest = true
compare(button.buttonState, "activeHover")
button.forcePressForTest = true
compare(button.buttonState, "activePressed")
button.enabled = false
compare(button.buttonState, "disabled")
compare(button.effectiveScale, 1.0)
```

Add a second test that enables `MotionTokens.reducedMotionOverride`, presses the button, and compares `effectiveScale === 1.0` and `effectiveYOffset === 0` while foreground/background color still change.

- [ ] **Step 2: Run the test and verify it fails**

Run: `qs -p tests/qml/tst_lazer_icon_button.qml`

Expected: FAIL because `IconButton` is not registered.

- [ ] **Step 3: Implement pointer and keyboard states**

Implement `IconButton` as a focusable `Item` with a rounded background, a tintable icon mask, `HoverHandler`, `TapHandler`, and inner key handling. Ensure:

- Hover transforms only when `supportsHover` is true.
- `active` remains visible under hover and press.
- Disabled blocks pointer and keyboard activation and uses opacity `0.45`.
- Enter and Space produce the same activation signal as pointer release.
- Focus ring is visible and uses both outline and color.
- Scale and Y offset use interruptible `Behavior`s with 70ms press and 100ms release selection.
- Color transitions use 100ms for hover and 160ms when `active` changes.
- The icon source remains one persistent visual item across states.

- [ ] **Step 4: Register and run the component test**

Add `IconButton 1.0 IconButton.qml` to `modules/lazerbar/qmldir`.

Run: `qs -p tests/qml/tst_lazer_icon_button.qml`

Expected: PASS with no WARN or ERROR lines.

- [ ] **Step 5: Commit the state machine**

```bash
git add modules/lazerbar/IconButton.qml modules/lazerbar/qmldir tests/qml/tst_lazer_icon_button.qml
git commit -m "feat: add lazer icon button states"
```

---

### Task 3: Mode Selector And Sliding Indicator

**Files:**
- Create: `modules/lazerbar/ModeSelector.qml`
- Create: `tests/qml/tst_lazer_mode_selector.qml`
- Modify: `modules/lazerbar/qmldir`

**Interfaces:**
- Consumes: `IconButton`, `LazerTheme`, `MotionTokens`.
- Produces: `ModeSelector.selectedMode: string`, one of `osu`, `taiko`, `catch`, `mania`.
- Produces: `ModeSelector.selectedIndex: int`, `indicatorItem: Item`, and `modeSelected(mode: string)`.
- Expects icon URLs through properties `osuSource`, `taikoSource`, `catchSource`, `maniaSource` so tests can instantiate without production assets.

- [ ] **Step 1: Write failing selector tests**

Test default state, direct activation, and keyboard navigation:

```qml
compare(selector.selectedMode, "osu")
compare(selector.selectedIndex, 0)
selector.activateIndex(2)
compare(selector.selectedMode, "catch")
var indicator = selector.indicatorItem
selector.activateIndex(3)
compare(selector.indicatorItem, indicator)
compare(selector.indicatorTargetX, selector.slotX(3))
selector.moveSelection(-1)
compare(selector.selectedMode, "catch")
```

Also verify reduced motion makes `indicatorX === indicatorTargetX` without a running positional animation.

- [ ] **Step 2: Run the test and verify it fails**

Run: `qs -p tests/qml/tst_lazer_mode_selector.qml`

Expected: FAIL because `ModeSelector` does not exist.

- [ ] **Step 3: Implement selector and persistent indicator**

Use four persistent `IconButton` instances and one persistent white indicator rectangle. Active foreground is `#00FFA2`; inactive foreground is `#A0A0A0`. The indicator animates X over 160ms with `outStd`, but snaps under reduced motion. Left/Right arrows wrap across four modes; Enter/Space activates the focused mode without replaying scale on Arrow navigation.

- [ ] **Step 4: Register and run selector tests**

Add `ModeSelector 1.0 ModeSelector.qml` to `qmldir`.

Run: `qs -p tests/qml/tst_lazer_mode_selector.qml`

Expected: PASS with no WARN or ERROR lines.

- [ ] **Step 5: Commit mode selection**

```bash
git add modules/lazerbar/ModeSelector.qml modules/lazerbar/qmldir tests/qml/tst_lazer_mode_selector.qml
git commit -m "feat: add lazer mode selector"
```

---

### Task 4: Reusable Dropdown And Context Menus

**Files:**
- Create: `modules/lazerbar/MenuItem.qml`
- Create: `modules/lazerbar/DropdownMenu.qml`
- Create: `modules/lazerbar/ContextMenu.qml`
- Create: `tests/qml/tst_lazer_popups.qml`
- Modify: `modules/lazerbar/qmldir`

**Interfaces:**
- Consumes: `LazerTheme`, `MotionTokens`, `LazerBarLogic.popupOrigin()`.
- Produces: `DropdownMenu.model`, `openAt(anchorItem)`, `closeAndRestoreFocus()`, `phase`, `currentIndex`, `interactive`, `originName`.
- Produces: `ContextMenu.openAtPoint(point, availableRect)`, clamped `popupX`, `popupY`, and inherited menu lifecycle.
- Produces: menu signals `triggered(index, entry)` and `closed()`.

- [ ] **Step 1: Add failing popup lifecycle tests**

Extend `tst_lazer_popups.qml` with a test host and assert:

```qml
dropdown.openAt(opener)
compare(dropdown.phase, "opening")
tryCompare(dropdown, "phase", "open", 250)
compare(dropdown.interactive, true)
dropdown.closeAndRestoreFocus()
compare(dropdown.interactive, false)
compare(dropdown.phase, "closing")
tryCompare(dropdown, "phase", "closed", 180)
```

Assert `openFromScale === 0.98`, `openFromY === -4`, open duration 160, close duration 100, top-left/top-right origin resolution, screen clamping, Arrow wrap, Enter activation, Escape close, and opener focus restoration.

- [ ] **Step 2: Run popup tests and verify failure**

Run: `qs -p tests/qml/tst_lazer_popups.qml`

Expected: FAIL because menu types do not exist.

- [ ] **Step 3: Implement `MenuItem` and `DropdownMenu`**

Use one persistent clipped popup surface and a lifecycle enum/string `closed/opening/open/closing`. Set `interactive = false` synchronously before starting close. Animate only opacity and transforms; apply shadow-depth change through a lightweight QtQuick shadow/effect only when reduced motion is off. Set the transform origin from the resolved anchor-facing top corner. Menu-item hover fill must be 6%-10% white, while shortcut text remains muted.

Implement Tab containment inside an open menu, Up/Down wrapping, Enter/Space activation, and Escape focus restoration.

- [ ] **Step 4: Implement `ContextMenu` as shared behavior**

Reuse the same menu content and lifecycle rather than duplicating menu item logic. Position from the supplied point, clamp to `availableRect`, and resolve the nearest top-corner origin. Do not implement cascading submenus.

- [ ] **Step 5: Register and run popup tests**

Register all three types and run:

`qs -p tests/qml/tst_lazer_popups.qml`

Expected: menu tests PASS with no WARN or ERROR lines.

- [ ] **Step 6: Commit menus**

```bash
git add modules/lazerbar/MenuItem.qml modules/lazerbar/DropdownMenu.qml modules/lazerbar/ContextMenu.qml modules/lazerbar/qmldir tests/qml/tst_lazer_popups.qml
git commit -m "feat: add lazer menu primitives"
```

---

### Task 5: Modal Overlay And Focus Containment

**Files:**
- Create: `modules/lazerbar/ModalOverlay.qml`
- Modify: `tests/qml/tst_lazer_popups.qml`
- Modify: `modules/lazerbar/qmldir`

**Interfaces:**
- Consumes: `LazerTheme`, `MotionTokens`.
- Produces: `ModalOverlay.openFrom(opener)`, `closeAndRestoreFocus()`, `phase`, `interactive`, `backdropOpacity`, `panelProgress`.
- Provides: default `content` property for modal body.

- [ ] **Step 1: Add failing modal tests**

Add tests that verify:

```qml
modal.openFrom(opener)
compare(modal.phase, "opening")
compare(modal.backdropTargetOpacity, 0.55)
compare(modal.backdropEnterDuration, 120)
compare(modal.panelEnterDuration, 240)
tryCompare(modal, "phase", "open", 340)
modal.closeAndRestoreFocus()
compare(modal.interactive, false)
compare(modal.panelExitDuration, 160)
compare(modal.backdropExitDuration, 100)
```

Add two focusable children and assert Tab/Shift+Tab cycle inside the modal, Escape closes, and focus returns to the opener. Add reduced-motion assertions for zero Y/scale movement with opacity still transitioning.

- [ ] **Step 2: Run tests and verify the modal cases fail**

Run: `qs -p tests/qml/tst_lazer_popups.qml`

Expected: FAIL because `ModalOverlay` is absent.

- [ ] **Step 3: Implement modal lifecycle and motion**

Use one persistent backdrop and one persistent centered panel. Enter backdrop from 0 to 0.55 over 120ms; enter panel opacity 0 to 1, Y 8 to 0, and scale 0.985 to 1 over 240ms. Exit panel over 160ms and backdrop over 100ms. Disable content and outside-pointer actions synchronously when closing begins. Keep the overlay surface present through the exit and hide it only after both exit animations complete.

- [ ] **Step 4: Register and run all popup tests**

Add `ModalOverlay 1.0 ModalOverlay.qml` to `qmldir`.

Run: `qs -p tests/qml/tst_lazer_popups.qml`

Expected: PASS with no WARN or ERROR lines.

- [ ] **Step 5: Commit modal behavior**

```bash
git add modules/lazerbar/ModalOverlay.qml modules/lazerbar/qmldir tests/qml/tst_lazer_popups.qml
git commit -m "feat: add lazer modal overlay"
```

---

### Task 6: Bundled Icon Asset Set

**Files:**
- Create: `modules/lazerbar/icons/settings.svg`
- Create: `modules/lazerbar/icons/home.svg`
- Create: `modules/lazerbar/icons/mode-osu.svg`
- Create: `modules/lazerbar/icons/mode-taiko.svg`
- Create: `modules/lazerbar/icons/mode-catch.svg`
- Create: `modules/lazerbar/icons/mode-mania.svg`
- Create: `modules/lazerbar/icons/news.svg`
- Create: `modules/lazerbar/icons/code.svg`
- Create: `modules/lazerbar/icons/book.svg`
- Create: `modules/lazerbar/icons/podium.svg`
- Create: `modules/lazerbar/icons/library.svg`
- Create: `modules/lazerbar/icons/chat.svg`
- Create: `modules/lazerbar/icons/globe.svg`
- Create: `modules/lazerbar/icons/music.svg`
- Create: `modules/lazerbar/icons/clock.svg`
- Create: `modules/lazerbar/icons/bell.svg`

**Interfaces:**
- Consumed by: zone components and `IconButton.source`.
- Constraint: all icons use a 24x24 viewBox and mask-compatible opaque geometry; `clock.svg` may preserve a separate pink hand only if `ClockWidget` renders it as a dedicated layer.

- [ ] **Step 1: Create original 24x24 generic SVG geometry**

Draw consistent rounded-stroke icons with no external references, embedded fonts, filters, or copied osu! paths. Encode all single-color assets in opaque white for runtime masking. Use simple semantic geometry for the four modes: circle, drum, three fruit dots, and key bars.

- [ ] **Step 2: Validate every SVG**

Run: `xmllint --noout modules/lazerbar/icons/*.svg`

Expected: exit 0 for all 16 files.

- [ ] **Step 3: Add an icon-loading smoke test**

Extend `tst_lazer_icon_button.qml` to instantiate each source in a data-driven test and wait until the image/mask reports ready. The test must fail on a missing or malformed resource.

- [ ] **Step 4: Run the icon-button test**

Run: `qs -p tests/qml/tst_lazer_icon_button.qml`

Expected: PASS with no WARN or ERROR lines.

- [ ] **Step 5: Commit icon assets**

```bash
git add modules/lazerbar/icons tests/qml/tst_lazer_icon_button.qml
git commit -m "feat: add lazer bar icon assets"
```

---

### Task 7: Clock And User Profile

**Files:**
- Create: `modules/lazerbar/ClockWidget.qml`
- Create: `modules/lazerbar/UserProfile.qml`
- Create: `tests/qml/tst_lazer_status_widgets.qml`
- Modify: `modules/lazerbar/qmldir`

**Interfaces:**
- Consumes: `LazerTheme`, `LazerBarLogic.formatDuration()`, `LazerBarLogic.parseUptime()`.
- Produces: `ClockWidget.currentTimeText`, `uptimeText`, `refresh()`.
- Produces: `UserProfile.username`, `avatarSource`, `fallbackText`, `avatarReady`.

- [ ] **Step 1: Write failing status-widget tests**

Test an injected uptime sample and invalid input without depending on host uptime:

```qml
clock.testUptimeText = "3661.23 120.00"
clock.refresh()
compare(clock.uptimeText, "已运行 01:01:01")
clock.testUptimeText = "invalid"
clock.refresh()
compare(clock.uptimeText, "已运行 --:--:--")
profile.username = " Sighthesia "
compare(profile.fallbackText, "S")
profile.username = ""
compare(profile.fallbackText, "?")
```

- [ ] **Step 2: Run tests and verify failure**

Run: `qs -p tests/qml/tst_lazer_status_widgets.qml`

Expected: FAIL because status widgets do not exist.

- [ ] **Step 3: Implement real clock and `/proc/uptime` refresh**

Use one repeating 1000ms QML `Timer`. Refresh local time with `Qt.formatTime(new Date(), "hh:mm:ss")`. Read `/proc/uptime` through Quickshell's supported process/file API without shell interpolation, feed the text to `parseUptime()`, and expose `已运行 --:--:--` on read/parse failure. Keep an injected test string path that bypasses the process only when `testMode` is true.

Render the clock face as a persistent icon plus a dedicated `#FF66AA` hand layer so the hand remains pink while the dial follows foreground state.

- [ ] **Step 4: Implement avatar fallback**

Use one 32x32 clipped rounded item with radius 4. Render `Image` when ready; crossfade to a local initial fallback when source is empty or errors. Preserve one persistent frame so avatar load does not resize the status zone.

- [ ] **Step 5: Register and run status tests**

Run: `qs -p tests/qml/tst_lazer_status_widgets.qml`

Expected: PASS with no WARN or ERROR lines.

- [ ] **Step 6: Commit status widgets**

```bash
git add modules/lazerbar/ClockWidget.qml modules/lazerbar/UserProfile.qml modules/lazerbar/qmldir tests/qml/tst_lazer_status_widgets.qml
git commit -m "feat: add lazer profile and uptime widgets"
```

---

### Task 8: Left, Utility, And Status Zones

**Files:**
- Create: `modules/lazerbar/LeftZone.qml`
- Create: `modules/lazerbar/UtilityZone.qml`
- Create: `modules/lazerbar/StatusZone.qml`
- Create: `tests/qml/tst_lazer_zones.qml`
- Modify: `modules/lazerbar/qmldir`

**Interfaces:**
- Consumes: `IconButton`, `ModeSelector`, `ClockWidget`, `UserProfile`, bundled SVGs, and `LazerBarLogic.visibleUtilityIds()`.
- Produces: zone `implicitWidth`, ordered focus controls, `selectedMode`, `notificationsActive`, and `availableWidth` for utility reduction.
- Produces: visual-only signals for future use without invoking business actions.

- [ ] **Step 1: Write failing zone layout tests**

Assert left-zone order and default mode, all eight utility IDs on wide width, only `music` at 32px, status username/avatar/clock/bell ordering, and bell toggle through `activateNotification()`.

Assert removal order by stepping available width downward and checking `community`, `chat`, `ranking`, `wiki`, `changelog`, `news`, and `library` leave in that order. Verify an item fades before setting `layoutVisible` false.

- [ ] **Step 2: Run zone tests and verify failure**

Run: `qs -p tests/qml/tst_lazer_zones.qml`

Expected: FAIL because zone types do not exist.

- [ ] **Step 3: Implement left and utility zones**

Build `LeftZone` with Settings, Home, separator, and `ModeSelector`. Build `UtilityZone` in the exact requested order with a separator before Music. Its `availableWidth` computes survivors through `visibleUtilityIds()`; leaving entries animate opacity over 100ms, then stop consuming width. Do not animate width itself.

- [ ] **Step 4: Implement status zone and focus order**

Build `StatusZone` with username, avatar, clock, uptime, and bell. Bell is the only local toggle besides mode selection. Expose explicit `KeyNavigation.tab/backtab/left/right` links across controls so Tab order remains left-to-right within each zone.

- [ ] **Step 5: Register and run zone tests**

Run: `qs -p tests/qml/tst_lazer_zones.qml`

Expected: PASS with no WARN or ERROR lines.

- [ ] **Step 6: Commit zones**

```bash
git add modules/lazerbar/LeftZone.qml modules/lazerbar/UtilityZone.qml modules/lazerbar/StatusZone.qml modules/lazerbar/qmldir tests/qml/tst_lazer_zones.qml
git commit -m "feat: compose lazer top bar zones"
```

---

### Task 9: Layer-Shell Background And Per-Screen Composition

**Files:**
- Create: `modules/lazerbar/BarBackground.qml`
- Create: `modules/lazerbar/TopBar.qml`
- Create: `shell.qml`
- Modify: `modules/lazerbar/qmldir`

**Interfaces:**
- Consumes: all three zones and `Quickshell.screens`.
- Produces: one `BarBackground` and three content-width interactive `PanelWindow`s per screen.
- Produces: public `TopBar.screen`, `username`, and `avatarSource` properties.

- [ ] **Step 1: Create the full-width exclusive-zone owner**

Implement `BarBackground` as a top-anchored `PanelWindow` with:

```qml
implicitHeight: 46
WlrLayershell.layer: WlrLayer.Top
WlrLayershell.exclusiveZone: 46
```

Paint `#18171C` and 12px bottom corners. Do not set `width` or `height` directly on the `PanelWindow`.

- [ ] **Step 2: Compose three content-width interactive windows**

Implement `TopBar` with persistent left, utility, and status `PanelWindow`s. Set `WlrLayershell.exclusiveZone: 0` for all three. Keep each window's `implicitWidth` equal to content width so transparent space cannot intercept application input. Position left at the left edge, status at the right edge, and utility between them; derive utility `availableWidth` from screen width minus left/status widths and safety gaps.

Use a consistent namespace and top layer. Ensure the background is created before interactive windows and does not accept pointer input.

- [ ] **Step 3: Add the Quickshell entry point**

Create `shell.qml` with a commented `Variants { model: Quickshell.screens }` and one `TopBar` delegate per screen. Provide default username `Sighthesia` and an empty avatar source so the fallback is visible immediately.

- [ ] **Step 4: Register and run every focused QML test**

Run each command separately and fix every WARN/ERROR line:

```bash
qs -p tests/qml/tst_lazer_bar_logic.qml
qs -p tests/qml/tst_lazer_icon_button.qml
qs -p tests/qml/tst_lazer_mode_selector.qml
qs -p tests/qml/tst_lazer_popups.qml
qs -p tests/qml/tst_lazer_status_widgets.qml
qs -p tests/qml/tst_lazer_zones.qml
```

Expected: all PASS.

- [ ] **Step 5: Smoke-launch the shell**

Run: `timeout 8s qs -p .`

Expected: the process remains healthy until timeout, creates the bar, and emits no QML WARN or ERROR lines. Treat timeout exit 124 as expected only if logs are clean.

- [ ] **Step 6: Commit the shell composition**

```bash
git add shell.qml modules/lazerbar/BarBackground.qml modules/lazerbar/TopBar.qml modules/lazerbar/qmldir
git commit -m "feat: launch lazer top bar per screen"
```

---

### Task 10: Regression, Interaction, And Layout Verification

**Files:**
- Modify only files proven faulty by this verification task.

**Interfaces:**
- Consumes: complete top-bar implementation.
- Produces: a clean verified branch with no known QML warnings or backend regressions.

- [ ] **Step 1: Run all existing backend QML tests**

Run each test independently:

```bash
qs -p tests/qml/tst_capsule_metrics.qml
qs -p tests/qml/tst_bar_layout.qml
qs -p tests/qml/tst_media_lyrics.qml
qs -p tests/qml/tst_media_service.qml
qs -p tests/qml/tst_workspace_hint_services.qml
```

Expected: all PASS with no WARN or ERROR lines.

- [ ] **Step 2: Run Python regression tests**

Run: `python -m unittest discover -s scripts/tests -v`

Expected: PASS.

- [ ] **Step 3: Verify motion values at normal and reduced settings**

Launch normally and exercise hover, press, mode switching, bell switching, DropdownMenu, ContextMenu, and ModalOverlay using their test/demo harness. Confirm:

- Hover scale never exceeds 1.015.
- Press reaches 0.985 and 1px Y offset.
- Active accent survives hover and press.
- Indicator slides as one persistent object.
- Menus scale from the trigger-facing corner.
- Closing disables interaction immediately.
- Modal backdrop/panel timings are asymmetric.

Enable `MotionTokens.reducedMotionOverride` in the test harness and confirm scale/Y/indicator/shadow movement is absent while opacity and color remain.

- [ ] **Step 4: Verify multi-screen and narrow-width behavior**

On the available compositor setup, confirm every screen gets exactly one background and three interactive zones, only the background reserves 46px, and application windows begin below it. Use the zone test harness at 1920, 1366, 1024, and 800px widths to confirm no overlap and that Music is retained.

- [ ] **Step 5: Inspect final repository state and diff**

Run:

```bash
git status --short --branch
git diff --check backend-only...HEAD
git log --oneline backend-only..HEAD
```

Expected: only the unrelated untracked `docs/image.png` may remain outside commits; no whitespace errors; commit sequence is focused and conventional.

- [ ] **Step 6: Commit any verification fixes**

If verification required changes, stage only those files and commit:

```bash
git add modules/lazerbar shell.qml tests/qml
git commit -m "fix: finalize lazer top bar behavior"
```

Before running the shown `git add`, omit every unchanged path and inspect the staged diff so unrelated files are never included. If no fixes were needed, do not create an empty commit.
