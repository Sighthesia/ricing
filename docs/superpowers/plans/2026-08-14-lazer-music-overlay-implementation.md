# Lazer Music Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an osu!lazer-style music top-bar button and a non-exclusive, MPRIS-backed music control overlay to each screen.

**Architecture:** A dedicated `OsuTopBarButton` owns active/hover/flash state while `OsuMusicOverlay` owns fixed card content and keyboard control behavior. `TopBar` creates persistent non-exclusive panel and tooltip windows per screen, binds presentation to existing media services, and keeps all outer window geometry fixed while animating only inner items.

**Tech Stack:** Qt 6, QtQuick/QML, Quickshell, Quickshell.Wayland, existing Afloat singleton services, QtTest, bundled SVG.

## Global Constraints

- Work on branch `lazer` and preserve unrelated `docs/image.png`.
- Use native QML only; do not add React, CSS, Tailwind, or icon-font dependencies.
- Use existing motion tokens: 70/100/160/240/320ms; normalize flash and panel entrance to 160ms.
- Tooltip hover delay is exactly 200ms and is not a visual animation duration.
- Reduced motion removes scale/Y movement while retaining opacity and color transitions.
- Music windows use `exclusionMode: ExclusionMode.Ignore` and never reserve workspace.
- Keep layer-shell outer geometry fixed; animate only inner opacity and transform.
- Close paths disable input synchronously before visual exit.
- Add a short English comment before major QML declarations.
- After each QML task, run the relevant test and remove every WARN/ERROR line.
- Commit each independently verified task with a conventional commit message.

---

### Task 1: Music Tokens, Icons, And Top-Bar Button

**Files:**
- Modify: `modules/lazerbar/LazerTheme.qml`
- Modify: `modules/lazerbar/qmldir`
- Create: `modules/lazerbar/OsuTopBarButton.qml`
- Create: `modules/lazerbar/icons/shuffle.svg`
- Create: `modules/lazerbar/icons/previous.svg`
- Create: `modules/lazerbar/icons/play.svg`
- Create: `modules/lazerbar/icons/pause.svg`
- Create: `modules/lazerbar/icons/next.svg`
- Create: `modules/lazerbar/icons/playlist.svg`
- Create: `tests/qml/tst_osu_top_bar_button.qml`

**Interfaces:**
- Produces `OsuTopBarButton.isActive`, `hovered`, `isFlashing`, `iconSource`, `titleText`, `subtitleText`, `clicked()`.
- Produces test overrides `testMode`, `forceHoverForTest`, and `triggerFlash()`.
- Produces theme colors `osuButtonActive`, `osuButtonHover`, `musicBackground`, `musicGold`, and `musicMuted`.

- [ ] **Step 1: Write the failing button test**

Test rest, hover, active, disabled, flash, tooltip delay state, keyboard activation, and reduced motion. Assert exact colors and `flashOpacity` starting at 0.6 before reaching zero.

- [ ] **Step 2: Run the failing test**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_osu_top_bar_button.qml -o -,txt -v1`

Expected: type unavailable.

- [ ] **Step 3: Implement tokens and button**

Use one persistent rounded background, one masked icon, one topmost white flash rectangle, `HoverHandler`, `TapHandler`, and Keys handlers. Hover background is `#333744`, active is `#EB1C60`, radius is 6, rest icon opacity is 0.8. `triggerFlash()` sets 0.6 synchronously and retargets one NumberAnimation to zero over 160ms.

Expose `tooltipRequested` after a 200ms Timer but do not render below the 46px host window; Task 3 owns the tooltip window.

- [ ] **Step 4: Create and validate generic SVG controls**

Use white opaque, 24x24 mask-compatible geometry. Run `xmllint --noout modules/lazerbar/icons/{shuffle,previous,play,pause,next,playlist}.svg`.

- [ ] **Step 5: Run the test cleanly**

Expected: all cases pass with no WARN/ERROR.

- [ ] **Step 6: Commit**

```bash
git add modules/lazerbar/LazerTheme.qml modules/lazerbar/qmldir modules/lazerbar/OsuTopBarButton.qml modules/lazerbar/icons tests/qml/tst_osu_top_bar_button.qml
git commit -m "feat: add osu top bar music button"
```

---

### Task 2: Music Overlay Content And Controls

**Files:**
- Create: `modules/lazerbar/MusicControlButton.qml`
- Create: `modules/lazerbar/OsuMusicOverlay.qml`
- Modify: `modules/lazerbar/qmldir`
- Create: `tests/qml/tst_osu_music_overlay.qml`

**Interfaces:**
- Produces presentation properties and action signals exactly as specified in the design.
- Produces `openProgress`, `interactive`, `effectiveYOffset`, `open()`, `close()`, and `focusFirstControl()`.
- Produces `closeRequested()` on Escape.

- [ ] **Step 1: Write failing overlay tests**

Assert 340x130 geometry, title/artist defaults, progress clamp at negative and above-one values, shuffle toggle, transport disabled blocking, play/pause source state, playlist signal, Escape signal, 160ms open and 100ms close, and reduced-motion Y suppression.

- [ ] **Step 2: Run the failing test**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_osu_music_overlay.qml -o -,txt -v1`

- [ ] **Step 3: Implement fixed card and controls**

Use a persistent 340x130 root, a 10px rounded `#12131A` card, subtle border/shadow, centered metadata, five fixed-size controls, and bottom-edge 4px progress. Use gold `#FFD000` for Shuffle and progress. The large play/pause control uses a circular white outline.

- [ ] **Step 4: Implement keyboard and lifecycle**

Tab/Shift+Tab and Left/Right traverse controls; disabled transport controls are skipped. Enter/Space activates. Escape emits close. Open animates opacity plus Y from -4 over 160ms; close reverses over 100ms after setting `interactive` false. Reduced motion leaves Y at zero.

- [ ] **Step 5: Run tests cleanly and commit**

```bash
git add modules/lazerbar/MusicControlButton.qml modules/lazerbar/OsuMusicOverlay.qml modules/lazerbar/qmldir tests/qml/tst_osu_music_overlay.qml
git commit -m "feat: add osu music overlay controls"
```

---

### Task 3: Per-Screen Window And Real Media Integration

**Files:**
- Modify: `modules/lazerbar/UtilityZone.qml`
- Modify: `modules/lazerbar/TopBar.qml`
- Create: `tests/qml/tst_lazer_music_integration.qml`

**Interfaces:**
- `UtilityZone.musicActive` controls the dedicated button.
- `UtilityZone.musicButtonItem` exposes focus restoration geometry.
- `UtilityZone.musicOverlayRequested(bool open)` toggles the screen-local panel.
- `TopBar` binds display state to `Services.MediaControlService` and actions to `Services.MediaService`.

- [ ] **Step 1: Write integration-facing component tests**

Test that the utility music entry is `OsuTopBarButton`, toggles active state, emits requested open state, and leaves other entries as generic `IconButton`s. Test host geometry helpers without importing MPRIS.

- [ ] **Step 2: Replace only the music utility delegate**

Keep entry order and responsive behavior. Branch the delegate with a Loader or dedicated trailing music component so the existing seven generic entries stay unchanged. Expose button state and signals to `TopBar`.

- [ ] **Step 3: Add fixed non-exclusive overlay and tooltip windows**

For each screen, create:

- A fixed transparent 340px overlay window anchored top/right with top margin 46 and right alignment shared with the utility group.
- A small transparent tooltip window aligned beneath the music button.
- `exclusionMode: ExclusionMode.Ignore` on both.
- Empty input mask immediately on close; card-only mask while open.

Do not animate PanelWindow size or margins per frame.

- [ ] **Step 4: Wire real media services**

Import `../../services` as Services. Bind title, artist, progress, playing, and capability flags to `MediaControlService`. Call `MediaService.previous()`, `playPause()`, and `next()` from matching signals. Keep shuffle local and playlist signal-only.

- [ ] **Step 5: Verify tests and shell startup**

Run all new tests, relevant existing lazer tests, then `timeout 8s qs -p .`. Require no WARN/ERROR.

- [ ] **Step 6: Commit**

```bash
git add modules/lazerbar/UtilityZone.qml modules/lazerbar/TopBar.qml tests/qml/tst_lazer_music_integration.qml
git commit -m "feat: connect lazer music overlay"
```

---

### Task 4: Full Regression And Final Motion Review

**Files:**
- Modify only files proven faulty by verification.

- [ ] **Step 1: Run every new and existing lazer QML test**

Run the two new component tests, integration test, and all `tst_lazer_*.qml` files individually with `/usr/lib/qt6/bin/qmltestrunner`.

- [ ] **Step 2: Validate SVG and startup**

Run `xmllint` for every icon and `timeout 8s qs -p .`. Treat timeout 124 as expected only when logs contain no WARN/ERROR.

- [ ] **Step 3: Verify live MPRIS behavior**

With an available player, verify title/artist/progress updates and Previous/PlayPause/Next work. Verify the window never changes workspace exclusive geometry and closes input before fading out.

- [ ] **Step 4: Inspect repository state**

Run `git diff --check`, `git status --short --branch`, and `git log --oneline backend-only..HEAD`. Leave `docs/image.png` untouched.

- [ ] **Step 5: Commit only required fixes**

If verification changes code, stage exact files and commit `fix: finalize lazer music overlay`. Do not create an empty commit.
