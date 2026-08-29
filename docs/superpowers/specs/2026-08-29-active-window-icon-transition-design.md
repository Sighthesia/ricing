# Active Window Icon Transition

## Goal

Make Active Window icon changes visually match the existing `MarqueeLabel`
character transition used by the title and application name.

## Behavior

- The outgoing icon falls downward and fades out.
- The incoming icon enters from above and fades in.
- Both layers overlap during the transition; the incoming icon is not shown
  until its image is ready.
- Window changes and workspace changes use the same trigger path.
- Empty-icon transitions retain the outgoing layer long enough to complete its
  downward fade, then collapse the icon slot.
- Reduced motion skips the transition and shows only the final state.

## Parameters

Use `MarqueeLabel`'s existing transition contract rather than new constants:

- `ghostFallTime` for the outgoing icon opacity and fall animation.
- `ghostFallDistanceScale` multiplied by the icon height for the downward
  distance.
- `scanRevealMs` for the incoming opacity animation.
- `MotionTokens` easing and reduced-motion gating.

## Ownership

`ActiveWindow.qml` owns the current and outgoing icon layers and triggers the
transition from its synchronized active application state. The title and app
name continue to use `MarqueeLabel`; no changes to Media are required.

## Verification

- `qmllint modules/bar/widgets/ActiveWindow.qml modules/bar/MarqueeLabel.qml`
- Check icon transitions for window-to-window, workspace-to-window,
  icon-to-empty, and empty-to-icon changes.
- Confirm no image layer becomes permanently invisible after a rapid switch.
