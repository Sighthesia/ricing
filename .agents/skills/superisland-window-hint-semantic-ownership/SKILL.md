---
name: superisland-window-hint-semantic-ownership
description: Use when changing SuperIsland window-hint geometry or layout and you need to separate the bar host, hint presentation root, attached shell, and detached lower content ownership.
---

# SuperIsland Window-Hint Semantic Ownership

Trace the real root element, width owner, and content owner before changing window-hint geometry.

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

## Confusion Traps
- Do not let a visually correct title row make you assume the detached lower panel is the same content root.
- Do not tune spacing in a child rectangle when the real bug is that the parent still owns the wrong width or height.
- Do not solve a bridge/corner problem by inventing a second local corner; use the shared shell or shared surface for continuity.
- Do not treat a blank seam as an inner padding defect when the lower host surface already owns the visible edge.
- Do not round the seam itself if that leaves a faint gap between surfaces; round the decorative exterior, not the connection line.

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

## Verification
- Check which root element owns `implicitWidth`, `width`, and `layoutMeasurementWidth`.
- Confirm whether the bar host still sits in the bar while only hint content is rehomed.
- Run `timeout 5 qs --path .` after changes.
- Inspect the seam at 1x and fractional scaling to confirm the connection line stays closed while the outer decorative arcs still read as rounded.
- Verify the decorative bridge layer is not clipped by the content surface that owns the square seam.
- If available, compare the host surface before and after the fix to ensure the visible gap is gone without widening the lower body.

## References
- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/superisland/IslandWindowHintCard.qml`
- `modules/bar/AttachedExpansionShell.qml`
