# Design: Unified Ear-Body Animation Direction

## Conclusion

For future large-scale scaling, translation, morphing, and visibility transitions, the bar ears and the dockzone body should eventually return to a single shared geometry owner.

The current split architecture is useful as a visibility workaround:

- `BarDockZoneBackground.qml` owns the body and top ears
- `BarBottomEarWindow.qml` owns the bottom ears in separate overlay windows

That split is acceptable for static rendering or tiny motion tweaks, but it is the wrong long-term model for continuous unified animation.

## Why The Current Split Hurts Animation

### 1. Two different motion spaces

The body animates inside the main bar window, while bottom ears animate in separate overlay windows. Even when values are synchronized, they do not share one transform tree.

Result:

- different anchor origins
- different clipping / visibility rules
- harder-to-match timing during scale and translation

### 2. Shape morphing becomes coordination, not animation

When one object is split across multiple windows, a future "single deforming island" effect becomes multiple separate animations that only try to look unified.

Result:

- more bookkeeping
- more drift risk
- harder debugging

### 3. Visibility fixes fight animation quality

Overlay windows solved the bottom-ear visibility problem, but they did so by prioritizing rendering freedom over geometry unity.

This is a valid short-term workaround, not a strong final animation architecture.

## Recommended Target Architecture

### Final direction

Use one shared geometry owner for the whole dockzone silhouette per animated zone.

Recommended mental model:

```text
DockzoneSurface
├── body geometry
├── left ear geometry
└── right ear geometry
```

All visible silhouette parts should derive from one geometry model and one animation timeline.

### Shared geometry state

These values should become the single source of truth for all ear/body motion:

- `bodyWidth`
- `bodyHeight`
- `bodyRadius`
- `earRadius`
- `leftEarOffset`
- `rightEarOffset`
- `bottomEarDepth`
- `opacity`
- `scale`
- `translationX`
- `translationY`

If these remain spread across separate windows and separate item trees, unified animation will remain fragile.

## Practical Migration Strategy

### Phase 1: centralize geometry state

Before changing rendering again, move all ear/body layout numbers behind one shared geometry model.

This can still feed the current overlay solution temporarily.

### Phase 2: reduce rendering owners

Replace the bottom-ear overlay windows with rendering that belongs to the same geometry owner as the body.

Possible implementation directions later:

- one larger transparent bar surface that contains body + ears
- one custom geometry/mask owner for the whole silhouette
- one visual root with animation applied above all ear/body parts together

### Phase 3: animate only the shared model

Drive all future motion from shared properties instead of animating each ear/window independently.

## When Overlay Windows Are Still Fine

Keep the current overlay-window approach only if the motion needs are limited to:

- tiny hover shifts
- subtle opacity fades
- rare appearance toggles

Do not treat it as the preferred base for:

- large scale changes
- coordinated squash/stretch
- continuous morphing
- island-like repositioning with ear/body continuity

## Trade-off Summary

### Keep overlay windows

- easier short-term visibility
- lower immediate refactor cost
- worse long-term animation unity

### Return to single geometry owner

- harder refactor
- much better continuity for large motion
- simpler future animation reasoning

## Recommendation

Treat `BarBottomEarWindow.qml` as a transitional workaround, not the final architecture.

If unified ear-body animation is a real future goal, the next serious implementation task should be: consolidate body and ears under one shared geometry owner, then animate that owner as one object.
