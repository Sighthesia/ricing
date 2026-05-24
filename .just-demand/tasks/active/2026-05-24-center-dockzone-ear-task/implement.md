# Implement

- Root cause: `IslandBody.qml` rendered the center body with a semi-transparent `Rectangle` plus an extra top `Rectangle` to flatten the top corners, so the same region was painted twice.
- Minimal fix: keep the existing body container, content, blur inset, and mouse interaction structure, but replace the background fill with a single-pass `Canvas` body shape.
- Shape contract: flat top edge, rounded bottom corners, matching the center dockzone body silhouette already used in `DockzoneSurfaceRoot.qml`.
- Non-goals: do not change left/right ear canvases, hover behavior, layout behavior, or context-menu behavior.
- Follow-up fix: replace `IslandBody.blurRegionSource` body-only export with `blurParts` that includes body plus left/right top ear strip items.
- Mirror the bar implementation pattern where useful: use one-pixel strip `Item`s for concave ear blur, and aggregate regions in `IslandWindow.qml` via `Variants` plus `Region.regions`.
- Do not reintroduce `Region` subtract/ellipse composition because it was observed to flatten incorrectly through `BackgroundEffect.blurRegion`.
