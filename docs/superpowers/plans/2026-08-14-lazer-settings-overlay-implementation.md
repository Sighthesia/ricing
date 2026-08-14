# Lazer Settings Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a centered, modal osu!lazer-style settings overlay whose Appearance, Top Bar, and Notifications controls immediately affect real shell behavior and persist through `SettingsService`.

**Architecture:** Each screen keeps one fixed-size settings `PanelWindow` on the desktop-facing side of the bar. `TopBar` owns one `activeOverlay` value shared by settings and music; the window never resizes during motion, while a persistent inner panel slides over a blocking scrim. Focused visual controls emit typed changes, category pages bind them to singleton services, and every exposed setting gains a verified live consumer.

**Tech Stack:** Qt 6.11, QtQuick/QML, Quickshell, Quickshell.Wayland layer shell, Quickshell.Services.Notifications, existing Afloat singleton services, QtTest, bundled SVG assets.

## Global Constraints

- Work on branch `lazer`; preserve unrelated untracked `docs/image.png` and all user changes.
- Use native QML only; add no React, CSS, Tailwind, icon-font, or third-party UI dependency.
- The settings window uses `exclusionMode: ExclusionMode.Ignore`; only `BarBackground` reserves workspace.
- Keep the settings `PanelWindow` outer geometry fixed during every entrance and exit frame; animate only inner scene-graph items.
- Normal entrance is 320ms with `Easing.OutQuint`; normal exit is 240ms with `Easing.InCubic`; category switching is 160ms with `MotionTokens.outSoft`.
- A top bar moves the panel from above toward rest; a bottom bar mirrors that path from below toward rest.
- Scrim target is black at opacity `0.6`; it covers and blocks only the screen area on the desktop-facing side of the bar.
- Settings and music are mutually exclusive per screen through one `activeOverlay` string.
- Closing disables panel controls immediately but keeps the scrim input region until the close animation completes.
- Reduced motion removes panel/category positional movement while retaining short opacity and color transitions.
- Use `implicitWidth`/`implicitHeight` for `PanelWindow`; never assign deprecated `width`/`height` to layer-shell windows.
- Put `Keys.*` handlers on an inner focused `Item`, never directly on `PanelWindow`.
- Every perceptible color, opacity, border, radius, spacing, position, and scale change must transition.
- Add a short English intent comment before every major QML `Variants`, `PanelWindow`, `Item`, and reusable visual component declaration.
- Clamp every numeric setting before assignment; enum controls emit only documented values.
- Every exposed setting must have a live consumer in this branch; do not ship inert controls.
- After every QML change, run the relevant test and fix every WARN/ERROR line before committing.
- Commit each independently verified task with a conventional commit message; do not amend commits.

## File Map

- `modules/lazerbar/LazerSettingsLogic.js`: overlay state, panel geometry, category direction, clamps, timeout conversion, and notification anchors.
- `modules/lazerbar/LazerSettings{Row,Toggle,Slider,Choice,TextField}.qml`: service-independent controls.
- `modules/lazerbar/LazerSettings{Appearance,Bar,Notifications}.qml`: category content and service binding.
- `modules/lazerbar/LazerSettingsPanel.qml`: header, rail, persistent pages, and category transition.
- `modules/lazerbar/LazerSettingsOverlay.qml`: scrim, lifecycle, motion, input blocking, and focus.
- `modules/lazerbar/LeftZone.qml`, `UtilityZone.qml`, `TopBar.qml`: overlay button and per-screen ownership.
- `modules/lazerbar/BarBackground.qml`: live bar geometry.
- `modules/lazerbar/NotificationHost.qml`, `LazerNotificationStack.qml`, `LazerNotificationPopup.qml`: live notification position and timeout consumers.
- `services/NotificationService.qml`: deterministic popup expiry data/API.
- `services/ColorService.qml`, `services/Color.qml`: live auto/dark/light palette generation and selection.
- `modules/lazerbar/qmldir`: type registration.

---

### Task 1: Settings State And Geometry Logic

**Files:**
- Modify: `modules/lazerbar/LazerBarLogic.js`
- Create: `modules/lazerbar/LazerSettingsLogic.js`
- Modify: `modules/lazerbar/LazerTheme.qml`
- Modify: `modules/lazerbar/MotionTokens.qml`
- Create: `tests/qml/tst_lazer_settings_logic.qml`

**Interfaces:**
- Produces `BarLogic.nextOverlay(current, requested): string`.
- Produces `SettingsLogic.clamp(value, minimum, maximum): number`.
- Produces `panelWidth(availableWidth)`, `panelHeight(availableHeight)`, and `navigationWidth(panelWidth)`.
- Produces `categoryDirection(previousIndex, nextIndex): -1|0|1`.
- Produces `timeoutSecondsToMs(seconds): int` and `notificationAnchors(position): object`.
- Produces theme tokens `settingsPanel`, `settingsPanelBorder`, `settingsRail`, `settingsRow`, `settingsRowHover`, `settingsSelected`, `settingsScrimOpacity = 0.6`, and `settingsRadius = 16`.
- Produces motion tokens `settingsEnter = 320`, `settingsExit = 240`, `settingsScrim = 180`, and `settingsCategory = 160`.

- [ ] **Step 1: Write the failing pure-logic test**

Create table-driven tests containing these assertions:

```qml
compare(BarLogic.nextOverlay("", "settings"), "settings")
compare(BarLogic.nextOverlay("settings", "settings"), "")
compare(BarLogic.nextOverlay("music", "settings"), "settings")
compare(SettingsLogic.panelWidth(1920), 1040)
compare(SettingsLogic.panelWidth(900), 760)
compare(SettingsLogic.panelWidth(600), 568)
compare(SettingsLogic.panelHeight(1080), 760)
compare(SettingsLogic.panelHeight(540), 508)
compare(SettingsLogic.navigationWidth(759), 168)
compare(SettingsLogic.navigationWidth(760), 216)
compare(SettingsLogic.timeoutSecondsToMs(1), 2000)
compare(SettingsLogic.timeoutSecondsToMs(20), 15000)
compare(SettingsLogic.categoryDirection(2, 0), -1)
const anchors = SettingsLogic.notificationAnchors("bottom-left")
compare(anchors.top, false)
compare(anchors.bottom, true)
compare(anchors.left, true)
compare(anchors.right, false)
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_settings_logic.qml -o -,txt -v1
```

Expected: FAIL because the settings logic module and `nextOverlay()` do not exist.

- [ ] **Step 3: Implement the pure helpers and tokens**

`panelWidth()` targets `availableWidth * 0.8`, clamps regular layouts to 760..1040, and returns `max(320, availableWidth - 32)` below 792px. `panelHeight()` targets `availableHeight * 0.78`, clamps regular layouts to 520..760, and returns `max(320, availableHeight - 32)` below 552px. All helpers reject non-finite values predictably.

- [ ] **Step 4: Run the test cleanly**

Expected: PASS with no WARN/ERROR.

- [ ] **Step 5: Commit**

```bash
git add modules/lazerbar/LazerBarLogic.js modules/lazerbar/LazerSettingsLogic.js modules/lazerbar/LazerTheme.qml modules/lazerbar/MotionTokens.qml tests/qml/tst_lazer_settings_logic.qml
git commit -m "feat: add lazer settings state logic"
```

---

### Task 2: Reusable Settings Controls

**Files:**
- Create: `modules/lazerbar/LazerSettingsRow.qml`
- Create: `modules/lazerbar/LazerSettingsToggle.qml`
- Create: `modules/lazerbar/LazerSettingsSlider.qml`
- Create: `modules/lazerbar/LazerSettingsChoice.qml`
- Create: `modules/lazerbar/LazerSettingsTextField.qml`
- Modify: `modules/lazerbar/qmldir`
- Create: `tests/qml/tst_lazer_settings_controls.qml`

**Interfaces:**
- `LazerSettingsRow`: `labelText`, `descriptionText`, `enabled`, default `control` property, minimum 56px height.
- `LazerSettingsToggle`: `checked`, `enabled`, `accessibleName`, signal `toggled(bool)`, method `activate()`.
- `LazerSettingsSlider`: `value`, `from`, `to`, `stepSize`, `suffix`, `enabled`, `accessibleName`, readonly `displayText`, signal `valueModified(real)`, methods `increase()` and `decrease()`.
- `LazerSettingsChoice`: model entries `{ value, label }`, `currentValue`, `enabled`, signal `valueSelected(string)`.
- `LazerSettingsTextField`: `text`, `placeholderText`, signals `textCommitted(string)` and `clearRequested()`.

- [ ] **Step 1: Write failing component tests**

Assert toggle activation and disabled blocking; slider clamp, stepping, suffix, and Left/Right behavior; enum rejection of unknown values; text trim/commit and clear; focus-visible state; and reduced-motion transform suppression. Use `SignalSpy` for every public signal.

- [ ] **Step 2: Run and verify type-unavailable failures**

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_settings_controls.qml -o -,txt -v1
```

- [ ] **Step 3: Implement persistent accessible controls**

Use `HoverHandler` plus `TapHandler`, one persistent background/thumb/indicator, and `Accessible` roles. Normalize sliders with:

```qml
function normalized(candidate) {
    const clamped = Math.max(from, Math.min(to, Number(candidate)))
    const steps = Math.round((clamped - from) / stepSize)
    return Math.max(from, Math.min(to, from + steps * stepSize))
}
```

Do not import `SettingsService` in reusable controls.

- [ ] **Step 4: Run tests and validate layout**

Run the component test and `git diff --check`; verify the longest Chinese choice fits the 760px panel.

- [ ] **Step 5: Commit**

```bash
git add modules/lazerbar/LazerSettingsRow.qml modules/lazerbar/LazerSettingsToggle.qml modules/lazerbar/LazerSettingsSlider.qml modules/lazerbar/LazerSettingsChoice.qml modules/lazerbar/LazerSettingsTextField.qml modules/lazerbar/qmldir tests/qml/tst_lazer_settings_controls.qml
git commit -m "feat: add lazer settings controls"
```

---

### Task 3: Functional Settings Category Pages

**Files:**
- Create: `modules/lazerbar/LazerSettingsAppearance.qml`
- Create: `modules/lazerbar/LazerSettingsBar.qml`
- Create: `modules/lazerbar/LazerSettingsNotifications.qml`
- Modify: `modules/lazerbar/qmldir`
- Create: `tests/qml/tst_lazer_settings_pages.qml`

**Interfaces:**
- Every page exposes `contentHeight` and test aliases for its controls.
- Pages accept injectable `settingsObject`; Appearance also accepts injectable `wallpaperService`.
- Production defaults use `Services.SettingsService` and `Services.WallpaperService`.
- Pages accept injectable `saveCallback`; production defaults call `Services.SettingsService.save()`. Normal writes assign a clamped value then call `saveCallback()`; wallpaper commit uses `wallpaperService.changeWallpaper(path)`.

- [ ] **Step 1: Write failing page tests with fake settings objects**

Use local `QtObject` fakes and a counter-backed `saveCallback` so tests cannot touch the real state file. Cover every scoped field:

```qml
QtObject {
    id: fakeBar
    property int height: 48
    property string position: "top"
    property bool floating: false
    property int floatingMargin: 4
    property int cornerRadius: 12
}
```

Appearance assertions cover wallpaper path, `colorScheme`, `panelOpacity`, `enableBlur`, `blurSurfaceOpacity`, `glassHighlightIntensity`, `glassGlowIntensity`, `glassThemeAdaptive`, and `ripplePulseEnabled`. Bar assertions cover ranges 40..64, 0..24 and only `top|bottom`. Notification assertions cover max 1..8, timeout 2..15 seconds stored as milliseconds, four positions, and DND. Verify dependent sliders disable without losing stored values.

- [ ] **Step 2: Run and verify page types are unavailable**

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_settings_pages.qml -o -,txt -v1
```

- [ ] **Step 3: Implement scrollable category pages**

Use Chinese titles `外观`, `顶部栏`, and `通知`. Use an unframed `Flickable` with translucent grouped rows; avoid nested card stacks. Wallpaper clear writes an empty path directly and saves because `WallpaperService.changeWallpaper()` intentionally ignores empty paths.

- [ ] **Step 4: Run Tasks 2 and 3 tests cleanly**

Expected: PASS with no WARN/ERROR.

- [ ] **Step 5: Commit**

```bash
git add modules/lazerbar/LazerSettingsAppearance.qml modules/lazerbar/LazerSettingsBar.qml modules/lazerbar/LazerSettingsNotifications.qml modules/lazerbar/qmldir tests/qml/tst_lazer_settings_pages.qml
git commit -m "feat: add functional lazer settings pages"
```

---

### Task 4: Persistent Panel And Category Cross-Fade

**Files:**
- Create: `modules/lazerbar/LazerSettingsNavItem.qml`
- Create: `modules/lazerbar/LazerSettingsPanel.qml`
- Modify: `modules/lazerbar/qmldir`
- Create: `tests/qml/tst_lazer_settings_panel.qml`

**Interfaces:**
- Properties `availableWidth`, `availableHeight`, `selectedCategory`, and `interactive`.
- Readonly `panelWidth`, `panelHeight`, `navigationWidth`, `selectedIndex`, and `contentTransitionDirection`.
- Signals `closeRequested()` and `categoryChanged(string)`.
- Methods `selectCategory(string)`, `focusFirstControl()`, and `focusNavigation()`.
- Test aliases expose all three persistent pages and the selection indicator.

- [ ] **Step 1: Write the failing panel test**

Assert regular/narrow geometry, default `appearance`, three simultaneously existing page instances, page identity and per-page scroll-position preservation after switching, direction ±1, overlapping opacity during transition, exact 160ms duration, no restart when selecting the active page, navigation keyboard behavior, immediate interactive gating, hidden-page focus exclusion, and zero X translation under reduced motion.

- [ ] **Step 2: Run the failing test**

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_settings_panel.qml -o -,txt -v1
```

- [ ] **Step 3: Implement one persistent two-column panel**

Use one 16px-radius outer surface, a 64px header, 216/168px navigation rail, and clipped content viewport. Instantiate all pages once. Move one persistent pink indicator between rows. Cross-fade pages with opacity and ±8px translation; rapid selections stop at current values and retarget rather than resetting.

- [ ] **Step 4: Run panel, page, and control tests**

Expected: all pass without WARN/ERROR.

- [ ] **Step 5: Commit**

```bash
git add modules/lazerbar/LazerSettingsNavItem.qml modules/lazerbar/LazerSettingsPanel.qml modules/lazerbar/qmldir tests/qml/tst_lazer_settings_panel.qml
git commit -m "feat: add lazer settings panel navigation"
```

---

### Task 5: Modal Overlay Lifecycle And Input Contract

**Files:**
- Create: `modules/lazerbar/LazerSettingsOverlay.qml`
- Modify: `modules/lazerbar/qmldir`
- Create: `tests/qml/tst_lazer_settings_overlay.qml`

**Interfaces:**
- `phase`: `closed|opening|open|closing`.
- `interactive` is true only for opening/open; `blocksDesktop` is true until close finishes.
- Properties `progress`, `scrimProgress`, `availableWidth`, `availableHeight`, `opener`.
- Properties include `entryDirection: -1|1`, where `-1` means top-origin and `1` means bottom-origin.
- Readonly `panelOffsetY`, `panelOpacity`, `scrimOpacity`, `enterDuration`, `exitDuration`, and `scrimDuration`.
- Signals `closed()` and `closeRequested()`; methods `openFrom(Item)`, `closeAndRestoreFocus()`, `closeWithoutFocusRestore()`, and `requestClose()`.

- [ ] **Step 1: Write failing lifecycle tests**

Assert open/close phases, input states, exact durations and opacity, top-origin start at `-panel.height`, bottom-origin start at `panel.height`, scrim click close, panel click isolation, Escape close, focus restoration, `closeWithoutFocusRestore()` leaving focus available for a replacement overlay, reduced-motion zero offset, and reopening during close from current progress. Use this key contract:

```qml
overlay.closeAndRestoreFocus()
compare(overlay.phase, "closing")
compare(overlay.blocksDesktop, true)
compare(overlay.interactive, false)
tryCompare(overlay, "phase", "closed", 340)
compare(overlay.blocksDesktop, false)
```

- [ ] **Step 2: Run the failing test**

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_settings_overlay.qml -o -,txt -v1
```

- [ ] **Step 3: Implement fixed-host inner motion**

Use `NumberAnimation` with `Easing.OutQuint` on open and `Easing.InCubic` on close. Translate the centered panel from `entryDirection * panel.height` relative to rest. The scrim `TapHandler` closes; a panel-area handler accepts interior taps. Keep root visible and blocking until exit completion. Implement Tab/Backtab cycling on an inner focused `Item`; hidden pages must be disabled and absent from that cycle.

- [ ] **Step 4: Run overlay and panel tests cleanly**

Expected: PASS without WARN/ERROR.

- [ ] **Step 5: Commit**

```bash
git add modules/lazerbar/LazerSettingsOverlay.qml modules/lazerbar/qmldir tests/qml/tst_lazer_settings_overlay.qml
git commit -m "feat: add lazer settings overlay motion"
```

---

### Task 6: Unified Settings And Music Buttons

**Files:**
- Modify: `modules/lazerbar/OsuTopBarButton.qml`
- Modify: `modules/lazerbar/LeftZone.qml`
- Modify: `modules/lazerbar/UtilityZone.qml`
- Modify: `tests/qml/tst_osu_top_bar_button.qml`
- Modify: `tests/qml/tst_lazer_zones.qml`
- Modify: `tests/qml/tst_lazer_music_integration.qml`

**Interfaces:**
- `LeftZone.settingsActive`, alias `settingsButtonItem`, signal `overlayRequested(string target)`.
- `UtilityZone.musicActive`, alias `musicButtonItem`, signal `overlayRequested(string target)` replacing `musicOverlayRequested(bool)`.
- Both buttons always emit their target; `TopBar` applies `nextOverlay()`.

- [ ] **Step 1: Extend existing tests first**

Assert settings inactive/active state and `overlayRequested("settings")`; update music to assert `overlayRequested("music")`. Retain all hover, flash, tooltip, keyboard, narrow priority, and reduced-motion assertions.

- [ ] **Step 2: Run the three affected tests and observe failures**

Use `/usr/lib/qt6/bin/qmltestrunner` individually for each file.

- [ ] **Step 3: Replace only settings and music with `OsuTopBarButton`**

Use settings tooltip `设置` / `外观、顶部栏与通知`. Preserve Home and mode controls. Suppress active-entry tooltips and keep music as the final narrow-screen utility.

- [ ] **Step 4: Run affected tests cleanly**

- [ ] **Step 5: Commit**

```bash
git add modules/lazerbar/OsuTopBarButton.qml modules/lazerbar/LeftZone.qml modules/lazerbar/UtilityZone.qml tests/qml/tst_osu_top_bar_button.qml tests/qml/tst_lazer_zones.qml tests/qml/tst_lazer_music_integration.qml
git commit -m "feat: unify lazer overlay buttons"
```

---

### Task 7: Live Lazer Bar Geometry

**Files:**
- Modify: `modules/lazerbar/BarBackground.qml`
- Modify: `modules/lazerbar/TopBar.qml`
- Modify: `modules/lazerbar/LeftZone.qml`
- Modify: `modules/lazerbar/UtilityZone.qml`
- Modify: `modules/lazerbar/StatusZone.qml`
- Create: `tests/qml/tst_lazer_bar_geometry.qml`

**Interfaces:**
- `BarBackground.barSettings` defaults to `Services.SettingsService.bar` and exposes readonly `barHeight`, `atTop`, `floatingMargin`, `effectiveRadius`, `reservedZone`.
- Zone roots accept `barHeight` and derive `implicitHeight` from it.
- `TopBar` derives every bar and overlay attachment edge from the same settings object.

- [ ] **Step 1: Write failing geometry tests with fake bar settings**

Assert height 48→64 updates window height and exclusive zone; bottom position swaps anchors; floating margin 12 applies at the edge and reserves `height + margin`; non-floating resolves margin zero; top rounds bottom corners while bottom rounds top corners; zones receive bar height; music/tooltip/settings open toward the desktop-facing edge.

- [ ] **Step 2: Run the failing geometry test**

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_bar_geometry.qml -o -,txt -v1
```

- [ ] **Step 3: Bind every bar surface to shared settings**

Use direct layer-shell geometry bindings with no `Behavior`. Clamp values at the consumer as defense against an externally edited state file. Ensure bottom-bar overlays stay inside screen bounds and the settings host excludes the bar plus floating gap.

- [ ] **Step 4: Run geometry and existing zone tests**

- [ ] **Step 5: Commit**

```bash
git add modules/lazerbar/BarBackground.qml modules/lazerbar/TopBar.qml modules/lazerbar/LeftZone.qml modules/lazerbar/UtilityZone.qml modules/lazerbar/StatusZone.qml tests/qml/tst_lazer_bar_geometry.qml
git commit -m "feat: connect lazer bar geometry settings"
```

---

### Task 8: Per-Screen Settings Window And Overlay Mutual Exclusion

**Files:**
- Modify: `modules/lazerbar/TopBar.qml`
- Create: `tests/qml/tst_lazer_overlay_integration.qml`

**Interfaces:**
- `TopBar` screen scope owns `activeOverlay`, `requestOverlay(target)`, and `settingsBlocksDesktop`.
- Settings host uses full input mask while `settingsOverlay.blocksDesktop`; empty mask otherwise.
- Settings host requests `WlrKeyboardFocus.OnDemand` only while settings opens/is open.

- [ ] **Step 1: Write a host-facing integration test**

Extract/test state through a lightweight test harness matching `requestOverlay()` and assert: closed→settings, settings→closed, settings→music, music→settings, no empty intermediate target, music close invocation before settings open, settings controls disabled immediately on cross-switch, `closeWithoutFocusRestore()` on replacement, and settings opener focus restored only when closing to empty. Instantiate two harnesses to verify one screen's category and active target do not mutate the other.

- [ ] **Step 2: Run and verify failures against current independent state**

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_overlay_integration.qml -o -,txt -v1
```

- [ ] **Step 3: Integrate one fixed settings window per screen**

Replace `musicOverlayOpen` with `activeOverlay`. Add a transparent fixed host spanning the desktop side, `ExclusionMode.Ignore`, conditional full/empty `Region`, and inner `LazerSettingsOverlay`. Pass `entryDirection: barAtTop ? -1 : 1`. Route Left/Utility signals through `requestOverlay()`. Call `closeWithoutFocusRestore()` when another overlay replaces settings and `closeAndRestoreFocus()` only when closing to empty. Preserve music card-only masking. Keep the top bar above the settings window and undimmed.

- [ ] **Step 4: Verify integration and startup**

Run integration tests and `timeout 8s qs -p .`; require Configuration Loaded and no WARN/ERROR.

- [ ] **Step 5: Commit**

```bash
git add modules/lazerbar/TopBar.qml tests/qml/tst_lazer_overlay_integration.qml
git commit -m "feat: connect lazer settings overlay"
```

---

### Task 9: Live Notification Timeout And Position

**Files:**
- Modify: `services/NotificationService.qml`
- Create: `modules/lazerbar/LazerNotificationPopup.qml`
- Create: `modules/lazerbar/LazerNotificationStack.qml`
- Create: `modules/lazerbar/NotificationHost.qml`
- Modify: `modules/lazerbar/TopBar.qml`
- Modify: `modules/lazerbar/qmldir`
- Create: `tests/qml/tst_lazer_notifications.qml`

**Interfaces:**
- Popup model entries add `expiresAt: double` from `Date.now() + SettingsService.notifications.timeout`.
- `NotificationService.expirePopups(nowMs): int` removes expired entries and returns the count.
- `NotificationService.appendPopup(entry, nowMs): bool` owns max-visible and `expiresAt` calculation, allowing deterministic service tests.
- Stack accepts `popupModel`, `position`, and `timeout`; host derives four edge anchors from `SettingsLogic.notificationAnchors()`.

- [ ] **Step 1: Write failing service and presentation tests**

Use a local model for presentation tests and call `appendPopup(entry, fixedNow)` for service tests. Assert expiry removes only due entries, max-visible caps before append, all four positions resolve correctly, stack order grows away from the selected edge, popup close calls `removeNotification(notifId)`, and setting timeout changes the expiry assigned to newly received entries.

- [ ] **Step 2: Run the failing test**

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_notifications.qml -o -,txt -v1
```

- [ ] **Step 3: Implement the smallest real popup consumer**

Add one low-frequency service timer (100ms) calling `expirePopups(Date.now())`; do not create one timer per delegate. Present compact translucent popups in a fixed edge strip large enough for eight cards so model growth never resizes the layer-shell window per frame. Mask input to the actual stack only. Position the host from the configured screen corner and offset it from the live top/bottom bar edge.

- [ ] **Step 4: Run notification tests and startup**

Send a local notification with `notify-send`, verify position and configured dismissal duration, and require no WARN/ERROR.

- [ ] **Step 5: Commit**

```bash
git add services/NotificationService.qml modules/lazerbar/LazerNotificationPopup.qml modules/lazerbar/LazerNotificationStack.qml modules/lazerbar/NotificationHost.qml modules/lazerbar/TopBar.qml modules/lazerbar/qmldir tests/qml/tst_lazer_notifications.qml
git commit -m "feat: connect lazer notification settings"
```

---

### Task 10: Live Appearance Consumers

**Files:**
- Modify: `services/ColorService.qml`
- Modify: `services/Color.qml`
- Modify: `modules/lazerbar/LazerTheme.qml`
- Modify: `modules/lazerbar/BarBackground.qml`
- Modify: `modules/lazerbar/LazerSettingsPanel.qml`
- Create: `tests/qml/tst_lazer_appearance_settings.qml`

**Interfaces:**
- `ColorService.requestedMode` resolves `auto|dark|light`; auto follows `Qt.styleHints.colorScheme` when available and otherwise dark.
- `ColorService.commandFor(wallpaperPath, requestedMode, outputPath): string` exposes deterministic command construction for tests.
- Extraction generates both dark and light output for auto and the selected single mode for explicit mode.
- `Color.activeMode` selects `adapter.dark` or `adapter.light` and reapplies on mode changes.
- Lazer surface opacity, blur fallback, highlight intensity, glow intensity, and adaptive tint consume the corresponding appearance values.

- [ ] **Step 1: Write failing appearance-consumer tests**

Assert `commandFor()` emits `--dark`, `--light`, or neither for dual-mode auto output; palette selection; panel/background alpha derived from `panelSurfaceOpacity`; blur toggle changing fallback opacity; highlight/glow opacity tracking settings; adaptive tint on/off; and ripple toggle continuing to gate `IslandService`.

- [ ] **Step 2: Run the failing test**

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_appearance_settings.qml -o -,txt -v1
```

- [ ] **Step 3: Implement live consumers without changing the approved dark visual identity**

Extend the color JSON adapter with both `dark` and `light`. Resolve auto mode from Qt when supported. Keep osu pink/green accents fixed; adapt only neutral surfaces and subtle tint/highlight/glow. Apply panel opacity to bar/settings/notification neutral fills, render a subtle highlight and glow from their configured intensities, and use the theme accent only when adaptation is enabled. Animate scene-graph colors/opacities, but never animate window geometry.

- [ ] **Step 4: Run appearance, service, and startup tests**

Change each control live and verify visible response plus persistence after restart. Require no WARN/ERROR.

- [ ] **Step 5: Commit**

```bash
git add services/ColorService.qml services/Color.qml modules/lazerbar/LazerTheme.qml modules/lazerbar/BarBackground.qml modules/lazerbar/LazerSettingsPanel.qml tests/qml/tst_lazer_appearance_settings.qml
git commit -m "feat: connect lazer appearance settings"
```

---

### Task 11: Full Regression And Manual Interaction Verification

**Files:**
- Modify only files proven faulty by verification.

- [ ] **Step 1: Run every new settings test individually**

```bash
for test in \
  tests/qml/tst_lazer_settings_logic.qml \
  tests/qml/tst_lazer_settings_controls.qml \
  tests/qml/tst_lazer_settings_pages.qml \
  tests/qml/tst_lazer_settings_panel.qml \
  tests/qml/tst_lazer_settings_overlay.qml \
  tests/qml/tst_lazer_bar_geometry.qml \
  tests/qml/tst_lazer_overlay_integration.qml \
  tests/qml/tst_lazer_notifications.qml \
  tests/qml/tst_lazer_appearance_settings.qml; do
  /usr/lib/qt6/bin/qmltestrunner -input "$test" -o -,txt -v1 || exit 1
```

- [ ] **Step 2: Run every existing Lazer and backend test**

Run all `tests/qml/tst_lazer_*.qml`, `tst_osu_*.qml`, and the existing backend QML tests individually. Run `python -m unittest discover -s scripts/tests -v`. Treat any WARN/ERROR as failure.

- [ ] **Step 3: Validate startup, SVG, and repository cleanliness**

```bash
xmllint --noout modules/lazerbar/icons/*.svg
timeout 8s qs -p .
git diff --check
git status --short --branch
```

Timeout 124 is acceptable only after `Configuration Loaded` with no WARN/ERROR. Leave `docs/image.png` untouched.

- [ ] **Step 4: Perform the manual acceptance matrix**

Verify on each connected screen: settings flash and pink state; repeat-click close; direct settings/music cross-switch; 320ms OutQuint entrance and 240ms accelerating exit; mirrored bottom-bar entrance; desktop-only 0.6 scrim; click-away and Escape; no desktop click-through during exit; focus return; three category cross-fades and remembered scroll; every setting responds live and survives restart; top/bottom/floating bar placement; four notification corners and expiry; narrow 600px layout; reduced motion; no per-frame `PanelWindow` resize.

- [ ] **Step 5: Commit only proven final fixes**

If verification requires changes, replace the sample paths below with the exact files named by the failing test and stage only those files:

```bash
git add -- modules/lazerbar/<fixed-file>.qml tests/qml/<fixed-test>.qml
git commit -m "fix: finalize lazer settings overlay"
```

Do not create an empty commit.
