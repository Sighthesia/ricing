# osu Fullscreen Visual Calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mixed rounded fullscreen host with source-faithful osu!lazer wave pages, a left-side Settings panel, and a dedicated Now Playing overlay while preserving existing settings and MPRIS behaviour.

**Architecture:** A pure per-screen `OverlayCoordinator` serialises one active target across three persistent owner windows. Wiki, News, and Beatmap share one fixed fullscreen owner with an 85% clipped four-wave surface; Settings and Now Playing keep independent fixed-geometry layer-shell owners and masks.

**Tech Stack:** Qt 6.11, QtQuick/QML, Quickshell, Quickshell.Wayland layer shell, existing Afloat services, pure JavaScript helpers, QtTest/QML TestCase, Python unittest.

## Global Constraints

- Work on branch `lazer`; preserve unrelated `.opencode/package.json`, `docs/image.png`, and any concurrent user changes.
- Use the local osu!lazer source at `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu` as the visual and motion authority.
- Wiki, News, and Beatmap use one fixed per-screen wave owner at exactly 85% available screen width.
- The wave surface has no rounded outer corners, glass border, floating-card margin, or generic glass shadow.
- Implement all four wave layers at `13deg`, `-7deg`, `4deg`, and `-2deg`; do not simplify the reveal.
- Wave entry is 800ms: body `Easing.OutQuint`, waves `Easing.OutSine`.
- Wave exit is 500ms: body `Easing.InQuad` as the Qt approximation of osu!lazer `Easing.In`, waves `Easing.InSine`.
- Wiki uses a fixed Orange palette, News Purple, and Beatmap Blue; wallpaper-derived colours must not replace these palettes.
- Top bar placement joins the surface below the bar; bottom bar placement keeps the surface at the screen top and never mirrors motion.
- Settings uses a dedicated left owner, approximately 400px main content plus its rail, and a 600ms horizontal transition.
- Settings overlays the desktop and never moves external Wayland applications, the bar, islands, or other Afloat surfaces.
- Music uses a dedicated Now Playing owner and retains existing MPRIS properties and action signals.
- Only one owner may be interactive per screen; cross-owner transitions close the current owner before opening the pending target.
- Keep all `PanelWindow` outer geometry fixed during animation; animate only inner QML items.
- Use `implicitWidth`/`implicitHeight` on `PanelWindow`; never assign deprecated layer-shell `width`/`height`.
- Put `Keys.*` handlers on inner focused `Item`s, never directly on `PanelWindow`.
- Reduced motion removes large translation and wave movement while preserving opacity, callbacks, route cleanup, and focus semantics.
- Add a short English intent comment before each major QML declaration.
- After every QML edit, run the relevant QML test and fix every new WARN/ERROR before committing.
- Make conventional commits after each independently verified task; do not amend commits.

## File Map

- `modules/lazerbar/OverlayCoordinatorLogic.js`: target validation and owner classification.
- `modules/lazerbar/OverlayCoordinator.qml`: per-screen mutual exclusion, pending transitions, and focus ownership.
- `modules/lazerbar/FullscreenOverlayLogic.js`: wave-only geometry, Escape precedence, and layer constants.
- `modules/lazerbar/OsuOverlayPalette.js`: fixed Orange, Purple, and Blue overlay palettes.
- `modules/lazerbar/FullscreenWave.qml`: one clipped, rotated reveal layer.
- `modules/lazerbar/FullscreenOverlayHost.qml`: wave owner lifecycle, four layers, side close zones, and wave route loader.
- `modules/lazerbar/FullscreenHeader.qml`, `FullscreenSidebar.qml`: shared osu page structure.
- `modules/lazerbar/WikiLikePage.qml`, `NewsLikePage.qml`, `BeatmapLikePage.qml`: minimal static page layouts.
- `modules/lazerbar/LazerSettingsOverlay.qml`, `LazerSettingsPanel.qml`: left-side settings lifecycle and presentation.
- `modules/lazerbar/OsuMusicOverlay.qml`: dedicated Now Playing presentation and lifecycle.
- `modules/lazerbar/TopBar.qml`: three owner windows and service wiring.
- `modules/lazerbar/LazerBarLogic.js`, `UtilityZone.qml`, `qmldir`: route cleanup, button dispatch, and registrations.
- `.trellis/spec/frontend/quality-guidelines.md`: replace the rejected mixed-owner contract.

---

### Task 1: Overlay Coordinator Contract

**Files:**
- Create: `modules/lazerbar/OverlayCoordinatorLogic.js`
- Create: `modules/lazerbar/OverlayCoordinator.qml`
- Create: `tests/qml/tst_overlay_coordinator_logic.qml`
- Create: `tests/qml/tst_overlay_coordinator.qml`
- Modify: `modules/lazerbar/qmldir`

**Interfaces:**
- Produces `CoordinatorLogic.normalizeTarget(target): string`.
- Produces `CoordinatorLogic.ownerFor(target): "wave" | "settings" | "music" | ""`.
- Produces `CoordinatorLogic.isSameOwner(left, right): bool`.
- Produces `OverlayCoordinator.request(target, opener): bool`.
- Produces `OverlayCoordinator.ownerClosed(owner): void`.
- Produces properties `activeTarget`, `activeOwner`, `pendingTarget`, `transitioning`, and `opener`.
- Produces signals `openRequested(owner, target)`, `closeRequested(owner)`, and `routeRequested(target)`.

- [ ] **Step 1: Write failing pure logic tests**

Create `tests/qml/tst_overlay_coordinator_logic.qml` with these assertions:

```qml
compare(Logic.normalizeTarget("wiki"), "wiki")
compare(Logic.normalizeTarget("remote"), "")
compare(Logic.ownerFor("wiki"), "wave")
compare(Logic.ownerFor("settings"), "settings")
compare(Logic.ownerFor("music"), "music")
verify(Logic.isSameOwner("wiki", "news"))
verify(!Logic.isSameOwner("wiki", "settings"))
```

- [ ] **Step 2: Run the pure logic test and verify failure**

Run:

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_overlay_coordinator_logic.qml -o -,txt -v1
```

Expected: FAIL because `OverlayCoordinatorLogic.js` does not exist.

- [ ] **Step 3: Implement the pure target helpers**

Implement only these target groups:

```javascript
var targets = ["settings", "music", "wiki", "news", "beatmap"]
var waveTargets = ["wiki", "news", "beatmap"]

function normalizeTarget(target) {
    var candidate = target == null ? "" : String(target)
    return targets.indexOf(candidate) >= 0 ? candidate : ""
}

function ownerFor(target) {
    var normalized = normalizeTarget(target)
    if (waveTargets.indexOf(normalized) >= 0)
        return "wave"
    return normalized === "settings" || normalized === "music" ? normalized : ""
}

function isSameOwner(left, right) {
    var owner = ownerFor(left)
    return owner !== "" && owner === ownerFor(right)
}
```

- [ ] **Step 4: Run the pure test and verify pass**

Expected: PASS with no WARN/ERROR.

- [ ] **Step 5: Write failing coordinator lifecycle tests**

Create `tests/qml/tst_overlay_coordinator.qml` with `SignalSpy`s and cover these exact sequences:

```qml
verify(coordinator.request("wiki", opener))
compare(openSpy.signalArguments[0], ["wave", "wiki"])

verify(coordinator.request("news", opener))
compare(routeSpy.signalArguments[0], ["news"])

verify(coordinator.request("settings", opener))
compare(closeSpy.signalArguments[0], ["wave"])
compare(coordinator.pendingTarget, "settings")
coordinator.ownerClosed("wave")
compare(openSpy.signalArguments[1], ["settings", "settings"])

verify(coordinator.request("settings", opener))
compare(closeSpy.signalArguments[1], ["settings"])
coordinator.ownerClosed("settings")
compare(coordinator.activeTarget, "")
verify(opener.activeFocus)
```

Also assert that `request("remote", opener)` returns `false`, repeated requests while closing replace `pendingTarget`, and a stale `ownerClosed("music")` does nothing.

- [ ] **Step 6: Run the coordinator test and verify failure**

Expected: FAIL because `OverlayCoordinator` is not registered.

- [ ] **Step 7: Implement the minimal non-visual coordinator**

Use a `QtObject` with no visual children. `request()` opens from idle, emits `routeRequested()` for wave-to-wave changes, toggles the active target closed, or stores a pending target before emitting `closeRequested()`. `ownerClosed()` validates the closing owner, opens the latest pending target, or clears state and restores `opener.forceActiveFocus()`.

- [ ] **Step 8: Run both coordinator tests**

Run both new test files sequentially. Expected: PASS with no WARN/ERROR.

- [ ] **Step 9: Commit**

```bash
git add modules/lazerbar/OverlayCoordinatorLogic.js modules/lazerbar/OverlayCoordinator.qml modules/lazerbar/qmldir tests/qml/tst_overlay_coordinator_logic.qml tests/qml/tst_overlay_coordinator.qml
git commit -m "feat: add lazer overlay coordinator"
```

---

### Task 2: Wave Geometry, Motion, And Palette Primitives

**Files:**
- Modify: `modules/lazerbar/FullscreenOverlayLogic.js`
- Create: `modules/lazerbar/OsuOverlayPalette.js`
- Create: `modules/lazerbar/FullscreenWave.qml`
- Modify: `modules/lazerbar/MotionTokens.qml`
- Modify: `modules/lazerbar/qmldir`
- Modify: `tests/qml/tst_fullscreen_overlay_logic.qml`
- Create: `tests/qml/tst_fullscreen_wave.qml`

**Interfaces:**
- `FullscreenOverlayLogic.normalizeRoute()` accepts only `wiki`, `news`, and `beatmap`.
- Produces `surfaceWidth(screenWidth): number`, exactly `screenWidth * 0.85` after non-negative normalisation.
- Produces `surfaceTop(barPosition, barHeight): number`, returning clamped `barHeight` only for `top`.
- Produces `waveAngle(index): 13 | -7 | 4 | -2 | 0`.
- Produces `OverlayPalette.forRoute(route): { body, header, sidebar, light4, light3, dark4, dark3, text, muted, accent }`.
- Produces `FullscreenWave.progress`, `angle`, `colour`, and `finalOffset` presentation properties.
- Adds motion tokens `waveEnter = 800`, `waveExit = 500`, `waveRoute = 160`, and `settingsSlide = 600`.

- [ ] **Step 1: Replace old geometry expectations with failing wave expectations**

Update `tst_fullscreen_overlay_logic.qml`:

```qml
compare(Logic.normalizeRoute("wiki"), "wiki")
compare(Logic.normalizeRoute("settings"), "")
compare(Logic.surfaceWidth(1920), 1632)
compare(Logic.surfaceWidth(800), 680)
compare(Logic.surfaceTop("top", 46), 46)
compare(Logic.surfaceTop("bottom", 46), 0)
compare([0, 1, 2, 3].map(Logic.waveAngle), [13, -7, 4, -2])
```

Add palette assertions for Orange Wiki, Purple News, Blue Beatmap, stable body colours across repeated calls, and an empty object for invalid routes.

- [ ] **Step 2: Run the logic test and verify failure**

Expected: FAIL on the old clamped width and settings route acceptance.

- [ ] **Step 3: Implement wave-only logic, palettes, and timing tokens**

Remove settings/music from `FullscreenOverlayLogic.routes`; retain `escapeAction()`. Keep fixed hexadecimal colours in `OsuOverlayPalette.js` so pure QtTest does not import services. Add the four exact motion tokens to `MotionTokens.qml`.

- [ ] **Step 4: Run the logic test and verify pass**

Expected: PASS with no WARN/ERROR.

- [ ] **Step 5: Write the failing wave component test**

Create four `FullscreenWave` instances and assert:

```qml
compare(first.angle, 13)
compare(second.angle, -7)
compare(third.angle, 4)
compare(fourth.angle, -2)
first.progress = 0
compare(first.effectiveOffset, first.hiddenOffset)
first.progress = 1
compare(first.effectiveOffset, first.finalOffset)
```

Enable reduced motion and assert `effectiveOffset === finalOffset` while `opacity` still tracks progress.

- [ ] **Step 6: Implement one focused wave layer**

`FullscreenWave.qml` is a clipped `Item` containing one oversized rotated `Rectangle`. It exposes computed `hiddenOffset`, `effectiveOffset`, and an opacity-only reduced-motion path. It must not own timers or layer-shell geometry.

- [ ] **Step 7: Run wave and logic tests**

Expected: both PASS with no WARN/ERROR.

- [ ] **Step 8: Commit**

```bash
git add modules/lazerbar/FullscreenOverlayLogic.js modules/lazerbar/OsuOverlayPalette.js modules/lazerbar/FullscreenWave.qml modules/lazerbar/MotionTokens.qml modules/lazerbar/qmldir tests/qml/tst_fullscreen_overlay_logic.qml tests/qml/tst_fullscreen_wave.qml
git commit -m "feat: add osu wave overlay primitives"
```

---

### Task 3: Source-Faithful Wave Fullscreen Owner

**Files:**
- Modify: `modules/lazerbar/FullscreenOverlayHost.qml`
- Modify: `tests/qml/tst_fullscreen_overlay_host.qml`

**Interfaces:**
- Retains `openRoute(route, opener)`, `close()`, `handleEscape()`, `finishClose()`, `route`, `phase`, `routeItem`, `closed()`.
- Removes `settingsComponent` and `musicComponent`.
- Adds `barPosition`, `barHeight`, `bodyProgress`, `waveProgress`, `surfaceTop`, `surfaceWidth`, `palette`, and aliases `surface`, `outsideLeft`, `outsideRight` for testing.
- Accepts only `wiki`, `news`, and `beatmap`.

- [ ] **Step 1: Rewrite host tests to describe the approved surface**

Replace compatibility-route tests with assertions that an 800px host has a 680px surface, radius `0`, no border, four wave delegates in source order, and top offsets of 46px/0px for top/bottom bar modes. Assert invalid `settings` and `music` opens leave the host closed.

Add lifecycle checks:

```qml
host.openRoute("wiki", opener)
tryCompare(host, "phase", "open", 1000)
compare(host.bodyProgress, 1)
compare(host.waveProgress, 1)
host.close()
tryVerify(function() { return host.bodyProgress > 0 && host.bodyProgress < 1 }, 250)
var beforeReverse = host.bodyProgress
host.openRoute("news", opener)
verify(host.bodyProgress >= beforeReverse - 0.02)
```

Assert clicking `outsideLeft` or `outsideRight` enters `closing`, and same-owner `wiki -> news` keeps the shell visible while replacing `routeItem`.

- [ ] **Step 2: Run the host test and verify failure**

Expected: FAIL because the current host is a rounded centred card and still accepts Settings/Music.

- [ ] **Step 3: Replace the visual tree without changing the public lifecycle**

Use this major order inside the host:

```qml
MouseArea { id: outsideLeft }
MouseArea { id: outsideRight }
Item {
    id: clippedViewport
    clip: true
    Repeater { model: 4; FullscreenWave { /* angle and palette by index */ } }
    Item { id: surface; /* header + route loader */ }
}
```

Stop the current direction's animations before retargeting. Do not assign `bodyProgress = 0` when reopening from `closing`. Only a closed-to-opening transition starts at zero. Clear the route and restore focus only in `finishClose()`.

- [ ] **Step 4: Implement route replacement cross-fade**

Keep the owner open for wave-to-wave route changes. Fade the loader to zero over `MotionTokens.waveRoute / 2`, replace the component, then fade to one. Do not restart `bodyProgress` or `waveProgress`.

- [ ] **Step 5: Implement reduced motion lifecycle**

Use short `MotionTokens.fast` opacity animations, no large translations, and the same `phase` transitions and completion callbacks.

- [ ] **Step 6: Run host, wave, and logic tests**

Expected: all PASS. The host test may emit only the known offscreen QtTest window exposure warning; no component QML WARN/ERROR is accepted.

- [ ] **Step 7: Commit**

```bash
git add modules/lazerbar/FullscreenOverlayHost.qml tests/qml/tst_fullscreen_overlay_host.qml
git commit -m "feat: rebuild lazer fullscreen wave owner"
```

---

### Task 4: Wiki, News, And Beatmap UI Structure

**Files:**
- Modify: `modules/lazerbar/FullscreenHeader.qml`
- Modify: `modules/lazerbar/FullscreenSidebar.qml`
- Modify: `modules/lazerbar/WikiLikePage.qml`
- Modify: `modules/lazerbar/NewsLikePage.qml`
- Modify: `modules/lazerbar/BeatmapLikePage.qml`
- Create: `tests/qml/tst_osu_fullscreen_pages.qml`

**Interfaces:**
- `FullscreenHeader` consumes `title`, `description`, `breadcrumb`, and `palette`; emits `closeRequested()`.
- `FullscreenSidebar` consumes `entries`, `selected`, `palette`, and responsive `railWidth`; emits `selectedChangedByUser(value)`.
- Each page exposes `pageKind`, `paletteKind`, `sidebarItemCount`, and `sampleItemCount` read-only test properties.
- Beatmap static controls expose focus and selection state only; no query callback is added.

- [ ] **Step 1: Write structural identity tests before visual changes**

Create each page at `1200x720` and assert:

```qml
compare(wiki.pageKind, "wiki")
compare(wiki.paletteKind, "orange")
verify(wiki.sidebarItemCount >= 3)
verify(wiki.sampleItemCount >= 2)
compare(news.paletteKind, "purple")
verify(news.sidebarItemCount >= 3)
verify(news.sampleItemCount >= 3)
compare(beatmap.paletteKind, "blue")
verify(beatmap.sampleItemCount >= 4)
```

Also assert every outer page/card radius used for the primary layout is `0` or the source-specific inner-card value, never the old generic `10` rounded-glass treatment.

- [ ] **Step 2: Run the page test and verify failure**

Expected: FAIL because the test properties and palette-aware primitives do not exist.

- [ ] **Step 3: Rebuild shared header and sidebar**

Remove glass borders and generic dark-card styling. Use palette header/sidebar/body colours, osu-like title/description hierarchy, fixed alignment, and responsive rail width. Preserve close signal and sidebar selection interface.

- [ ] **Step 4: Rebuild the Wiki template**

Use Orange palette, location/header treatment, a table-of-contents rail, one article column, representative headings/links, and only a few paragraphs. The content must be sufficient to scroll but must not become a content-authoring task.

- [ ] **Step 5: Rebuild the News template**

Use Purple palette, archive rail, and three representative rows with source-like cover/date/title/summary proportions. Avoid generic bordered rounded cards.

- [ ] **Step 6: Rebuild the Beatmap template**

Use Blue palette, static filter controls, and at least four source-proportioned listing cards. Controls show hover/focus/selected states but do not filter the model.

- [ ] **Step 7: Run page and host tests**

Expected: PASS with no QML WARN/ERROR.

- [ ] **Step 8: Commit**

```bash
git add modules/lazerbar/FullscreenHeader.qml modules/lazerbar/FullscreenSidebar.qml modules/lazerbar/WikiLikePage.qml modules/lazerbar/NewsLikePage.qml modules/lazerbar/BeatmapLikePage.qml tests/qml/tst_osu_fullscreen_pages.qml
git commit -m "feat: match osu fullscreen page styling"
```

---

### Task 5: Left-Side Settings Owner

**Files:**
- Modify: `modules/lazerbar/LazerSettingsLogic.js`
- Modify: `modules/lazerbar/LazerSettingsOverlay.qml`
- Modify: `modules/lazerbar/LazerSettingsPanel.qml`
- Modify: `modules/lazerbar/LazerTheme.qml`
- Modify: `tests/qml/tst_lazer_settings_logic.qml`
- Modify: `tests/qml/tst_lazer_settings_overlay.qml`
- Modify: `tests/qml/tst_lazer_settings_panel.qml`

**Interfaces:**
- Produces `SettingsLogic.sidePanelWidth(availableWidth): number`, targeting `SettingsPanel` rail plus 400px main area and clamping only when the screen is narrower.
- `LazerSettingsOverlay.openFrom(opener)` always enters from the left.
- Keeps `closeAndRestoreFocus()`, `closeWithoutFocusRestore()`, `requestClose()`, `resetImmediately()`, `closed()`, and existing panel property aliases.
- Replaces vertical `panelOffsetY` with horizontal `panelOffsetX` and sets normal entry/exit to 600ms.

- [ ] **Step 1: Change settings logic and overlay tests first**

Add exact assertions:

```qml
compare(SettingsLogic.sidePanelWidth(1920), 616) // 216 rail + 400 content
compare(SettingsLogic.sidePanelWidth(900), 616)
verify(SettingsLogic.sidePanelWidth(500) <= 500)
compare(overlay.panelEnterDuration, 600)
compare(overlay.panelExitDuration, 600)
verify(overlay.panelOffsetX < 0)
compare(overlay.panelHost.x, overlay.panelOffsetX)
compare(overlay.panelHost.y, 0)
compare(overlay.panelHost.height, host.height)
```

Remove all top/bottom `entryDirection` assertions. Keep focus trap, scrim close, save binding, reopen-from-closing, and reduced-motion tests.

- [ ] **Step 2: Run settings tests and verify failure**

Run settings logic, panel, controls, pages, and overlay tests. Expected: overlay/logic failures only; existing save/control tests remain green.

- [ ] **Step 3: Implement left-side geometry and motion**

Anchor `panelHost` to the left, make its height equal the owner height, derive width from `sidePanelWidth()`, and compute `panelOffsetX = -panelHost.width * (1 - progress)` outside reduced motion. Entry and exit both use 600ms and remain interruptible from current `progress`.

- [ ] **Step 4: Replace glass panel styling with osu settings styling**

Remove the centred modal radius/border treatment. Keep existing settings pages and persistence bindings unchanged. Update rail, header, rows, and selected states to the fixed osu settings palette without importing wallpaper services into `LazerTheme`.

- [ ] **Step 5: Verify no other shell surface moves**

Keep all movement inside `LazerSettingsOverlay`; do not bind `TopBar`, `BarBackground`, island services, or compositor application geometry to settings progress.

- [ ] **Step 6: Run all settings tests**

Expected: PASS with no WARN/ERROR.

- [ ] **Step 7: Commit**

```bash
git add modules/lazerbar/LazerSettingsLogic.js modules/lazerbar/LazerSettingsOverlay.qml modules/lazerbar/LazerSettingsPanel.qml modules/lazerbar/LazerTheme.qml tests/qml/tst_lazer_settings_logic.qml tests/qml/tst_lazer_settings_overlay.qml tests/qml/tst_lazer_settings_panel.qml
git commit -m "feat: restore osu side settings panel"
```

---

### Task 6: Dedicated Now Playing Owner

**Files:**
- Modify: `modules/lazerbar/OsuMusicOverlay.qml`
- Modify: `tests/qml/tst_osu_music_overlay.qml`

**Interfaces:**
- Preserve all current presentation properties and signals: `titleText`, `artistText`, `playing`, `progress`, `shuffleActive`, capability booleans, transport signals, `playlistRequested()`, and `closeRequested()`.
- Preserve `open()`, `close()`, `focusFirstControl()`, `interactive`, and `openProgress`.
- Expose test aliases for the background, metadata block, controls, and progress track.

- [ ] **Step 1: Expand tests around the real Now Playing contract**

Keep progress clamping and signals. Add assertions for fixed local geometry, dedicated `openState`, disabled transport controls, focus order, Escape emission, and no fullscreen-sized implicit dimensions. Assert the component has no wave/page route properties.

- [ ] **Step 2: Run the music test and verify the new assertions fail**

Expected: FAIL only for new structural/style/focus assertions.

- [ ] **Step 3: Rework presentation without changing service interfaces**

Use the osu!lazer Now Playing hierarchy: visual background/art area, metadata, transport controls, and progress. Keep the component local and fixed-size; do not add a backdrop, wave layer, route loader, remote artwork fetch, volume control, or playlist implementation.

- [ ] **Step 4: Preserve interruptible and reduced-motion lifecycle**

Opening enables interaction and focuses the first enabled control. Closing disables interaction immediately and animates opacity/local offset only. Reduced motion removes offset and keeps a short fade.

- [ ] **Step 5: Run the music test**

Expected: PASS with no WARN/ERROR.

- [ ] **Step 6: Commit**

```bash
git add modules/lazerbar/OsuMusicOverlay.qml tests/qml/tst_osu_music_overlay.qml
git commit -m "feat: restore osu now playing overlay"
```

---

### Task 7: Top Bar Three-Owner Integration And Migration

**Files:**
- Modify: `modules/lazerbar/TopBar.qml`
- Modify: `modules/lazerbar/LazerBarLogic.js`
- Modify: `modules/lazerbar/UtilityZone.qml`
- Modify: `tests/qml/tst_lazer_bar_logic.qml`
- Modify: `tests/qml/tst_fullscreen_overlay_host.qml`
- Modify: `.trellis/spec/frontend/quality-guidelines.md`

**Interfaces:**
- `TopBar` delegates every target request to one `OverlayCoordinator` per screen.
- Coordinator `openRequested` dispatches to exactly one of `fullscreenHost.openRoute()`, `settingsOverlay.openFrom()`, or `musicOverlay.open()`.
- Coordinator `closeRequested` dispatches to the matching owner's no-focus-restore close path.
- Each owner completion calls `coordinator.ownerClosed(owner)`.
- `LeftZone.settingsActive` and `UtilityZone.musicActive` derive from `coordinator.activeTarget`.

- [ ] **Step 1: Update bar logic tests to reject mixed-host assumptions**

Remove `LazerBarLogic.nextOverlay()` tests because ownership now belongs to `OverlayCoordinator`. Keep utility visibility, formatting, and visual-state tests. Add route mapping assertions only where `UtilityZone` maps `library -> beatmap`, `wiki -> wiki`, and `news -> news`.

- [ ] **Step 2: Run the bar and coordinator tests before integration**

Expected: bar test fails until obsolete route logic is removed; coordinator tests stay green.

- [ ] **Step 3: Split `TopBar` into three persistent owner windows**

Use these owner geometries:

```qml
PanelWindow { // Wave owner: screen-sized, fixed
    implicitWidth: screen.width
    implicitHeight: screen.height
}
PanelWindow { // Settings owner: fixed maximum panel geometry
    implicitWidth: settingsOverlay.requiredWidth
    implicitHeight: screen.height
}
PanelWindow { // Now Playing owner: local fixed geometry
    implicitWidth: musicOverlay.implicitWidth
    implicitHeight: musicOverlay.implicitHeight
}
```

The wave mask is active through opening/opening interaction and side close zones, then cleared on completed close. Settings and Music masks remain limited to their visible local content. Do not reintroduce Settings/Music `Component`s inside `FullscreenOverlayHost`.

- [ ] **Step 4: Wire coordinator sequencing and focus**

Opening Settings uses `leftContent.settingsButtonItem` as opener; Music uses `utilityContent.musicButtonItem`; wave routes use the clicked utility button when available. Cross-owner close calls no-focus-restore variants. Final close is the coordinator's sole focus-restoration point.

- [ ] **Step 5: Remove obsolete mixed owner code**

Delete `LazerBarLogic.nextOverlay()`, `FullscreenOverlayHost.settingsComponent`, `musicComponent`, compatibility route tests, and comments describing one owner for every route. Do not add fallback branches.

- [ ] **Step 6: Replace the frontend quality guideline scenario**

Rewrite `Shared Fullscreen Route Owner` as `Coordinated Overlay Owners`. Document the wave-only shared owner, dedicated Settings/Music owners, fixed outer windows, pending cross-owner transition, mask boundaries, Escape precedence, and required tests.

- [ ] **Step 7: Run integration-adjacent tests**

Run coordinator, bar logic, fullscreen host, settings overlay/panel, and music overlay tests sequentially. Expected: PASS with no new WARN/ERROR.

- [ ] **Step 8: Commit**

```bash
git add modules/lazerbar/TopBar.qml modules/lazerbar/LazerBarLogic.js modules/lazerbar/UtilityZone.qml tests/qml/tst_lazer_bar_logic.qml tests/qml/tst_fullscreen_overlay_host.qml .trellis/spec/frontend/quality-guidelines.md
git commit -m "refactor: split lazer overlay surface owners"
```

---

### Task 8: Full Verification And Task Completion

**Files:**
- Modify only if verification exposes a defect in files already owned by Tasks 1-7.
- Update: `.trellis/tasks/08-15-osu-fullscreen-visual-calibration/implement.md`

**Interfaces:**
- Produces no new product API.
- Confirms every PRD acceptance criterion and records exact verification commands/results.

- [ ] **Step 1: Run all plugin-independent QML tests sequentially**

Run every `tests/qml/tst_*.qml` that can load under `/usr/lib/qt6/bin/qmltestrunner`, one process at a time. Do not parallelise overlay tests because focus and window activation are timing-sensitive.

Expected: all loadable tests PASS. Record plugin-load skips separately; do not classify missing Quickshell/MPRIS imports in plain `qmltestrunner` as feature regressions.

- [ ] **Step 2: Run Python backend tests**

```bash
python -m unittest discover -s scripts/tests -v
```

Expected: PASS.

- [ ] **Step 3: Check whitespace and launch the real shell**

```bash
git diff --check
timeout 12s qs -p .
```

Expected: `Configuration Loaded`; no new QML WARN/ERROR. The existing notification D-Bus ownership warning is environmental only when another notification server is confirmed active.

- [ ] **Step 4: Manually verify observable geometry**

Open Wiki, News, Beatmap, Settings, and Music from the bar. Confirm:

- Wave pages are 85% wide, unrounded, four-layered, and enter/exit vertically.
- Top-bar mode joins below the bar; bottom-bar mode remains top-based.
- Side zones close wave pages without click-through.
- Settings enters from the left without moving applications or shell surfaces.
- Music remains local near its top-bar entry.
- Cross-owner requests never leave two interactive owners.
- Reduced motion removes large movement while lifecycle and focus remain correct.

- [ ] **Step 5: Review the final diff and worktree boundary**

```bash
git status --short
git diff --check
git log --oneline -10
```

Verify `.opencode/package.json`, `docs/image.png`, and unrelated concurrent changes are neither staged nor modified by this task.

- [ ] **Step 6: Record verification and commit any planning-status update**

If no product fix was required, update only the Trellis execution record and commit:

```bash
git add .trellis/tasks/08-15-osu-fullscreen-visual-calibration/implement.md
git commit -m "chore: record osu overlay verification"
```

If verification required a product fix, rerun the failing targeted test first, commit that fix with its own conventional message, then rerun Steps 1-5 before recording completion.

## Final Completion Gate

- Every task has its own passing targeted tests and conventional commit.
- No Settings or Music route remains inside `FullscreenOverlayHost`.
- No rounded glass outer shell remains on Wiki, News, or Beatmap.
- Four wave angles, fixed palettes, exact durations, reversal, side close, and reduced motion are tested.
- Settings persistence and MPRIS controls remain functional.
- Frontend quality guidance matches the three-owner architecture.
- Full QML/Python verification, `git diff --check`, and real `qs -p .` launch pass.
