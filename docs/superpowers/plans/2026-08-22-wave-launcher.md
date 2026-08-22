# Wave Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or an equivalent task-by-task execution workflow. Steps use checkbox syntax for tracking.

**Goal:** Replace the deprecated content-oriented wave overlay with a reusable full-screen wave shell that opens a keyboard-first launcher for apps, clipboard entries, and shortcuts.

**Architecture:** Extract the generic 85% wave window, body, backdrop, sidebar, header, focus, mask, and lifecycle from `FullscreenOverlayHost` into `WaveSurfaceHost`. Put all launcher-specific query, mode, result, sorting, selection, execution, and error behavior in `LauncherPage`, driven by a dedicated `LauncherService` contract. Update the top-bar/shortcut entry path to open the launcher directly, and remove Wiki/News/Beatmap route logic from the new frontend.

**Tech Stack:** Quickshell, QtQuick/QML, QtTest, QML singleton services, `.pragma library` JavaScript logic modules, existing `Afloat.LazerBar` qmldir registration, existing settings-panel visual and motion contracts.

## Global Constraints

- Treat `IslandService`, old Island pages, and old Island entry points as deprecated and do not use them.
- The first release contains only Apps, Clipboard, and Shortcuts launcher modes; control-center contents are out of scope.
- The launcher opens directly from the top-bar launcher entry or keyboard shortcut.
- The search field receives focus on open before the first user keystroke.
- Empty application queries show all applications sorted by favorite weight, recent-use timestamp, locale-aware name, then stable identifier.
- `>clip ` and `>key ` select clipboard and shortcut data sources without leaving the wave surface.
- Successful execution closes the surface; empty, loading, data-source failure, and execution failure states keep it open.
- Major surfaces use the project osu!lazer sharp geometry; reuse settings-panel highlight, click-flash, focus, and motion contracts.
- The wave window remains below the top bar geometry and must not cover it visually or interactively.
- After every QML change, run the relevant QML tests and fix newly introduced WARN/ERROR lines.
- Do not modify unrelated pre-existing notification changes in the worktree.

## File Map

### Generic wave shell

- Create: `modules/lazerbar/WaveSurfaceHost.qml` — generic fullscreen wave owner and content host.
- Create: `modules/lazerbar/WaveSurfaceLogic.js` — pure route, geometry, lifecycle-action, and keyboard helpers extracted from content-specific logic.
- Modify: `modules/lazerbar/FullscreenWave.qml` — retain only generic wave rendering and verify the tuned backdrop timing/opacity contract.
- Modify: `modules/lazerbar/FullscreenHeader.qml` — accept launcher title/description data without Wiki/News/Beatmap assumptions.
- Modify: `modules/lazerbar/FullscreenSidebar.qml` — render the host-provided three launcher entries and active mode.
- Modify: `modules/lazerbar/qmldir` — register the new shell and launcher components; remove deprecated content registrations.

### Launcher behavior and services

- Create: `services/LauncherLogic.js` — pure prefix parsing, stable sorting, selection clamping, and keyboard action decisions.
- Modify: `services/LauncherService.qml` — own launcher session state, mode/query synchronization, result refresh, execution outcomes, and IPC entry points without Island delegation.
- Modify: `services/qmldir` — keep the standalone `LauncherService` registration; no additional singleton is introduced by this slice.
- Create: `modules/lazerbar/LauncherPage.qml` — launcher search field, result viewport, empty/loading/error states, and mode wiring.
- Create: `modules/lazerbar/LauncherResultRow.qml` — sharp result row with keyboard, hover, click, and selected feedback.

### Integration and tests

- Modify: `modules/lazerbar/TopBar.qml` — host the generic wave surface and open `launcher` directly from the top-bar launcher control/shortcut path.
- Modify: `modules/lazerbar/OverlayCoordinator.qml` and `modules/lazerbar/OverlayCoordinatorLogic.js` — remove deprecated Wiki/News/Beatmap wave targets while retaining serialized settings/music ownership and adding launcher ownership.
- Create: `tests/qml/tst_launcher_logic.qml` — pure launcher parsing, sorting, selection, and action tests.
- Create: `tests/qml/tst_launcher_service.qml` — service state, mode/query, refresh, and execution-result tests with controlled fixtures.
- Create: `tests/qml/tst_launcher_page.qml` — focus, mode switching, selection, empty/error rendering, keyboard, and pointer behavior.
- Create: `tests/qml/tst_wave_surface_host.qml` — generic shell geometry, top-bar exclusion, focus restoration, route lifecycle, and reduced-motion tests.
- Create: `tests/qml/tst_wave_surface_logic.qml` — generic host geometry and keyboard helper tests.
- Remove only after all references are migrated: `modules/lazerbar/FullscreenOverlayHost.qml`, `modules/lazerbar/FullscreenOverlayLogic.js`, `modules/lazerbar/WikiLikePage.qml`, `modules/lazerbar/NewsLikePage.qml`, `modules/lazerbar/BeatmapLikePage.qml`, `tests/qml/tst_fullscreen_overlay_host.qml`, `tests/qml/tst_fullscreen_overlay_logic.qml`, and their registrations.

---

### Task 1: Lock launcher pure behavior

**Files:**
- Create: `services/LauncherLogic.js`
- Create: `tests/qml/tst_launcher_logic.qml`

**Interfaces:**
- Produces `parseQuery(query) -> { mode: string, text: string, prefix: string }` for `apps`, `clipboard`, and `shortcuts`.
- Produces `sortResults(items) -> array` using favorite weight descending, recent-use timestamp descending, locale-aware display name ascending, and stable identifier ascending.
- Produces `clampSelection(index, count) -> integer`.
- Produces `keyboardAction(key, hasInput, hasSelection, interactive) -> string` with `up`, `down`, `execute`, `clear`, `close`, or `none`.

- [ ] **Step 1: Add failing pure-logic tests** for blank/app queries, `>clip `, `>key `, whitespace normalization, stable sorting ties, empty-list clamping, out-of-range clamping, and Escape/Enter/Up/Down action precedence.
- [ ] **Step 2: Run the focused test and confirm it fails**.

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_logic.qml -o -,txt`

  Expected: FAIL because `services/LauncherLogic.js` does not yet provide the functions.

- [ ] **Step 3: Implement the pure helpers** with defensive numeric/string normalization and no QML or service dependencies.
- [ ] **Step 4: Run the focused test and confirm it passes**.

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_logic.qml -o -,txt`

- [ ] **Step 5: Commit** with `test(launcher): define launcher query and sorting contracts` after inspecting the diff.

### Task 2: Replace Island delegation with launcher service state

**Files:**
- Modify: `services/LauncherService.qml`
- Modify: `services/qmldir`
- Modify: backend fixtures or service test support only where the existing repository pattern requires it.
- Create: `tests/qml/tst_launcher_service.qml`

**Interfaces:**
- `LauncherService.visible`, `query`, `mode`, `results`, `loading`, `error`, and `selectedIndex` are observable state.
- `LauncherService.open()`, `close()`, `toggle()`, `refresh()`, `selectNext()`, `selectPrevious()`, `executeSelected()`, and `execute(item)` are callable operations.
- Data-source adapters expose `refresh(query, mode)` and `execute(item)` results to the service; tests inject deterministic fixtures instead of shelling out.

- [ ] **Step 1: Add failing service tests** for open defaults to `apps`, query-prefix mode transitions, refresh state, result selection clamping, successful execution closing, failed execution preserving visibility, and explicit error state.
- [ ] **Step 2: Run the service test and confirm it fails**.

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_service.qml -o -,txt`

- [ ] **Step 3: Refactor `LauncherService.qml`** so it no longer calls `IslandService.showLauncher()`, `IslandService.close()`, or reads Island page state. Keep IPC targets needed by the new launcher entry and expose a fixture-friendly adapter seam.
- [ ] **Step 4: Implement query refresh sequencing** so stale refresh results cannot replace a newer query/mode, while loading/error state remains visible in the current session.
- [ ] **Step 5: Run the service test and confirm it passes**.
- [ ] **Step 6: Commit** with `feat(launcher): own standalone launcher session state`.

### Task 3: Extract and test the generic wave shell

**Files:**
- Create: `modules/lazerbar/WaveSurfaceHost.qml`
- Create: `modules/lazerbar/WaveSurfaceLogic.js`
- Modify: `modules/lazerbar/FullscreenHeader.qml`
- Modify: `modules/lazerbar/FullscreenSidebar.qml`
- Modify: `modules/lazerbar/FullscreenWave.qml`
- Modify: `modules/lazerbar/qmldir`
- Create or rename: `tests/qml/tst_wave_surface_logic.qml`
- Create or rename: `tests/qml/tst_wave_surface_host.qml`

**Interfaces:**
- `WaveSurfaceHost.openRoute(route, source)`, `close()`, `handleEscape()`, and `finishClose()` own generic surface lifecycle.
- Host properties include `route`, `phase`, `bodyProgress`, `waveProgress`, `title`, `description`, `sidebarEntries`, `activeSidebarId`, and a content component/slot.
- Host emits `closed()` and a mode/route selection signal without interpreting launcher data.

- [ ] **Step 1: Create `tst_wave_surface_logic.qml` and `tst_wave_surface_host.qml`** by preserving the existing generic geometry, top-bar-below placement, wave progress, outside close zones, focus restoration, route lifecycle, and reduced-motion assertions while removing Wiki/News/Beatmap-specific palette and component assertions.
- [ ] **Step 2: Run the new shell tests and confirm they fail because `WaveSurfaceHost` and `WaveSurfaceLogic.js` do not yet exist**.
- [ ] **Step 3: Extract generic geometry and keyboard helpers** from `FullscreenOverlayLogic.js` into `WaveSurfaceLogic.js`, retaining explicit validation for launcher route and future route extension.
- [ ] **Step 4: Move the fixed viewport, waves, body animation, header, sidebar, outside zones, mask assumptions, and content loader into `WaveSurfaceHost.qml`**. Preserve the current top-bar exclusion geometry and the tuned `waveBackdropEnter` timing.
- [ ] **Step 5: Make `FullscreenHeader` and `FullscreenSidebar` data-driven**: header accepts title/breadcrumb/description, sidebar accepts entries and active id; neither contains old content route branches.
- [ ] **Step 6: Run shell tests and `qmllint`**.

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wave_surface_logic.qml -o -,txt`

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wave_surface_host.qml -o -,txt`

  Run: `qmllint modules/lazerbar/WaveSurfaceHost.qml modules/lazerbar/FullscreenHeader.qml modules/lazerbar/FullscreenSidebar.qml modules/lazerbar/FullscreenWave.qml`

- [ ] **Step 7: Commit** with `refactor(lazerbar): extract reusable wave surface host`.

### Task 4: Build launcher page and result presentation

**Files:**
- Create: `modules/lazerbar/LauncherPage.qml`
- Create: `modules/lazerbar/LauncherResultRow.qml`
- Create: `tests/qml/tst_launcher_page.qml`
- Modify: `modules/lazerbar/qmldir`

**Interfaces:**
- `LauncherPage` consumes the observable `LauncherService` state and calls `refresh`, `selectNext`, `selectPrevious`, `executeSelected`, and `execute(item)`.
- `LauncherPage` provides `title`, `description`, `sidebarEntries`, and a mode-change signal to `WaveSurfaceHost`.
- `LauncherResultRow` consumes one normalized result item plus `selected` and emits `activated()`.

- [ ] **Step 1: Add failing component tests** for initial search focus, all three sidebar entries, mode switching without surface restart, result selection, Enter execution, Up/Down navigation, pointer activation, empty state, loading state, and error/retry state.
- [ ] **Step 2: Run the component test and confirm it fails**.

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_page.qml -o -,txt`

- [ ] **Step 3: Implement `LauncherResultRow.qml`** with fixed-height sharp geometry, icon/title/description metadata, selected highlight, hover feedback, keyboard focus feedback, and click activation using existing settings-panel feedback contracts.
- [ ] **Step 4: Implement `LauncherPage.qml`** with an auto-focused search field, mode sidebar wiring, prefix updates, result viewport, selected-index binding, and keyboard event handling on an inner focusable Item rather than a `PanelWindow`.
- [ ] **Step 5: Render explicit loading, empty, error, and retry states** without replacing the search field or dropping focus.
- [ ] **Step 6: Run the component tests and `qmllint`**.

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_page.qml -o -,txt`

  Run: `qmllint modules/lazerbar/LauncherPage.qml modules/lazerbar/LauncherResultRow.qml`

- [ ] **Step 7: Commit** with `feat(lazerbar): add keyboard-first launcher page`.

### Task 5: Wire direct top-bar and shortcut opening

**Files:**
- Modify: `modules/lazerbar/TopBar.qml`
- Modify: `modules/lazerbar/OverlayCoordinator.qml`
- Modify: `modules/lazerbar/OverlayCoordinatorLogic.js`
- Modify: `modules/lazerbar/qmldir`
- Add or modify integration tests covering the new opener path.

**Interfaces:**
- Top-bar launcher activation calls the standalone launcher open path and passes its opener Item for focus restoration.
- The coordinator owns the new launcher surface transition alongside the retained settings/music owners; it does not route to deprecated Wiki/News/Beatmap content.
- `WaveSurfaceHost` is mounted in a PanelWindow whose top/bottom margins keep the bar uncovered for top and bottom bar positions.

- [ ] **Step 1: Add failing integration assertions** that launcher activation opens `launcher`, focuses the search field, does not open Island, preserves existing settings/music coordinator ownership, and restores opener focus after close.
- [ ] **Step 2: Replace the wave owner in `TopBar.qml`** with `WaveSurfaceHost`, bind `LauncherPage` as its content, and preserve the existing below-bar geometry and mask behavior.
- [ ] **Step 3: Reduce coordinator wave targets to `launcher`**, retain `settings` and `music` owners unchanged, and remove old Wiki/News/Beatmap normalization and route-switch assumptions.
- [ ] **Step 4: Connect keyboard shortcut IPC** to `LauncherService.open()` and ensure opening an already-open launcher focuses the current search session rather than creating a second instance.
- [ ] **Step 5: Run integration tests and `qs -p .`**.

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_overlay_coordinator.qml -o -,txt`

  Run: `timeout 8 qs -p .`

- [ ] **Step 6: Commit** with `feat(lazerbar): open launcher through wave surface`.

### Task 6: Remove deprecated content routes and finish verification

**Files:**
- Modify: `modules/lazerbar/qmldir`
- Remove after reference search: `modules/lazerbar/FullscreenOverlayHost.qml`, `modules/lazerbar/FullscreenOverlayLogic.js`, `modules/lazerbar/WikiLikePage.qml`, `modules/lazerbar/NewsLikePage.qml`, `modules/lazerbar/BeatmapLikePage.qml`, and obsolete route tests.
- Modify only tests that still reference removed route names.

**Interfaces:**
- The new frontend has no Wiki, News, or Beatmap route registrations, constructors, palette branches, or sidebar entries.
- The generic shell remains independently usable by `launcher` and future routes.

- [ ] **Step 1: Search all QML, JS, qmldir, and tests** for `wiki`, `news`, `beatmap`, `FullscreenOverlayHost`, `FullscreenOverlayLogic`, and `IslandService`; classify each occurrence as required backend behavior or deprecated frontend reference.
- [ ] **Step 2: Remove deprecated frontend route files and registrations** only after the launcher path no longer imports or references them.
- [ ] **Step 3: Run all launcher and wave tests sequentially** to avoid focus/timing interference.

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_logic.qml -o -,txt`

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_service.qml -o -,txt`

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_page.qml -o -,txt`

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wave_surface_logic.qml -o -,txt`

  Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wave_surface_host.qml -o -,txt`

- [ ] **Step 4: Run static and runtime verification**.

  Run: `qmllint modules/lazerbar services tests/qml`

  Run: `git diff --check`

  Run: `timeout 8 qs -p .`

  Expected: no new QML WARN/ERROR lines; existing environment warnings must be identified separately rather than attributed to this feature.

- [ ] **Step 5: Review acceptance criteria** from `docs/superpowers/specs/2026-08-22-wave-launcher-design.md`, inspect `git diff`, and commit with `chore(lazerbar): remove deprecated wave content routes`.
