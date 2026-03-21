# Bar Transient Y-Reveal Design

**Date:** 2026-03-21  
**Status:** Proposed

## Goal

Create one shared bar-local geometry contract for transient vertical reveal so dynamic bar widgets can show extra information by changing height and reserving downward bar space without each widget owning its own Y-axis animation state machine.

This work intentionally standardizes Y-axis geometry ownership only. It does not force all widgets to share the same X-axis motion or content choreography.

## Related Work

This design builds on:

- `docs/superpowers/specs/2026-03-19-dynamic-bar-expansion-design.md`
- `docs/superpowers/specs/2026-03-20-position-driven-expansion-refactor-design.md`

The 2026-03-19 design established a shared bar-local expansion contract through `BarExpandTransition.qml` for width and height overshoot behavior.

The 2026-03-20 design established that layout-native push-down expansion should remain separate from bar-local motion. That boundary still stands. Bar widgets must keep a bar-local contract because they interact with bar window geometry and temporary downward extension below the exclusive zone.

## Problem

The current shell still has a severe Y-axis ownership problem across transient bar widgets.

Today, a single reveal often has several geometry owners at once:

- a widget animates its own visual height
- a background item animates another height path
- a clip shell owns a separate height path to avoid cropping during motion
- `BarLayoutService.qml` reserves downward bar extension through widget-specific properties
- child rows or tracks may also animate `y` on the same reveal path

This causes several recurring failures:

- animation state machines become large and fragile
- timing drifts between background, clip shell, and bar extension
- one widget cannot easily inherit another widget's Y-axis behavior
- fast retargeting produces clipping, resize churn, or stale extension locks
- widgets that only need a simple reveal still have to hand-build a complex timeline

This is most visible in:

- `modules/bar/widgets/WorkspaceWidget.qml`
- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/widgets/SystemTrayWidget.qml`

## Decision

Introduce a new bar-local Y-axis geometry owner dedicated to transient reveal.

Suggested component:

- `modules/bar/BarTransientRevealHost.qml`

This host becomes the only owner of vertical reveal geometry for adopted widgets.

Each widget keeps its own business semantics and content choices, but hands the following responsibilities to the host:

- background surface height
- clip height for revealed content
- reserved downward bar extension
- open and close timing for the Y-axis path

This design does not replace all motion with a single helper. Instead, it defines a strict ownership split:

- widget: decides when reveal is needed and what content should appear
- shared host: decides how much vertical space is visible and reserved
- content subtree: remains laid out in final positions and is merely revealed

## Architecture

### 1. Layered responsibility model

Each transient bar widget is split into three layers.

#### Semantic trigger layer

Widget-local logic or services still decide when transient information should appear.

Examples:

- workspace switch flash
- super island event reveal
- system tray hover reveal
- future system monitor hover reveal

This layer does not animate Y-axis geometry.

#### Shared reveal geometry layer

`BarTransientRevealHost.qml` owns the full vertical reveal contract.

Its job is to translate one boolean reveal request and two heights into a consistent visual result:

- one animated surface height
- one clip height that exposes content
- one reserved extension value reported to the bar layout service

This is the equivalent of giving every widget the same drawer rail instead of asking each widget to invent its own hinge and spring.

#### Content presentation layer

The widget's transient content is laid out in its final positions from the beginning.

The content layer may still perform small local effects such as:

- opacity fades
- content replacement
- pulse or highlight overlays
- X-axis width motion when needed

The content layer must not own the main Y-axis reveal geometry.

### 2. New primitive

#### `modules/bar/BarTransientRevealHost.qml`

Suggested responsibility:

- own the Y-axis geometry timeline for transient reveal
- expose separate values for visual surface height and clip height
- reserve extra downward bar space through a service-backed registration
- support close-phase extension hold so the bar window does not resize every frame
- retarget cleanly during rapid trigger changes

It does not decide:

- when a widget should reveal
- what content is rendered in the transient area
- how the widget behaves on the X axis
- how services queue or replace business events

### 3. Suggested API shape

```qml
Item {
    required property real collapsedHeight
    required property real expandedHeight
    required property bool expanded
    required property string extensionOwnerKey

    property bool animateSurface: true

    readonly property string state
    readonly property real surfaceHeight
    readonly property real clipHeight
    readonly property real reservedExtension
    readonly property bool running
}
```

Contract notes:

- `collapsedHeight` is the stable pill height visible in the default bar state
- `expandedHeight` is the full revealed height for the transient area
- `surfaceHeight` is the background surface height used by the visual pill or shell
- `clipHeight` is the visible region for the content subtree
- `reservedExtension` is the extra height below `Theme.barHeight` that must remain available at the bar window level

### 4. State model

The host owns only geometry state:

- `closed`
- `opening`
- `open`
- `closing`

State rules:

- first sync is non-animated and reflects the current truth
- when `expanded` becomes `true`, the host moves toward `expandedHeight`
- when `expanded` becomes `false`, the host moves toward `collapsedHeight`
- if `expanded` changes during motion, the host retargets from the current live values
- during `closing`, `reservedExtension` stays at the full expanded reservation until the close motion completes
- the host clears the registered extension immediately before entering `closed`

This keeps the vertical path consistent without forcing widgets to mirror the same geometry phase names.

### 5. Geometry model

The host publishes three related but distinct values because visual motion and layout reservation are not the same problem.

#### `surfaceHeight`

Used by the widget's visible background or shell.

This value may bounce, settle, or otherwise follow a shared visual motion token set.

#### `clipHeight`

Used by the outer clip container that reveals or hides the transient subtree.

V1 contract:

- when opening starts, `clipHeight` snaps immediately to `expandedHeight`
- when closing starts, `clipHeight` animates back to `collapsedHeight` with a simple non-overshooting timing path
- `clipHeight` must never use a more expressive bounce or overshoot than `surfaceHeight`

This keeps content fully available during reveal while still making the close path predictable for implementation and testing.

#### `reservedExtension`

Used by `BarLayoutService.qml` and ultimately `BarWindow.qml`.

This value should be stable enough to avoid resize churn in the outer bar window. It should not blindly mirror every intermediate surface animation frame.

That separation is essential. If the window reservation follows the visible height frame by frame, the compositor work returns immediately.

### 6. Shared timing tokens

This design should derive any new Y-axis timing from `Theme.anim.*` and, if needed, extend the semantic bar motion token set instead of adding widget-local literals.

V1 host behavior is intentionally opinionated:

- `surfaceHeight` may use the shared bar-local motion signature
- `clipHeight` always uses snap-open and simple animated-close behavior
- `reservedExtension` always releases only when the host finishes closing

These are contract rules for the first migration wave, not per-widget runtime toggles.

Suggested additions if the current token family is not enough:

- `Theme.anim.barRevealOpenDuration`
- `Theme.anim.barRevealCloseDuration`
- `Theme.anim.barRevealHoldDuration`
- `Theme.anim.barRevealSurfaceType`
- `Theme.anim.barRevealClipType`

These remain semantic bar-local tokens, not widget-specific timers.

## Bar Layout Service Integration

## 1. Replace per-widget extension properties with a registry

The current service owns separate fields such as:

- `workspaceFlashExtension`
- `superIslandFlashExtension`
- `mediaControlFlashExtension`
- `systemTrayFlashExtension`

That model does not scale because every new transient widget needs a new service property and a new binding contract.

Replace this with a registration-based model:

```qml
function setTransientExtension(ownerKey, height)
function clearTransientExtension(ownerKey)
readonly property var transientExtensions
readonly property int barTransientExtension
```

Rules:

- each reveal host writes through `extensionOwnerKey`
- the service stores the latest claimed extension per owner
- `barTransientExtension` is the max of all registered values
- `BarWindow.qml` consumes `barTransientExtension`

This makes the service own only aggregation, not widget-specific transient semantics.

## 2. Compatibility bridge during migration

Migration should not require every widget to move in the same patch.

During the migration wave, the service may temporarily keep legacy properties and internally bridge them into the new registry so existing widgets continue to work while early adopters use the new host.

That bridge is transitional only and should be removed once the targeted widgets are migrated.

Bridge rules:

- a widget may write through the legacy path or the registry path during migration, but never both at the same time
- the first migration wave ends once `SystemTrayWidget.qml`, `WorkspaceWidget.qml`, and `SuperIslandWidget.qml` no longer require widget-specific extension properties
- once that wave is complete, the legacy properties should be removed in the next cleanup patch instead of staying as a permanent compatibility layer

## Integration Rules

When a widget adopts `BarTransientRevealHost.qml`, the following rules become mandatory.

### 1. One Y-axis owner only

The host is the only owner of the primary Y-axis reveal path.

The adopted widget must not also animate on that same path:

- `height`
- `implicitHeight`
- container `y` used as a substitute for reveal height
- child row `y` when that row still contributes to the host's visible reveal geometry

Allowed child-only motion:

- `opacity`
- `color`
- `scale`
- pulse overlays
- content replacement timing

### 2. Pre-layout the transient content

The transient subtree should be declared in its final vertical structure before the reveal begins.

The reveal effect comes from changing how much of that subtree is visible, not from having the subtree construct its final positions through several local animations.

### 3. Separate Y-axis and X-axis ownership

Widgets may keep local X-axis behavior when it is part of their identity.

Examples:

- `WorkspaceWidget.qml` may keep its horizontal pill morph
- `SuperIslandWidget.qml` may keep width personality or pulse choreography
- `SystemTrayWidget.qml` may still vary horizontal width based on pinned versus expanded rows

The shared host standardizes only the vertical reveal and bar reservation path.

## Per-Widget Application

### `SystemTrayWidget.qml`

This is the best first migration target because its semantics are simple:

- a stable pinned row
- an expanded strip for flash or hover reveal

Migration intent:

- replace local `implicitHeight` and background height behaviors with the shared host
- keep pinned and transient rows mounted in final vertical positions
- let the host control clip height, background height, and reserved extension
- keep hover and flash as semantic triggers only

Expected result:

- a clear sample implementation for future bar widgets
- less widget-local timer and geometry coupling

### `WorkspaceWidget.qml`

This is the most urgent migration target because its current Y-axis path mixes clip ownership, background ownership, and service extension locking.

Migration intent:

- preserve workspace switch semantics
- keep existing X-axis personality and focus versus overview width behavior
- pre-layout the flash strip under the stable pill row
- replace widget-local Y-axis reveal logic with the shared host

Expected result:

- the widget still reveals extra workspace information during a switch
- bar extension stays stable during close
- the widget no longer needs several separate Y-axis safety mechanisms

### `SuperIslandWidget.qml`

This widget should migrate after the host API is proven by simpler widgets.

Migration intent:

- keep event semantics and content replacement phases
- remove phase ownership of Y-axis geometry
- let the shared host own background height, clip height, and reserved extension
- keep pulse, content swap, and emphasis effects only where they do not reclaim Y-axis ownership

Expected result:

- the widget keeps its semantic identity
- the vertical reveal path becomes consistent with other transient widgets

### `SuperSystemMonitorWidget.qml`

This widget does not yet need migration because it is currently static.

If it later gains hover or transient reveal behavior, it should adopt the new host from the beginning rather than reintroduce widget-local Y-axis animation patterns.

## Migration Sequence

Recommended order:

1. `modules/bar/widgets/SystemTrayWidget.qml`
2. `modules/bar/widgets/WorkspaceWidget.qml`
3. `modules/bar/widgets/SuperIslandWidget.qml`
4. future adopters such as `modules/bar/widgets/SuperSystemMonitorWidget.qml`

Reasons:

- `SystemTrayWidget.qml` is the simplest semantic sample
- `WorkspaceWidget.qml` has the highest immediate complexity payoff
- `SuperIslandWidget.qml` should move only after the new host contract is proven

## First-Wave Acceptance Criteria

The first migrated widget should demonstrate the contract clearly before broader adoption.

For `modules/bar/widgets/SystemTrayWidget.qml`, acceptance should mean:

- flash reveal and hover reveal both use `BarTransientRevealHost.qml` for Y-axis geometry
- the widget no longer writes `systemTrayFlashExtension` directly
- background height, content reveal, and reserved bar extension stay visually synchronized during open and close
- rapid hover enter and leave does not leave stale reserved extension behind

## Risks and Controls

### Risk: double-driving the same Y-axis path

If widgets keep their old height or row-travel animations while also adopting the host, the current complexity returns under a new name.

Control:

- require a strict owner rule for the adopted Y axis
- explicitly remove widget-local `height`, `implicitHeight`, and reveal-driving `y` animations from migrated widgets

### Risk: runtime content makes expanded height unstable

If expanded height changes unpredictably during reveal, the host will retarget often and the motion may feel noisy.

Control:

- prefer predefined transient area heights derived from stable bar tokens
- keep the first migration wave on widgets whose revealed height is already structurally predictable

### Risk: close-phase clipping or bar resize churn

If reserved bar extension drops at the same moment visual closing starts, transient content may be clipped or the bar window may resize every frame.

Control:

- keep `reservedExtension` separate from `surfaceHeight`
- allow hold-on-close behavior in the host

### Risk: flattening widget semantics too aggressively

If migration removes every local animation, widgets may lose their identity.

Control:

- standardize Y-axis geometry only
- preserve content semantics, X-axis personality, and local emphasis effects where they do not reclaim Y-axis ownership

## Validation

### Automated

- add a dedicated QML harness for `BarTransientRevealHost.qml`
- verify open, close, retarget, and hold-on-close behavior
- verify the registered bar extension remains stable during close
- verify widgets adopting the host no longer write widget-specific extension fields directly
- run `timeout 5 qs --path .`

### Manual

- rapidly switch workspaces and verify the extra strip is revealed without visible outer resize churn
- trigger super island events back to back and verify semantics remain intact while the vertical reveal stays unified
- trigger tray flash reveal and hover reveal and verify they share the same vertical motion language
- verify the bar's downward extension feels consistent across adopted widgets

## Non-Goals

- do not unify all content animation into one helper
- do not force widgets to share one X-axis motion system
- do not convert bar widgets to the layout-native `PositionDrivenExpander.qml` contract
- do not replace `AnimatedPanelBase.qml` or panel surface logic
- do not redesign business semantics for workspace, tray, or super island events

## Outcome

After this refactor, dynamic bar widgets should follow a cleaner contract:

- semantic triggers stay widget-local
- Y-axis reveal geometry becomes shared and predictable
- downward bar reservation becomes service-registered instead of widget-specific
- content identity remains local while vertical reveal feels like one system

This reduces animation state complexity where it hurts most, especially on the Y axis, without forcing the entire bar into one overly generic animation abstraction.
