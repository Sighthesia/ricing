# Task: bar-layout-drift-and-push-geometry

## Overview

Refactor the bar layout system so section and widget geometry contracts can express whole-section drift, explicit left/right edge coordinates, alignment semantics, and stable push displacement. The current left/center/right result-oriented layout model is no longer sufficient for SuperIsland-style exclusive-width push behavior.

## Requirements

- Redesign the `barlayout` geometry contract so sections expose explicit layout edges, visual edges, content edges, and push offsets instead of only final result positions.
- Add explicit alignment and anchoring semantics for sections and widgets so layout consumers can distinguish left-aligned, center-aligned, right-aligned, and drift-capable placement.
- Support sections that are allowed to drift as a whole instead of being permanently pinned to the left or right screen edge.
- Separate section-level push displacement from section-internal widget/slot layout so local reflow and global push motion can be animated independently.
- Preserve a compatibility path for existing consumers during migration so current fields like `left`, `right`, `width`, and `centerX` continue to work until all consumers are updated.
- Ensure center-section exclusive-width behavior can emit explicit left/right intrusion and push semantics instead of forcing neighboring sections to infer displacement from final positions.
- Update drag hit-testing, picker anchors, arrival overlays, and widget delegates to consume the new geometry contract correctly.
- Keep the refactor layout-system-focused; do not bundle unrelated visual redesigns into this task.

## Acceptance Criteria

- [ ] Each section geometry record exposes explicit left/right edge coordinates for both layout bounds and visual/content bounds.
- [ ] Each section geometry record exposes enough semantics to distinguish pinned, drift-capable, and push-displaced states.
- [ ] Widget/slot geometry separates local slot placement from section-level push displacement.
- [ ] Left and right sections can drift as a whole when center exclusive width expands, instead of being hard-pinned to screen edges.
- [ ] Push animation can be attached only to section push offset without corrupting local slot layout.
- [ ] Drag, insertion, picker anchoring, and arrival geometry still resolve to the correct visual positions after migration.
- [ ] Existing fields keep working until all layout consumers are migrated.
- [ ] `timeout 5 qs --path .` passes after the refactor.

## Technical Notes

- The current root issue is not a single animation bug; it is that the geometry contract only exposes result coordinates and omits layout intent.
- `services/barlayout/BarLayoutSections.js` currently hardcodes left/center/right assumptions around midpoint and edge pinning. Treat that file as a primary redesign target.
- `services/barlayout/BarLayoutGeometryPipeline.js` should become the main place that computes both compatibility geometry and the new semantic geometry fields.
- `modules/bar/BarSection.qml` and `modules/bar/BarWidgetWrapper.qml` must consume separate values for local slot layout vs section push displacement.
- Plan for migration in layers: add new fields first, switch consumers gradually, then retire obsolete assumptions.

## Suggested Data Model

### Section geometry

- `layoutLeft`
- `layoutRight`
- `layoutWidth`
- `visualLeft`
- `visualRight`
- `visualWidth`
- `contentLeft`
- `contentRight`
- `contentWidth`
- `anchorMode`
- `alignmentMode`
- `fixedEdge`
- `driftPolicy`
- `driftMinX`
- `driftMaxX`
- `pushOffsetX`
- `pushTargetOffsetX`
- `pushSource`

### Slot/widget geometry

- `baseLeft`
- `baseRight`
- `baseCenterX`
- `localLeft`
- `localRight`
- `localCenterX`
- `sectionPushOffsetX`
- `visualLeft`
- `visualRight`
- `visualCenterX`
- `alignmentMode`

## Migration Plan

1. Add the new geometry fields while keeping existing aliases.
2. Compute semantic push/drift data in `BarLayoutSections.js` and `BarLayoutGeometryPipeline.js`.
3. Migrate `BarSection.qml` and `BarWidgetWrapper.qml` to use separate local and push coordinates.
4. Migrate drag, picker, and arrival consumers.
5. Remove legacy left/right pinning assumptions after all consumers are updated.

## Out of Scope

- Redesigning unrelated widget visuals.
- Reworking SuperIsland card visuals beyond the geometry-contract changes needed to consume the new layout model.
- Changing persisted widget layout order or widget identity schema unless required by the refactor.
