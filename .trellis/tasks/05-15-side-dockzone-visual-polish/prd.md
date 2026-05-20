# Polish side dockzone visual alignment

## Goal

Fix pixel-level visual alignment issues in the newly unified side dockzone rendering so the left and right sections match the silhouette quality of the legacy `BarDockZoneBackground` path.

## Confirmed Facts

- The unified `DockzoneSurfaceRoot.qml` now renders left/center/right through one owner tree.
- The legacy `BarDockZoneBackground.qml` still exists as a reference for correct side geometry.
- Comparing new vs legacy code reveals these specific alignment issues:

### Issue 1: Left section container width

Legacy: `bodyWidth + (hasLeftTopEar ? earRadius : 0) + (hasTopRightEar ? earRadius : 0)`
For left: `bodyWidth + 0 + earRadius = bodyWidth + earRadius`

New model: `containerWidth = bodyWidth + earRadius` (same for left)
But `bodyX = 0` for left, so the top-right ear starts at `bodyX + bodyWidth - 1 = bodyWidth - 1`.

This means the top-right ear for left may be 1px off from the legacy position where it started at `bodyX + bodyWidth - 1` with `bodyX = 0`.

### Issue 2: Bottom ear X positions

Legacy `BarBottomEarWindow.qml`:
- Left bottom ear: `margins.left: root.earRadius` (24px from left edge)
- Right bottom ear: `margins.right: 0` (flush with right edge)

New `DockzoneSurfaceRoot.qml`:
- Left bottom ear: `x: root.metrics.bottomLeftEarX` where `bottomLeftEarX = 0`
- Right bottom ear: `x: root.metrics.bottomRightEarX` where `bottomRightEarX = bodyWidth`

The left bottom ear in legacy was offset by `earRadius` from the screen edge, but in the new code it's at `x: 0` within the container. Since the left body starts at `x: 0` in the container, the bottom ear should attach at the body's inner edge, not the outer edge.

### Issue 3: Right top ear x position

Legacy: `x: root.bodyX + root.bodyWidth - 1`
New: same formula via `root.bodyX + root.bodyWidth - 1`

This should be correct, but needs visual confirmation.

### Issue 4: Bottom ear Y overlap

Legacy overlay: `margins.top: Services.BarLayoutService.barHeight` (left) and `barHeight - 1` (right)
New: `y: root.metrics.bottomEarY - 1` where `bottomEarY = visibleBodyHeight`

The legacy left ear was flush at barHeight, while the right was 1px overlapping. The new code uses `-1` for both. This is a minor inconsistency.

## Requirements

- Fix bottom ear X positioning to match legacy attachment points.
- Ensure top-right ear for left section aligns correctly.
- Match legacy bottom ear Y overlap behavior per side.
- Keep center path unchanged.
- Keep model/owner architecture unchanged.

## Acceptance Criteria

- [ ] Left bottom ear attaches at the correct body-edge position matching legacy behavior.
- [ ] Right bottom ear attaches at the correct body-edge position matching legacy behavior.
- [ ] Top ears for side sections align with legacy positions.
- [ ] Center rendering remains unchanged.
- [ ] Affected files pass static validation.

## Out of Scope

- New floating visual effects.
- Architecture changes.
- Left/right floating trigger.

## Open Questions

- None blocking planning.
