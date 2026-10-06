# Control Center View Port Report

## Changed files

- `modules/lazerbar/WaveSurfaceLogic.js`: reduced Wave routes to `launcher`.
- `modules/lazerbar/OverlayCoordinatorLogic.js`: removed `control-center` from coordinator targets and made the wave entry method uniformly `requestOpen`.
- `modules/lazerbar/LauncherSurface.qml`: kept one launcher route, removed control-center route handoff and entry-context wiring, and forwarded the seven services through `LauncherPage`.
- `modules/lazerbar/LauncherPage.qml`: added four peer `sectionEntries`, page-local `controlCenterActive`, retained `ControlCenter` Loader, service forwarding, chrome visibility gates, Escape precedence, and hidden-list input isolation.
- `modules/lazerbar/ControlCenter.qml`: removed route-page chrome and launcher-entry back signaling; retained detail sub-pages, `handleBack()`, and `focusDefault()`.
- `modules/lazerbar/ControlCenterLogic.js`: changed `backAction()` to return `detail` or `none` without an entry-context argument.
- `modules/lazerbar/FullscreenSidebar.qml`: restored one peer-entry rail without footer partitioning.
- `modules/bar/TopBar.qml` and `modules/lazerbar/TopBar.qml`: reconciled service-owner comments to describe the view rather than a route.

## Design mapping

The old reference's retained view model was ported onto main's current wiki-style chrome. `LauncherPage` now publishes `sectionEntries` and `activeSectionId`; all four entries are peers and no footer marker is emitted. Control Center is mounted over the existing content area by one retained Loader, while the query surface, category bar, result list, and preview remain geometrically retained but hidden. The session query is untouched when entering or leaving the view, so the mode prefix, typed text, and editor caret survive.

Escape is handled by the page in this order: Control Center detail back, leave Control Center, clear query text to the active mode prefix, then decline so the host can close. Arrow and Return paths are guarded both at the page key handler and at their navigation/execution functions while the view is active.

## Static checks

- Required legacy-reference grep across `modules/` and `services/`: zero matches for `controlCenterRequested`, `requestControlCenter`, `footerEntries`, `primaryEntries`, `section: "footer"`, `enteredFromLauncher`, `returnToDefaultRoute`, `requestedFromLauncher`, and `overviewBackRequested`.
- Route grep: `WaveSurfaceLogic.js` has `routes = ["launcher"]`; `OverlayCoordinatorLogic.js` has targets `settings`, `music`, and `launcher`, with `waveTargets = ["launcher"]`; `LauncherSurface.qml` registers only `launcher`.
- `git diff --check`: passed.
- Tests were not recreated or run, per requirements.

## Shell gate

`scripts/check-shell.sh` was run with no Afloat shell running. It reported `no running Afloat shell found` and exited `2`, as expected. No shell was started.

## Residual risks

- Runtime QML loading and focus behavior remain unverified until the user's shell is restarted; the mandated shell gate cannot load a second shell in this worktree.
- The retained Control Center Loader keeps its detail object alive between view switches but closes any active detail sub-page when the launcher session closes, so a fresh launcher open always starts at the overview.
- Existing service and compositor diagnostics, if any, will only be visible through the next live `check-shell.sh` run after restart.
