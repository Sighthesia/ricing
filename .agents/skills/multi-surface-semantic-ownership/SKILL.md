---
name: multi-surface-semantic-ownership
description: Use when one visual feature spans multiple roots, shells, or detached surfaces and layout bugs stem from confusing the host owner, presentation owner, shell owner, or content owner.
---

# Multi-Surface Semantic Ownership

Trace the real root, width owner, shell owner, and content owner before changing geometry.

## When to Use
- You are editing `modules/bar/widgets/SuperIslandWidget.qml` or `modules/bar/superisland/IslandWindowHintCard.qml`.
- The user asks which element is the "real" SuperIsland body or whether it moved into another rectangle.
- A title row, workspace row, or clock row looks visually correct but its background or reserved width seems owned by the wrong element.

## Symptoms
- "SuperIsland" is used to describe both the bar host and the window-hint content, causing layout ambiguity.
- The visible shape changes, but neighboring widgets still reserve the old width.
- A lower rectangle appears to contain the hint, but the actual bar host still lives in the bar.
- A thin blank seam appears where the upper SuperIsland body meets the lower host surface, even though the content inside both regions is already aligned.
- The gap disappears only when the connection is drawn at the host surface level, not when inner content rectangles are tightened.
- A border-colored hairline appears near the title text even after title/workspace capsule borders are removed.
- The title host becomes slightly wider than the lower workspace host at its minimum state, so the decorative seam arcs look suspended.
- Decorative seam arcs look clipped when the title host is near the workspace width instead of reading like scaled outer corners.
- The title host springs during width retargets, but the lower workspace host snaps or clamps to the final width, causing a brief mismatch.

## Root Cause
- `SuperIslandWidget.qml` is the bar host root and owns the exported width contract.
- `IslandWindowHintCard.qml` owns the window-hint presentation branches and their inner background rectangles.
- `AttachedExpansionShell.qml` is a separate attached-shell root used only when that shell is active.
- The bar host does not move into the lower rectangle; only hint content is rehomed into a detached presentation.
- A blank seam under the lower host surface is often caused by rounded top corners on that surface, not by a missing content fill.
- The seam belongs to the real host surface layer, so the fix must square the connection there and let decorative quarter-circle or triangular arc pieces live on a non-clipped parent or sibling layer.

## Transferable Lesson
- Separate "host root", "presentation root", "shell root", and "content root" in your mental model before changing geometry.
- If width ownership and visual ownership differ, debug the exported width first and the inner layout second.
- Do not assume a visually lower rectangle means the entire SuperIsland root moved there.
- If a layout starts to feel "mixed", stop and name the owner of each rectangle before moving any margins or radii.
- If two regions appear to touch, verify whether that touch should be owned by shared shell geometry or by one presentation branch.
- When a seam looks blank instead of misaligned, treat it as a host-surface continuity problem first, not a content-spacing problem.
- Preserve the integrated rounded silhouette by keeping the real seam square at the host layer while drawing outer decorative arcs or quarter-circles outside the clipped content plane.
- If decorative geometry is clipped, move it to a non-clipped parent/sibling layer rather than forcing the clipped content to fake the silhouette.
- If a line has the old border color, verify host-level divider rectangles before chasing child capsule borders.
- When two attached surfaces must read as one body, clamp the upper minimum width to the lower host width before tuning decorative geometry.
- Decorative width adaptation should usually scale a complete shape from its attachment edge, not crop the shape's canvas.
- If one attached region uses a spring width owner and the other uses a static measured width, sync both to the same animated export before changing local visuals.

## Confusion Traps
- Do not let a visually correct title row make you assume the detached lower panel is the same content root.
- Do not tune spacing in a child rectangle when the real bug is that the parent still owns the wrong width or height.
- Do not solve a bridge/corner problem by inventing a second local corner; use the shared shell or shared surface for continuity.
- Do not treat a blank seam as an inner padding defect when the lower host surface already owns the visible edge.
- Do not round the seam itself if that leaves a faint gap between surfaces; round the decorative exterior, not the connection line.
- Do not assume a border-colored line under the title is part of the title capsules; `SuperIslandWidget.qml` may still be drawing a host-level divider.
- Do not adapt seam arcs by shrinking their canvas width first; that makes the corners read as clipped instead of gracefully compressed.
- Do not let the title host keep `collapsedWidth` as a permanent minimum once the true lower host width should own the attached minimum state.
- Do not trust `IslandWindowHintCard.qml` implicit width alone when checking the real minimum title width; `SuperIslandWidget.qml` can still clamp the exported host width with collapsed-width logic.

## Correct Pattern
- Treat `_pillClip` / `_pillBg` in `SuperIslandWidget.qml` as the visible bar host body.
- Treat `_barExpandedMainLayout` and `_barExpandedDetachedLayout` in `IslandWindowHintCard.qml` as window-hint presentation containers.
- Treat `layoutMeasurementWidth` and `implicitWidth` on `SuperIslandWidget.qml` as the authoritative bar reservation exports.
- Treat the title background width and lower rectangle background width as owned by `IslandWindowHintCard.qml`, not the bar wrapper.
- When the title rectangle must touch the workspace rectangle, let a shell or shared surface own the corner transition; do not fake the corner with two unrelated local rectangles.
- Keep slot capsules responsible for title/workspace motion, and keep the shell responsible for the bridge/corner continuity between them.
- For a seam between the upper body and lower host surface, make the host-level connection square so the two surfaces read as one continuous body.
- Put the outer quarter-circle, arc, or triangular bridge accents on a non-clipped parent or sibling layer so they can preserve the rounded silhouette without reopening the seam.
- If the seam disappears only when the decorative layer is isolated from the clipped content, that is the correct ownership split.
- In `modules/bar/widgets/SuperIslandWidget.qml`, treat the host-level divider rectangle inside `_pillClip` as a separate visual owner from the title capsules; disable it explicitly for `bar-expanded` window hint if it leaks into the title area.
- Clamp the bar-expanded title host minimum width to `_barExpandedDetachedHintWidth`, not to the idle or collapsed pill width.
- When the title host is clamped to the workspace host width, square the title host's bottom corners so the two backgrounds read as one surface.
- When the title host has a spring width but the lower workspace body should stay visually stable, give the workspace its own synchronized spring path that is clamped by the detached minimum width instead of binding it rigidly to the title's instantaneous width.
- Use the same animated width source for both hosts only when the lower body is intentionally allowed to shrink during the same phase; otherwise, keep the lower body on a clamped spring so it can follow the title near minimum without collapsing too early.
- Drive the lower workspace host width from the same animated width export that shrinks the title host, such as `_pillTransitionControl.animatedWidth`, instead of leaving the lower host on a static measured width.
- For seam arc adaptation, keep a full-size decorative arc and scale it from the seam edge; avoid reducing canvas width, which visually crops the arc.
- Drive decorative seam-arc visibility from the width delta between title host and detached workspace host.
- When the width delta is near zero, collapse the arc by scaling the full arc shape from the seam anchor; when the width delta is large enough, restore the arc at full scale.
- Keep the detached workspace host body width synced to `_pillTransitionControl.animatedWidth` while bar-expanded shrink or retarget spring is active so the lower host never lags behind the title host.

## Verification
- Check which root element owns `implicitWidth`, `width`, and `layoutMeasurementWidth`.
- Confirm whether the bar host still sits in the bar while only hint content is rehomed.
- Run `timeout 5 qs --path .` after changes.
- Inspect the seam at 1x and fractional scaling to confirm the connection line stays closed while the outer decorative arcs still read as rounded.
- Verify the decorative bridge layer is not clipped by the content surface that owns the square seam.
- If available, compare the host surface before and after the fix to ensure the visible gap is gone without widening the lower body.
- Verify the title host minimum width exactly matches the lower workspace host width when there are no windows or only very short titles.
- During live title width retargets, confirm the lower workspace host follows the same spring width path instead of waiting at the final width.
- At minimum arc width, confirm the outer corner reads like a scaled-down arc, not a horizontally cropped shard.
- Test these width states explicitly: no windows, very short title set, detached-width clamp, and long-title overflow.
- During live window-title shrink, confirm the title host and detached workspace host bottoms stay aligned through the whole spring instead of briefly crossing widths.
- When the title width is clamped to the detached workspace width, confirm the bottom title corners read as square and the decorative arcs fully retire rather than looking cut off.

## References
- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/superisland/IslandWindowHintCard.qml`
- `modules/bar/AttachedExpansionShell.qml`
