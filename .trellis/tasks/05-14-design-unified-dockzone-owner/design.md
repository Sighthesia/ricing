# Design: Unified Dockzone Geometry Owner

## Conclusion

The final architecture should move body and all ears back under one shared dockzone geometry owner.

That owner may live inside a transparent container that is larger than the visible bar body. This is the mechanism that allows unified animation without forcing the visible bar body itself to become taller.

## Core Principle

Separate these two concepts:

1. **Visible body height**
   The height users perceive as the dockzone body.

2. **Geometry container height**
   A larger transparent region that gives ears and future morph/scale motion enough room to exist while staying attached to the same owner.

The current implementation mixes those concerns and then compensates with overlay windows. The target architecture should model them explicitly.

## Recommended Target Structure

```text
DockzoneWindow
└── DockzoneSurfaceRoot
    ├── geometry container
    │   ├── body geometry
    │   ├── top-left ear
    │   ├── top-right ear
    │   ├── bottom-left ear
    │   └── bottom-right ear
    └── content region
```

## Responsibilities

### DockzoneWindow

- owns the outer transparent surface
- may be larger than the visible body height
- should not own ear/body geometry rules directly

### DockzoneSurfaceRoot

- becomes the single geometry owner
- owns all ear/body layout relationships
- exposes one animation timeline / one shared parameter model

### Content region

- defines where widgets/text should visually center
- stays aligned to the visible body area, not the full transparent container
- prevents content drift when ear or container geometry changes

## Shared Geometry Model

All rendering and animation should derive from one parameter set.

Recommended shared properties:

- `visibleBodyWidth`
- `visibleBodyHeight`
- `containerWidth`
- `containerHeight`
- `bodyRadius`
- `earRadius`
- `topEarInsetLeft`
- `topEarInsetRight`
- `bottomEarDropLeft`
- `bottomEarDropRight`
- `contentRegionY`
- `contentRegionHeight`
- `scale`
- `translateX`
- `translateY`
- `opacity`
- `morphProgress`

## Why This Improves Animation

### 1. One transform tree

Large scale and translation changes can be applied once at the shared root instead of synchronized across multiple windows.

### 2. One timing model

Ear/body visibility and morph transitions can derive from one progress value, which keeps their timing naturally coherent.

### 3. One geometry truth

If ears and body consume the same parameter model, large motion stops being a coordination problem and becomes an ordinary shape animation problem.

## Migration Strategy

### Phase 1: centralize geometry parameters

Before changing rendering ownership, move current ear/body numbers behind one shared geometry model.

### Phase 2: retire overlay ownership

Replace `BarBottomEarWindow.qml` as the long-term bottom-ear owner and move bottom-ear rendering back under the unified surface root.

### Phase 3: introduce explicit content region

Keep widget/text alignment tied to a dedicated visible body region instead of the full transparent container.

### Phase 4: animate the shared root

Future major motion should target the shared owner and its parameter model, not separately animated ear/window fragments.

## Trade-offs

### Benefits

- strongest long-term animation coherence
- simpler future reasoning about motion
- fewer synchronization bugs
- natural support for large morphs and continuous motion

### Costs

- requires a real refactor
- the current overlay-ear workaround becomes transitional only
- geometry math becomes more explicit and slightly more abstract

## Recommendation

Treat `BarBottomEarWindow.qml` as a temporary visibility workaround.

The next implementation task should be framed as:

**"Rebuild the dockzone as one shared deformable surface with a larger transparent geometry container and a stable visible content region."**
