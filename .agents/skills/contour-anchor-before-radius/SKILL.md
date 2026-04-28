---
name: contour-anchor-before-radius
description: Use when a rounded bridge, shoulder, or corner still looks too wide, bulged, or notched and the real problem may be where the curve starts rather than how round it is.
---

# Contour Anchor Before Radius

When a rounded handoff looks wrong, fix the contour anchor before changing the radius.

## A. The Generic Pattern / Methodology

| Item | Guidance |
| --- | --- |
| Core Concept | In contour geometry, anchor-like parameters often dominate silhouette before radius-like parameters do. |
| Universal Checklist | 1. Identify the parameter that places the shoulder or neck. 2. Identify the parameter that only changes curvature. 3. Compare the curve start point against the desired silhouette. 4. Fix width or anchor drift before reducing radius. 5. Only then tune radius for sharp remnants or notches. |

## B. The Specific Trap / Symptom (The Trigger)

| Context | Summary |
| --- | --- |
| Attached panel bridge in DymicShell | The shoulder looked like an outward bump. Shrinking the corner radius changed roundness but not the oversized silhouette, because the bridge outset already pushed the curve too far outward before the radius was applied. |

## C. The Anti-Pattern vs. Best Practice

| Pattern | Explanation |
| --- | --- |
| ❌ The Anti-Pattern (Why it failed) | Keep shrinking radii or adding more local corner logic when the curve already starts from the wrong lateral anchor. |
| ✅ The Best Practice (The Fix) | Fix the anchor or shoulder width first, then use radius tuning only for the remaining contour quality. |

## D. Generalizable Rules (Highly Portable)

### Warning Signs

- The bridge-to-panel transition reads as a protruding shoulder or blob on the outside edge.
- The corner is technically rounded, but the outer contour still looks wider than the pill neck.
- Lowering `inwardCornerRadius` changes roundness but does not remove the outward bump.

### Agnostic Rules

- When a rounded handoff still looks wrong, check the contour anchor before changing the radius.
- In attached-panel geometry, width-like parameters often dominate silhouette more than radius-like parameters.
- If one parameter controls where a curve starts, and another controls how curved it is, fix the start position first.
- Mixed layouts usually fail because a shell, not a child rectangle, owns the shoulder or corner continuity.
- If the boundary between two regions feels "confusing", decide whether the fix belongs in shell geometry, content geometry, or width ownership before editing.

## E. Universal Verification Strategy

### Agnostic Testing Logic

- Do not keep shrinking radii when the real issue is a shoulder that begins too far out.
- Do not split one bridge into multiple local bumps just to satisfy two neighboring rectangles.
- Do not treat the panel top edge as a content spacing problem if the attached shell is still exporting the wrong contour.

1. Compare the shoulder width before and after anchor changes.
2. Verify the contour no longer extends beyond the intended neck or host edge.
3. Only after that, check whether radius tuning is still needed.
4. Run `timeout 5 qs --path .` after geometry changes.

## References

- Shared geometry math: `modules/bar/AttachedExpansionGeometry.js`
- Shared shell path: `modules/bar/AttachedExpansionShell.qml`
- SuperIsland upstream parameters: `modules/bar/widgets/SuperIslandWidget.qml`
- Media panel upstream parameters: `modules/bar/widgets/MediaControlWidget.qml`
