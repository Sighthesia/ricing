---
name: visual-vs-layout-motion-ownership
description: Use when reusing an existing motion pattern and the animation becomes janky because layout-reservation geometry and visible throw/catch geometry are being animated by the same owner.
---

# Visual vs Layout Motion Ownership

Reuse complex motion by keeping layout geometry stable and moving only the visual layer that should visibly travel.

## A. The Generic Pattern / Methodology

| Item | Guidance |
| --- | --- |
| Core Concept | Separate exported layout ownership from visible motion ownership. |
| Universal Checklist | 1. Identify which root exports reserved size to the outside world. 2. Keep that export stable during motion. 3. Create a dedicated visual wrapper for travel. 4. Feed the same motion signal to every visual participant that should read as one surface. 5. Remove anchor/manual-position conflicts before tuning easing. |

## B. The Specific Trap / Symptom (The Trigger)

| Context | Summary |
| --- | --- |
| Attached panel motion reuse in DymicShell | Reusing the shell alone made the panel move without the pill. Moving the anchored pill root restored the visual story but caused layout thrash and resize churn because the exported host geometry started participating in throw/catch. |

## C. The Anti-Pattern vs. Best Practice

| Pattern | Explanation |
| --- | --- |
| ❌ The Anti-Pattern (Why it failed) | Animate the anchored/exported host root just because it is the easiest place to see movement. |
| ✅ The Best Practice (The Fix) | Leave the exported host stable and animate a child visual wrapper that does not own reserved layout geometry. |

## D. Generalizable Rules (Highly Portable)

### Warning Signs

- The panel opens below the widget, but the widget itself stays visually static.
- After adding throw/catch to the widget, the bar feels janky during open/close.
- Throw/catch state updates are happening, but the visible pill barely moves or the motion disappears entirely.
- The attached shell geometry looks correct, yet the overall handoff still reads like a dropdown instead of a pill-to-panel expansion.

### Agnostic Rules

- When reusing a complex motion system, copy the ownership split, not just the visible geometry.
- For attached pill-to-panel motion, keep exported layout and reservation geometry stable; animate a visual child wrapper instead of the anchored host root.
- If motion becomes invisible after moving ownership inward, check for two classic failures first: anchor/manual-position conflicts and parent clipping that hides the travel.

## E. Universal Verification Strategy

### Agnostic Testing Logic

- Animating `_pillClip.anchors.topMargin` or another exported anchored root to achieve throw/catch.
- Letting reserved transient extension update from the animated throw position.
- Using `anchors.fill` on the throw wrapper while also setting its `y`.
- Leaving the only visible moving layer inside a clipped parent and then concluding the motion system is broken.

1. Verify the source surface visibly participates in the same motion as the detached panel.
2. Verify reserved space and outer layout no longer stutter during the interaction.
3. If motion disappears, inspect clipping and anchor conflicts before changing animation curves.
4. Run `timeout 5 qs --path .`.

## References
- `modules/bar/widgets/MediaControlWidget.qml`
- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/AttachedExpansionMotion.qml`
- `modules/bar/AttachedExpansionShell.qml`
- `modules/bar/AttachedExpansionPanelHost.qml`
