# Implementation Plan

## Preconditions

- User has approved all four design sections.
- User must review and approve the committed written spec before `task.py start`.
- Load frontend, QML declaration-comment, visual-transition, and relevant animation/layout skills before product edits.

## Ordered Work

1. Update frontend quality guidance to replace the mixed shared-owner contract with the approved coordinator and three-owner contract.
2. Add pure coordinator logic and tests for target classification, mutual exclusion, pending transitions, repeated-target close, Escape, and focus restoration.
3. Refactor `TopBar.qml` to host the thin per-screen coordinator and three persistent owner windows without changing unrelated bar behaviour.
4. Replace the current rounded `FullscreenOverlayHost` presentation with a fixed-geometry 85% wave surface and four clipped wave layers.
5. Add tests for wave geometry, exact angles, palettes, entry/exit endpoints, interruption, side-zone close, and reduced motion.
6. Rework shared fullscreen header/sidebar primitives around osu overlay palettes and continuous surface geometry.
7. Rebuild Wiki, News, and Beatmap templates for source-faithful layout/UI style with minimal representative static content.
8. Restore Settings to its dedicated left owner while preserving existing settings data, persistence, controls, Escape, and focus behaviour.
9. Restore Music to a dedicated Now Playing owner while preserving MPRIS and transport behaviour.
10. Remove obsolete mixed-owner routes, aliases, tests, and documentation rather than retaining backward-compatibility branches.
11. Run targeted tests after each QML change and resolve every new WARN/ERROR before continuing.
12. Run the complete verification matrix and inspect the final diff for unrelated changes.

## Validation

- `qmltestrunner` for coordinator logic.
- `qmltestrunner` for wave host and page templates.
- Existing and updated settings component tests.
- Existing and updated music overlay tests.
- Existing top-bar logic and integration tests.
- All plugin-independent `tests/qml/tst_*.qml` sequentially.
- `python -m unittest discover -s scripts/tests -v`.
- `git diff --check`.
- `timeout 12s qs -p .` and inspect for new QML WARN/ERROR.

## Risky Files And Rollback Points

- `modules/lazerbar/TopBar.qml`: owner wiring and per-screen state. Verify after coordinator integration before visual work.
- `modules/lazerbar/FullscreenOverlayHost.qml`: replace presentation in one isolated step; keep pure geometry tests green.
- `modules/lazerbar/LazerSettingsOverlay.qml` / `LazerSettingsPanel.qml`: preserve save and focus contracts while changing ownership.
- `modules/lazerbar/OsuMusicOverlay.qml`: preserve service-facing public properties and signals.
- `.trellis/spec/frontend/quality-guidelines.md`: remove the obsolete mixed-owner rule in the same commit as architecture migration.

## Completion Gate

- All PRD acceptance criteria are observable and verified.
- No mixed fullscreen route remains for Settings or Music.
- No new compatibility code preserves the rejected rounded-card/fullscreen-host architecture.
- No unrelated user worktree changes are staged or modified.
