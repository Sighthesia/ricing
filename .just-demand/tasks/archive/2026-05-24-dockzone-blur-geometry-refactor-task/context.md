# Context

## Goal

Refactor bar dockzone background/blur plumbing so the visible dockzone body and ears use geometry-aligned QML sources for `BackgroundEffect.blurRegion`, limited to `modules/bar`.

## User-Confirmed Direction

The user approved 方案B:

- Do not keep body-only blur as the final answer.
- Do not rely on `Region` subtract/ellipse composition for concave ear blur; previous attempts were flattened by `BackgroundEffect.blurRegion`/niri and produced a full rectangle or otherwise wrong shape.
- Prefer a geometry-owner restructuring that keeps visible surface and blur sources aligned.

## Current Code Shape

- `modules/bar/DockzoneSurfaceRoot.qml` owns dockzone body/ear geometry and paints it with `Canvas` nodes:
  - `centerBody` paints the body.
  - `leftEar`, `rightEar`, `leftBottomEar`, `rightBottomEar` paint top/bottom ears.
  - `centerBodyBlurInset` is a normal `Item` used as the current blur source.
  - `blurRegionSource` and `blurRegionRadius` currently expose only body blur.
- `modules/bar/BarSection.qml` exposes `blurSourceItem` and `blurSourceRadius` from `DockzoneSurfaceRoot`.
- `modules/bar/BarContent.qml` exposes left/right section blur source item/radius.
- `modules/bar/BarWindow.qml` builds `BackgroundEffect.blurRegion` from left/right body regions only.

## Important Constraints

- Scope is `modules/bar` only.
- Do not modify `modules/island/*`; an existing paused task touches `modules/island/IslandBody.qml` and must not be mixed into this task.
- Preserve current dockzone layout, hover, visibility, attach/detach motion, and widget row behavior.
- Avoid whole-window/layer blur because it blurs transparent space.
- Keep `SettingsService.blurRegionInset` for rounded body edge bleed handling.
- Keep the Glass Liquid attached-island language: body and ears should remain one continuous surface.

## Acceptance

- Dockzone body and ears expose shared geometry sources suitable for visible surface/blur alignment.
- Bar blur region no longer uses only one body item per section.
- No `modules/island` files are changed.
- Relevant checks pass or limitations are clearly documented.
