---
name: attached-expansion-geometry
description: Use when modifying SuperIsland or media attached panel bridge geometry, especially if the bridge-to-panel corner looks bulged, notched, or overly wide.
---

# Attached Expansion Geometry

In DymicShell attached panel shells, `bridgeOutset` controls shoulder width first; if the bridge-to-panel corner bulges outward, reduce `bridgeOutset` before touching the corner radius.

## When to Use
- You are changing `modules/bar/AttachedExpansionGeometry.js` or `modules/bar/AttachedExpansionShell.qml`.
- A SuperIsland or media attached panel shoulder looks like a side bump instead of a clean inward handoff.
- You are tempted to fix the bridge by only shrinking `cutRadius` or adding a second shoulder radius.

## Symptoms
- The bridge-to-panel transition reads as a protruding shoulder or blob on the outside edge.
- The corner is technically rounded, but the outer contour still looks wider than the pill neck.
- Lowering `inwardCornerRadius` changes roundness but does not remove the outward bump.

## Root Cause
- The attached shell is one continuous `ShapePath`, but the shoulder is still defined by a rectilinear neck plus a quarter-circle cut.
- In `modules/bar/AttachedExpansionGeometry.js`, the outer shoulder endpoint is `neckRight + cutRadius` on the right and `neckLeft - cutRadius` on the left.
- `neckRight` / `neckLeft` are derived from `bridgeOutset`, so if `bridgeOutset` is too large, the quarter-circle starts from a shoulder that already sits too far outward.
- That means the bug is often shoulder width, not shoulder roundness.

## Transferable Lesson
- When a rounded handoff still looks wrong, check the contour anchor before changing the radius.
- In attached-panel geometry, width-like parameters often dominate silhouette more than radius-like parameters.
- If one parameter controls where a curve starts, and another controls how curved it is, fix the start position first.
- Mixed layouts usually fail because a shell, not a child rectangle, owns the shoulder or corner continuity.
- If the boundary between two regions feels "confusing", decide whether the fix belongs in shell geometry, content geometry, or width ownership before editing.

## Confusion Traps
- Do not keep shrinking radii when the real issue is a shoulder that begins too far out.
- Do not split one bridge into multiple local bumps just to satisfy two neighboring rectangles.
- Do not treat the panel top edge as a content spacing problem if the attached shell is still exporting the wrong contour.

## Correct Pattern
- Treat `bridgeOutset` as shoulder-width control, not as a general smoothness control.
- Keep the shared geometry stable:
  - `cornerStartY = panelTop - cutRadius`
  - `rightShoulderX = neckRight + cutRadius`
  - `leftShoulderX = neckLeft - cutRadius`
- For SuperIsland, tune `modules/bar/widgets/SuperIslandWidget.qml` in this order:
  - `_overlayBridgeOutset`
  - `_overlayInwardCornerRadius`
  - `_overlayInwardCornerDepth`
- If the shoulder bulges, first try `_overlayBridgeOutset: 0`.
- In this project, `_overlayBridgeOutset: 0` proved to be the clean fix for the SuperIsland bridge bulge because it keeps the neck aligned to the pill edge while preserving the existing quarter-circle cut logic.
- Only change `cutRadius` clamping in `AttachedExpansionGeometry.js` if the issue is a sharp remnant, a notch, or collapse-tail artifact. Do not use it as the first fix for outward bulges.

## Project-Specific Touchpoints
- Shared geometry math: `modules/bar/AttachedExpansionGeometry.js`
- Shared shell path: `modules/bar/AttachedExpansionShell.qml`
- SuperIsland upstream parameters: `modules/bar/widgets/SuperIslandWidget.qml`
- Media panel upstream parameters: `modules/bar/widgets/MediaControlWidget.qml`

## Verification
- Run `timeout 5 qs --path .`
- Visually check that the SuperIsland bridge no longer extends wider than the pill neck before the panel top corner starts.
- If media panel also uses the shared shell, verify its shoulder still reads intentional after any shared math change.
