# Replace Missing Scene Path Warning Target

## Goal

Eliminate the `File not found` warning that still references `@modules/background/DynamicIslandDockZone.qml` by making it resolve to `modules/bar/widgets/Placeholder.qml`.

## What I already know

* The current default widget source in `services/barlayout/BarLayoutLayoutModel.js` already points to `../../modules/bar/widgets/Placeholder.qml`.
* `BarLayoutService.qml` falls back to `BarLayoutModel.defaultLayoutModel()` when layout data is missing.
* The warning text still mentions `DynamicIslandDockZone.qml`, which suggests an older scene/source reference remains somewhere else in the runtime path.
* The user wants the related naming to be updated to `Placeholder` as well, not just the path target.

## Open Questions

* None.

## Requirements (evolving)

* Locate the remaining source of the `File not found` warning.
* Update the resolved scene/source path so the fallback points at `modules/bar/widgets/Placeholder.qml`.
* Rename related widget labels/IDs so the runtime naming matches `Placeholder`.

## Acceptance Criteria (evolving)

* [ ] The warning no longer references `@modules/background/DynamicIslandDockZone.qml`.
* [ ] The fallback resolves to `modules/bar/widgets/Placeholder.qml`.
* [ ] Related widget naming no longer references `DynamicIslandDockZone`.

## Definition of Done

* Change is minimal and limited to the warning/path resolution behavior.
* Validation is run for the affected code path.

## Technical Notes

* Likely impacted file: `services/barlayout/BarLayoutLayoutModel.js`
* Existing fallback source already uses `modules/bar/widgets/Placeholder.qml`
* Relevant specs: `.trellis/spec/frontend/directory-structure.md`, `.trellis/spec/frontend/quality-guidelines.md`
