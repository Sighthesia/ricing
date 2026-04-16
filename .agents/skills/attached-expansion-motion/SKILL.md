---
name: attached-expansion-motion
description: Use when reusing SuperIsland-style attached panel open/close motion in standalone widgets, especially if pill and panel feel detached, throw/catch affects the wrong layer, or the motion becomes janky.
---

# Attached Expansion Motion

Reuse SuperIsland attached-panel motion by keeping layout geometry stable and moving only the visual layer that should visibly throw/catch.

## When to Use
- You are adding SuperIsland-style attached expansion to a standalone widget such as media, system monitor, or tray-derived surfaces.
- The attached panel shell appears, but the source pill does not look involved in the open/close motion.
- Throw/catch only moves the panel, so pill and panel read as two separate surfaces.
- Moving the pill to restore one-piece motion makes the whole shell stutter or resize during the animation.

## Symptoms
- The panel opens below the widget, but the widget itself stays visually static.
- After adding throw/catch to the widget, the bar feels janky during open/close.
- Throw/catch state updates are happening, but the visible pill barely moves or the motion disappears entirely.
- The attached shell geometry looks correct, yet the overall handoff still reads like a dropdown instead of a pill-to-panel expansion.

## Root Cause
- Reusing `AttachedExpansionShell.qml` and `AttachedExpansionPanelHost.qml` is not enough by itself; the source pill must visually participate in the same throw/catch story.
- In standalone widgets, animating an anchored exported root such as `_pillClip.anchors.topMargin` can leak the throw offset into `_panelShellY`, `_panelDetachedY`, and reserved transient extension calculations, which causes layout thrash and layer-shell resize churn.
- If a child wrapper uses both `anchors.fill` and manual `x` / `y`, the wrapper gets conflicting geometry ownership and the throw/catch motion can be partially canceled or clipped away.

## Transferable Lesson
- When reusing a complex motion system, copy the ownership split, not just the visible geometry.
- For attached pill-to-panel motion, keep exported layout and reservation geometry stable; animate a visual child wrapper instead of the anchored host root.
- If motion becomes invisible after moving ownership inward, check for two classic failures first: anchor/manual-position conflicts and parent clipping that hides the travel.

## Correct Pattern
- Reuse the shared motion/shell stack:
  - `modules/bar/AttachedExpansionMotion.qml`
  - `modules/bar/AttachedExpansionShell.qml`
  - `modules/bar/AttachedExpansionPanelHost.qml`
- Give the attached panel enough vertical shoulder room before tuning motion:
  - In media-style widgets, `detachedY` should include inward-corner depth instead of starting directly at pill bottom.
- Keep layout ownership on the anchored pill host:
  - Let `_pillClip` or the exported widget root stay anchored and stable.
  - Do not animate `_pillClip.anchors.topMargin` for throw/catch.
- Move a visual wrapper inside the pill host:
  - Create a child wrapper like `_pillThrowLayer`.
  - Give it explicit `x`, `y`, `width`, and `height`.
  - Drive its `y` from the same throw offset used by the attached shell/panel hosts.
- Keep the attached shell and panel on the shared throw timeline:
  - Pass the same `throwOffsetY` into both `AttachedExpansionShell` and `AttachedExpansionPanelHost` so the bridge, panel body, and pill wrapper travel together.
- Avoid geometry ownership conflicts:
  - Do not combine `anchors.fill` with manual `y` on the throw wrapper.
  - If the parent pill host clips, the throw travel can disappear; prefer keeping the outer host unclipped and localize clipping to inner surfaces that actually need it.
- Treat transient extension as a stable reservation:
  - The reserved panel extension should be derived from stable detached geometry, not from the animated throw wrapper offset.

## Media Widget Pattern
- In `modules/bar/widgets/MediaControlWidget.qml`, the stable split is:
  - `_pillClip` stays anchored and defines stable host geometry.
  - `_pillThrowLayer` owns visible pill throw/catch travel.
  - `_panelThrowOffsetY` is still the single shared motion property.
  - `AttachedExpansionShell` and `AttachedExpansionPanelHost` both receive that same throw offset.
- If you need to make the attached connection more obvious before tuning motion, fix `detachedY` / inward-corner depth first, then adjust throw/catch distances.

## Anti-Patterns
- Animating `_pillClip.anchors.topMargin` or another exported anchored root to achieve throw/catch.
- Letting reserved transient extension update from the animated throw position.
- Using `anchors.fill` on the throw wrapper while also setting its `y`.
- Leaving the only visible moving layer inside a clipped parent and then concluding the motion system is broken.

## Verification
- Run `timeout 5 qs --path .`
- Open the standalone media panel and verify the pill visibly participates in throw/catch while the attached shell remains one continuous surface.
- Confirm the bar no longer stutters during the same interaction.
- If motion disappears again, inspect wrapper ownership and clipping before changing durations or easing.

## References
- `modules/bar/widgets/MediaControlWidget.qml`
- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/AttachedExpansionMotion.qml`
- `modules/bar/AttachedExpansionShell.qml`
- `modules/bar/AttachedExpansionPanelHost.qml`
