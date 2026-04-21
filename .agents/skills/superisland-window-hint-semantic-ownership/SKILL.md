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

## Root Cause
- `SuperIslandWidget.qml` is the bar host root and owns the exported width contract.
- `IslandWindowHintCard.qml` owns the window-hint presentation branches and their inner background rectangles.
- `AttachedExpansionShell.qml` is a separate attached-shell root used only when that shell is active.
- The bar host does not move into the lower rectangle; only hint content is rehomed into a detached presentation.

## Transferable Lesson
- Separate "host root", "presentation root", "shell root", and "content root" in your mental model before changing geometry.
- If width ownership and visual ownership differ, debug the exported width first and the inner layout second.
- Do not assume a visually lower rectangle means the entire SuperIsland root moved there.
- If a layout starts to feel "mixed", stop and name the owner of each rectangle before moving any margins or radii.
- If two regions appear to touch, verify whether that touch should be owned by shared shell geometry or by one presentation branch.

## Confusion Traps
- Do not let a visually correct title row make you assume the detached lower panel is the same content root.
- Do not tune spacing in a child rectangle when the real bug is that the parent still owns the wrong width or height.
- Do not solve a bridge/corner problem by inventing a second local corner; use the shared shell or shared surface for continuity.

## Correct Pattern
- Treat `_pillClip` / `_pillBg` in `SuperIslandWidget.qml` as the visible bar host body.
- Treat `_barExpandedMainLayout` and `_barExpandedDetachedLayout` in `IslandWindowHintCard.qml` as window-hint presentation containers.
- Treat `layoutMeasurementWidth` and `implicitWidth` on `SuperIslandWidget.qml` as the authoritative bar reservation exports.
- Treat the title background width and lower rectangle background width as owned by `IslandWindowHintCard.qml`, not the bar wrapper.
- When the title rectangle must touch the workspace rectangle, let a shell or shared surface own the corner transition; do not fake the corner with two unrelated local rectangles.
- Keep slot capsules responsible for title/workspace motion, and keep the shell responsible for the bridge/corner continuity between them.

## Verification
- Check which root element owns `implicitWidth`, `width`, and `layoutMeasurementWidth`.
- Confirm whether the bar host still sits in the bar while only hint content is rehomed.
- Run `timeout 5 qs --path .` after changes.

## References
- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/superisland/IslandWindowHintCard.qml`
- `modules/bar/AttachedExpansionShell.qml`
