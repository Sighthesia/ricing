# Implement center floating detach morph semantics

## Goal

Introduce the next stage of center dockzone semantics by making `floating`, `detachProgress`, and `morphProgress` behaviorally meaningful for the center path, without expanding into left/right migration or a new global service layer.

## Confirmed Facts

- `modules/bar/DockzoneSurfaceRoot.qml` already owns center-local animated `visibilityProgress` and `stateTransitionProgress`.
- `modules/bar/DockzoneSurfaceModel.js` still treats `morphProgress` and `detachProgress` as neutral placeholders.
- The contract spec defines `attached -> floating` and `floating -> attached` as the transitions that should activate `stateTransitionProgress`, `detachProgress`, and `morphProgress` together.
- The current center renderer keeps a stable attached silhouette and does not yet expose any floating-specific geometry or ear-local behavior.
- The current codebase has no existing hover, drag, pointer, or focus interaction in `modules/bar/` that naturally drives a floating center state.
- The only already-wired bar interaction around the center area is the widget picker flow, but earlier planning deliberately avoided making dockzone public meaning equal to widget-picker visibility.
- The center surface state source was just upgraded from a hardcoded string to a content-presence semantic mapping in `BarSection.qml`.
- Left/right dockzone paths still use legacy rendering and are out of scope for this stage.

## Requirements

- Keep implementation limited to the center path.
- Preserve `DockzoneSurfaceRoot.qml` as the owner of runtime progress state.
- Keep `DockzoneSurfaceModel.js` pure and stateless.
- Avoid introducing a new shared service unless a concrete need is proven.
- Avoid coupling dockzone public meaning directly to widget-picker visibility.

## Acceptance Criteria

- [ ] Center path can represent a real `floating` semantic state.
- [ ] `morphProgress` and `detachProgress` are no longer always neutral placeholders for the chosen floating flow.
- [ ] Attached baseline remains visually stable when not floating.
- [ ] Left/right legacy paths remain untouched.
- [ ] Affected files pass static validation.

## Out of Scope

- Left/right migration.
- Final unified render architecture for all sections.
- New dockzone-global service layer unless planning proves it is unavoidable.

## Decision

- The first real center `floating` flow should be driven by an explicit local semantic input / validation path, not by a new hover system and not by widget-picker visibility.
- The temporary validation path should live in `BarContent` / `BarSection`, not in a new service.

## Open Questions

- None blocking planning.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
