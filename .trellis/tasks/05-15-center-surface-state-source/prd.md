# Wire real center surface state source

## Goal

Replace the hardcoded center `surfaceState: "attached"` with a real semantic state source, so the center dockzone owner can enter and exit through an actual UI-driven lifecycle instead of a permanent attached baseline.

## Confirmed Facts

- `modules/bar/BarSection.qml` currently passes `surfaceState: "attached"` directly into the center `DockzoneSurfaceRoot.qml`.
- `modules/bar/DockzoneSurfaceRoot.qml` already supports semantic `surfaceState` changes and animates owner-local `visibilityProgress` and `stateTransitionProgress`.
- `modules/bar/DockzoneSurfaceModel.js` already derives global motion from owner-supplied visibility progress.
- The repository currently has no dedicated dockzone state service or other upstream center-surface state machine.
- `services/BarLayoutService.qml` already exposes a real shell state signal: `widgetPickerVisible`, plus `widgetPickerSection` and open/close/toggle methods.
- `modules/bar/widgets/WidgetPickerButton.qml` toggles the widget picker specifically for the `center` section.
- `modules/bar/WidgetPickerWindow.qml` already uses `Services.BarLayoutService.widgetPickerVisible` as its own visibility source.
- The existing evidence suggests `widgetPickerVisible` is the only concrete, already-wired UI state source that can drive the center surface without introducing a new service layer.
- `modules/bar/BarSection.qml` already has direct access to `sectionModel`, which is derived from `Services.BarLayoutService.sectionWidgets(sectionName)`.
- The codebase already uses section content presence as a visibility rule in another dockzone-adjacent place: `modules/bar/BarBottomEarWindow.qml` shows side ears only when `sectionWidgets("left" | "right")` is non-empty.
- The default layout model always seeds the center section with a placeholder widget, so content-presence semantics would currently keep the center surface visible by default.

## Requirements

- Replace the hardcoded center `surfaceState` with a real semantic source.
- Keep `DockzoneSurfaceRoot.qml` as the owner of animated progress drivers.
- Avoid introducing a new shared service layer unless strictly necessary.
- Preserve left/right legacy paths unchanged.
- Preserve current stable attached visuals when the center surface should be visible.

## Acceptance Criteria

- [ ] Center `surfaceState` is no longer hardcoded to `"attached"`.
- [ ] A real existing UI state source drives center semantic state changes.
- [ ] `DockzoneSurfaceRoot.qml` continues to own progress animation locally.
- [ ] Left/right legacy rendering remains untouched.
- [ ] Affected files pass static validation.

## Out of Scope

- New dockzone-specific global service layer.
- Left/right migration.
- Floating/detach/morph behavior.
- Full redesign of widget picker interactions.

## Decision

- The first real center `surfaceState` source should use a small intermediate semantic mapping layer instead of binding `widgetPickerVisible` directly as the dockzone's public meaning.

## Open Questions

- None blocking planning.
