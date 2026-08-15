# Technical Design: Lazer Settings Overlay

## Boundaries

- `modules/lazerbar/` owns visible overlay composition, per-screen window instances, controls, and interaction state.
- `services/` owns singleton state and side effects. UI reads services directly and writes through their existing setters/APIs.
- `modules/lazerbar/*Logic.js` contains pure calculations shared by QML and QtTest.
- `tests/qml/` verifies contracts at the smallest useful boundary, then integration behavior through `TopBar` and zone components.

## State And Data Flow

1. `LeftZone` and `UtilityZone` emit an overlay request from `OsuTopBarButton`.
2. `TopBar` applies `LazerBarLogic.nextOverlay(current, requested)` per screen.
3. `LazerSettingsOverlay` and `OsuMusicOverlay` render from that state inside a fixed host.
4. Settings controls write to `SettingsService`; existing debounce/persistence remains authoritative.
5. Services and visual consumers react to changed settings through normal QML bindings.

## Geometry And Motion

- Keep the outer panel window geometry fixed and animate inner panel/scrim properties.
- Use `LazerSettingsLogic` for panel dimensions, clamping, category direction, notification anchors, and timeout conversion.
- Reduced motion removes translation/scale transitions while retaining opacity and color feedback.
- Do not attach keyboard handlers directly to `PanelWindow`; use a focused inner item.

## Compatibility

- Preserve singleton declarations and `services/qmldir`/`modules/lazerbar/qmldir` registration.
- Preserve existing settings keys and service APIs; consumers adapt to current values rather than migrating stored data.
- Keep per-screen behavior based on `Variants { model: Quickshell.screens }`.

## Risks And Rollback

- The highest-risk boundary is per-frame layer-shell geometry. If animation janks, keep host geometry fixed and move animation to an inner item.
- Focus ownership can regress on reopen or page switch. Exercise reopen, Escape, Tab, and settings/music switching in isolated QtTest processes.
- Service consumers can create binding loops. Add focused tests and inspect `qs -p .` output for WARN/ERROR before commit.
- Rollback is file-scoped: revert only integration files and tests for the failing task; retain stable panel primitives.
