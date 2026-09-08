# Bar Popup Content and Geometry Transition

## Goal

When the pointer moves between bar widgets, the existing single popup should glide to the new anchor and morph to the new content size. Content must remain fully opaque. The new content is committed after the geometry transition reaches approximately 45%, so the popup is already moving before its content and measured size change.

## Scope

- Applies to `BarPopupHost` intent replacement between different widgets or action kinds.
- Reuses the existing single popup host, content layers, geometry targets, and `MotionTokens`.
- Keeps the current close delay, reveal behavior, tray submenu behavior, and reduced-motion contract.
- Removes cross-component opacity animation entirely.

## Interaction Contract

For an `A -> B` replacement:

1. Receive B and cancel any pending close.
2. Capture B as `pendingIntent` and increment a replacement serial.
3. Keep A rendered and fully opaque.
4. Start or retarget `displayX`, `displayY`, `displayWidth`, and `displayHeight` toward B's geometry.
5. At roughly 45% of the shared transition progress, commit B to `currentIntent`.
6. Re-measure B and retarget width and height from their current displayed values.
7. Let the same geometry animations settle without restarting from zero.

The 45% point is a timing target, not a fixed millisecond delay. It must follow the shared duration selected by `MotionTokens.medium`, and it must be safe when one property reaches its target before the others.

## State and Ownership

`BarPopupHost` remains the sole owner of replacement state:

- `currentIntent`: content currently bound to the popup.
- `pendingIntent`: newest intent waiting for the exchange point.
- `transitionSerial`: invalidates stale deferred exchanges.
- `displayX/displayY/displayWidth/displayHeight`: current rendered geometry.
- `targetX/targetY/targetWidth/targetHeight`: current geometry goal.
- `transitionProgress`: normalized shared progress for the current replacement.

The content layer owns measurement. The host owns target geometry and animation. No second popup instance or crossfading content layer is introduced.

## Replacement and Cancellation

Every replacement schedules an exchange with its serial. If another intent arrives before the exchange, the previous schedule becomes stale and must do nothing. The newest intent replaces `pendingIntent`.

If a close begins, invalidate the serial and clear `pendingIntent`. A deferred callback must not install content after close has started. If reduced motion is enabled, commit the newest intent immediately and assign final geometry directly.

## Measurement and Geometry

The old content stays mounted until the exchange point. After committing the new intent, its content must complete its normal binding and measurement cycle before `targetWidth` and `targetHeight` are recalculated. The recalculation must use the measured preferred size and the current screen bounds.

The displayed geometry is always the animation source. Updating the target must not assign `display*` directly during a normal replacement. This prevents jumps when the user changes direction repeatedly.

The outer layer-shell surface remains fixed to the screen. Only the inner clipped popup geometry is animated, preserving the existing protocol and input behavior.

## Motion

- Position and size use `MotionTokens.medium` and `Easing.OutQuint`.
- No opacity animation is used for replacement content.
- Existing reveal and close animations remain unchanged.
- All motion is gated by `MotionTokens.reducedMotion`.
- The popup keeps the established sharp rectangular surface language.

## Testing

Add or update tests at the composed popup seam to cover:

- Different widget identities retain opacity at `1` throughout replacement.
- Content is still A before the exchange point and B after it.
- Width and height retarget from their current displayed values after B is measured.
- Rapid `A -> B -> C` switches commit only C.
- A close invalidates a pending exchange.
- Reduced motion commits immediately and leaves final geometry stable.
- Existing tray-to-tray, status popup, content, and two-layer tests remain warning-free.

## Acceptance Criteria

- Moving between any supported bar widgets produces one continuous popup glide.
- Position, width, and height morph without a blank frame or opacity dip.
- Content changes around the midpoint of the geometry transition.
- Rapid pointer movement never displays stale content after the newest intent is accepted.
- Existing close, submenu, input, and reduced-motion behavior remains intact.
