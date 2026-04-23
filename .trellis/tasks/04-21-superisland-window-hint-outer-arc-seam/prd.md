# SuperIsland Window-Hint Seam And Motion Stabilization

## Goal

Stabilize the `bar-expanded` window-hint presentation so the title host, lower workspace host, and SuperIsland body behave like one coherent motion system during expand, live updates, and collapse.

## Confirmed Requirements

- Keep the current `bar-expanded` visual language: square seam connection between title and workspace hosts, with outer decorative arcs preserving the rounded silhouette.
- During collapse, the title background and workspace background must share the same upward catch timing so they do not visually separate.
- When the SuperIsland host widens from idle/clock width to the title-row width, that width ownership change must animate instead of snapping.
- Title capsules inside the widened title host may enter on initial expand, but they must not replay the full enter animation on the first live window switch after the hint is already visible.
- Preserve the existing live-updating window-hint behavior while held; local content should retarget, not restart the whole presentation.
- Keep the fix minimal and aligned with existing `SuperIslandWidget` / `IslandWindowHintCard` ownership boundaries.

## Product Intent

- The widened title host should feel like the real SuperIsland body stretching to receive window titles.
- The lower workspace host should feel physically attached to that body during both expand and collapse.
- Once the hint is already open, window/focus changes should feel like live lens updates rather than repeated notification-style entrances.

## Acceptance Checklist

- [ ] The lower workspace host participates in the same upward catch motion as the title host during window-hint collapse.
- [ ] No visible separation appears between title and workspace host backgrounds during collapse.
- [ ] SuperIsland width growth into the title-row width is animated during bar-expanded hint entry.
- [ ] Title capsules do not replay a full entrance animation on the first live window switch after the hint is already open.
- [ ] `timeout 5 qs --path .` passes after the fix.

## Implementation Notes

- This is primarily a motion-ownership fix, not a restyle.
- Treat `SuperIslandWidget.qml` as the owner of host width, attached reveal progress, collapse timing, and host-level catch motion.
- Treat `IslandWindowHintCard.qml` as the owner of inner title/workspace content presentation, but avoid restarting full entry motion for live updates once the host is already active.
- If animation state is derived from reveal progress, ensure that live window switches while held do not reset that reveal progress path or re-trigger first-entry handoff visuals.
