# Bar Popup Single-Instance Transition Design

## Goal

Make ordinary hover menus and right-click context menus behave as one reusable
menu per screen. When the pointer moves between widgets, the existing menu
instance moves to the new anchor and morphs to the new menu size instead of
closing and recreating a surface.

Content replacement uses a short crossfade: the current content fades out,
the new intent is installed, and the new content fades in. Position and size
continue toward the latest target throughout the content transition.

## Scope

- `BarPopupHost` remains the only per-screen popup owner.
- Hover and context intents use the same update path and content owner.
- The outer `PanelWindow` remains full-screen and fixed-size.
- Only the inner popup container geometry is animated.
- Existing reveal, close-delay, popup-hover bridge, and settings-layer colors
  remain unchanged unless required by the transition implementation.

## Behavior

### Initial Open

The first intent activates the host and uses the existing two-layer reveal.
There is no content crossfade because no prior menu is visible.

### Target Replacement

When an open host receives a different widget or menu kind:

1. Store the newest intent as the pending target and increment a transition
   sequence number.
2. Animate content opacity to zero using `MotionTokens.fast`.
3. At the end of the fade-out, apply the pending intent only if its sequence
   number is still current.
4. Animate content opacity back to one using `MotionTokens.fast`.

If a newer target arrives during either fade, the previous transition is
cancelled. The latest target wins, and no stale completion callback may apply
old data.

### Geometry

The host maintains target geometry separately from displayed geometry:

- `targetX`, `targetY`: anchor and direction-derived destination.
- `targetWidth`, `targetHeight`: dimensions required by the active menu.
- `displayX`, `displayY`, `displayWidth`, `displayHeight`: current rendered
  geometry.

Each target change retargets interruptible `NumberAnimation`s on the inner
  popup container. Position and size are allowed to animate while content is
  fading, so moving across widgets remains spatially continuous.

The target height must represent the currently selected menu, not the maximum
of hover and context menu heights. The container must still retain enough
height during a fade-out to avoid clipping the outgoing content before the
replacement is installed. After replacement, it animates to the new measured
height.

Top-bar and bottom-bar anchoring continue to use the final target height when
calculating `targetY`. Horizontal placement continues to use the existing
screen-edge clamp.

### Reduced Motion

When `MotionTokens.reducedMotion` is enabled, content is replaced immediately
and all transition geometry is assigned directly to its target. Existing
visibility and interaction contracts remain intact.

### Closing and Reopening

Closing keeps the current intent alive until the existing reveal exit finishes.
An intent arriving during the close cancels the pending close and resumes the
same instance without a second surface. `dismissImmediately()` remains a hard
reset for overlay ownership changes and explicit dismissal.

## Component Changes

### BarPopupHost

- Add transition state for current/pending intent and a monotonically
  increasing sequence number.
- Centralize intent field extraction so hover and context updates share it.
- Separate target geometry calculation from displayed geometry.
- Add interruptible geometry animations using `MotionTokens` and the existing
  easing contract.
- Add opacity animation around content replacement. The opacity layer must be
  non-interactive while content is not fully visible.
- Keep `BarPopupActions` and `BarContextPopupActions` mounted once and switch
  their bindings in place.

### BarContent and TopBar

No new popup owners are introduced. Existing signal forwarding remains the
single path for hover, anchor updates, and context intents. Both handlers must
continue calling `updateIntent()` rather than dismissing the host first.

## Testing

Extend the popup harnesses to verify:

- One host instance serves two sequential hover intents.
- Hover-to-context and context-to-context changes do not dismiss the host.
- The pending intent wins after rapid successive replacements.
- Content opacity reaches zero before a replacement and returns to one after it.
- Target geometry changes without resizing the outer `PanelWindow`.
- Height follows the selected menu rather than the maximum of both menu types.
- Bottom-bar placement recalculates from the target height.
- Reduced-motion replacement skips the crossfade and lands directly at target
  geometry.

Existing visibility, layer-color, action, and context-action tests must remain
green. Runtime verification should include a shell startup check and a manual
pointer sweep across widgets on both top and bottom bar configurations.

## Non-Goals

- No per-widget popup instances.
- No new popup window or layer-shell surface.
- No spring or bounce motion; this is frequent hover navigation and should use
  restrained, interruptible transitions.
- No unrelated changes to menu content styling or settings overlay ownership.
