# Dynamic Bar Expansion Design

**Date:** 2026-03-19  
**Status:** Proposed

## Goal

Unify the expansion and collapse visual language across all dynamic bar widgets by extracting a reusable transition layer that drives size overshoot, rebound, and pulse feedback from shared tokens and settings.

## Scope

This design applies to dynamic bar widgets that visually expand or collapse inside the bar.

Initial migration targets:

- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/widgets/WorkspaceWidget.qml`

Deferred from the first wave:

- `modules/bar/widgets/SuperSystemMonitorWidget.qml`

Non-goals for this work:

- changing service-side business logic or event routing
- redesigning widget content layout
- changing panel-only motion in `AnimatedPanelBase.qml`
- unifying hover-only highlight effects that do not change widget geometry

## Product Intent

All dynamic bar widgets should feel like they belong to the same product family.

The shared motion language is:

1. before expand, the surface eases into a slight reverse compression
2. it then snaps forward into a partial overshoot beyond the target size
3. it settles back to the target expanded size
4. a pulse flash plays in sync with the forward expansion beat
5. before collapse, the surface eases into a slight reverse expansion
6. it then snaps inward past the stable collapsed size
7. it settles back to the target collapsed size

This creates one recognizable motion signature while still allowing each widget to choose its own geometry and axis emphasis.

## Architecture

### 1. Shared animation contract

Introduce a reusable bar-local transition component under `modules/bar/`.

Suggested name:

- `modules/bar/BarExpandTransition.qml`

Responsibility:

- own the unified expand/collapse animation timeline
- accept current and target geometry values from a widget
- emit animated geometry and pulse state back to the widget
- centralize the overshoot and rebound math
- consume only `Theme` tokens that were already derived from settings by the config layer

It does **not** decide:

- when a widget should expand or collapse
- what content is rendered in each state
- how services schedule or replace business events

That separation keeps widget behavior local while making the visual execution reusable.

### 2. Theme token layer

Extend `config/Theme.qml` by deriving a dedicated semantic group from the existing `Theme.anim.*` system instead of creating a parallel animation family.

Suggested namespace:

- `Theme.anim.barExpand*`

Suggested token groups:

- phase durations derived from `Theme.anim.moveDuration`, `Theme.anim.highlightDuration`, and `Theme.anim.springDuration`
- easing choices derived from `Theme.anim.moveType`, `Theme.anim.highlightType`, and `Theme.anim.springType`
- reverse-preload ratios for expand and collapse
- overshoot ratios for expand and collapse
- settle ratios
- pulse scale and opacity defaults

Rule:

- `Theme.anim.*` remains the single animation root
- the new bar-expansion tokens are semantic aliases and ratios built on top of that root
- widgets consume only `Theme`, never raw settings values

This keeps brand motion in the token layer rather than scattering timing literals across widgets or creating a second token hierarchy.

### 3. Settings layer

Extend `services/SettingsService.qml` and `config/settings-default.json` with a global motion settings section for dynamic bar expansion.

Suggested schema:

```json
{
  "barMotion": {
    "preset": "balanced",
    "intensity": 1.0,
    "speedMultiplier": 1.0,
    "pulseEnabled": true
  }
}
```

Meaning:

- `preset`: coarse product style choice such as `soft`, `balanced`, `snappy`
- `intensity`: scales reverse preload and overshoot amplitude
- `speedMultiplier`: globally speeds up or slows down the unified motion
- `pulseEnabled`: enables or disables pulse flash playback

This is intentionally small. The settings panel should expose a few meaningful controls rather than every raw animation parameter.

### 4. Widget integration pattern

Each widget keeps its own state machine and layout math, but hands geometry changes to the shared transition layer.

The widget remains responsible for:

- deciding whether it is visually collapsed or expanded
- computing `collapsedWidth`, `expandedWidth`, `collapsedHeight`, `expandedHeight`
- choosing whether motion applies on width, height, or both axes
- choosing where pulse should be rendered

The transition layer becomes responsible for:

- computing intermediate animated width and height
- performing reverse preload before the main movement
- overshooting past the target and settling back
- synchronizing pulse timing with the forward beat

Adoption rule for each driven axis:

- once a widget hands width ownership to the shared transition layer, it must remove or disable local `Behavior`, `NumberAnimation`, `PropertyAnimation`, `Transition`, or state binding paths that also animate that same width path
- once a widget hands height ownership to the shared transition layer, it must remove or disable local animation ownership for that same height path
- content choreography that does not own final geometry, such as opacity, track handoff, or content replacement, may remain widget-local

This is similar to giving every widget the same suspension system while letting each one keep its own body shape.

## Reusable API Shape

The shared component should expose a small geometry-first API.

There must be exactly one truth source for normal runtime motion state:

- declarative state via the `expanded` property

Do not mix property-driven state with separate imperative playback entry points for ordinary widget interaction, because that would recreate double-driving risk in a new form.

Suggested public inputs:

- `required property real collapsedWidth`
- `required property real expandedWidth`
- `required property real collapsedHeight`
- `required property real expandedHeight`
- `property bool expanded`
- `property bool animateWidth`
- `property bool animateHeight`
- `property real widthBias`
- `property real heightBias`
- `property bool pulseEnabled`
- `property real pulseOpacityScale`

Suggested public outputs:

- `readonly property real animatedWidth`
- `readonly property real animatedHeight`
- `readonly property real pulseOpacity`
- `readonly property real pulseScale`
- `readonly property bool running`

Suggested optional imperative helpers:

- `function snapToExpanded()`
- `function snapToCollapsed()`

Rule:

- normal runtime transitions must be triggered by changing `expanded`
- imperative helpers are reserved for lifecycle escape hatches such as initial sync, teardown cleanup, or interruption recovery

The API should stay geometry-oriented so widgets do not need to understand the internal timeline implementation.

## Timeline Design

### Expand timeline

The expand timeline has three geometry phases plus pulse.

1. **Reverse preload**
   - width and/or height move slightly opposite the final direction
   - easing should feel restrained and anticipatory
2. **Forward overshoot**
   - geometry accelerates past the final expanded target
   - this is the strongest motion beat
3. **Settle**
   - geometry returns to the exact expanded target
   - motion should end cleanly without wobble
4. **Pulse**
   - highlight flash begins with the forward beat
   - fade-out can overlap the settle phase

### Collapse timeline

The collapse timeline mirrors the same logic.

1. **Reverse preload**
   - geometry expands slightly before shrinking
2. **Forward overshoot**
   - geometry contracts smaller than the stable collapsed target
3. **Settle**
   - geometry returns to the exact collapsed target

This keeps expansion and collapse feeling like two halves of one motion system instead of unrelated effects.

## Per-Widget Application

### `SuperIslandWidget.qml`

This is the first migration target because it already contains the most expressive geometry behavior and will validate the abstraction under the hardest conditions.

Migration intent:

- keep the existing transient and hint state machine
- keep dual-track content choreography between pill and flash areas
- replace ad-hoc width, height, and pulse choreography with the shared transition layer where possible
- ensure width and height begin together during restore and collapse

The shared transition layer should drive:

- pill background height expansion and collapse
- pill width expansion and restore timing
- unified pulse timing for the pill surface

The widget should still own:

- flash-track content motion
- transient content replacement sequencing
- baseline and flash event handoff

### `WorkspaceWidget.qml`

This widget is mostly horizontal and should use the same motion grammar with lower vertical emphasis.

Migration intent:

- unify the horizontal morph between focus and overview states
- allow a lighter overshoot than `SuperIsland`
- optionally keep height fixed while still using pulse and width overshoot

This is an example of global style with local axis bias.

### `SuperSystemMonitorWidget.qml`

This widget is deferred from the first migration wave. It should adopt the same brand motion in a later pass when it expands into a richer state, but it likely needs the most restrained amplitude.

Migration intent:

- reuse the same transition layer
- keep metric content stable and readable during motion
- use a softer pulse so warning semantics are not visually confused with attention flash

## Settings Panel Design

Add a small global motion section to the widget settings experience.

Integration point:

- add a new shared motion section under the existing functional group in `modules/bar/WidgetSettingsPanel.qml`
- because this motion is global, the section should be shown as a cross-widget block instead of being hidden behind a single widget-specific loader
- widget-specific sections such as `WorkspaceWidgetSection.qml`, `SuperIslandSection.qml`, and `MediaControlSection.qml` remain focused on business behavior, while the new motion section represents shared visual behavior

Suggested controls:

- preset selector: `Soft`, `Balanced`, `Snappy`
- intensity slider
- speed slider
- pulse toggle

The panel should explain these controls in product language instead of animation jargon.

For example:

- intensity = how dramatic the bounce feels
- speed = how quickly dynamic widgets complete the motion
- pulse = whether dynamic widgets flash during expansion beats

Component-specific overrides should stay code-level for now. Do not add per-widget motion controls in the first pass.

## Migration Strategy

Perform migration in this order:

1. `SuperIslandWidget.qml`
2. `WorkspaceWidget.qml`
3. defer `SuperSystemMonitorWidget.qml` to a later wave

Reasons:

- `SuperIsland` is the most demanding case and will prove the abstraction
- `WorkspaceWidget` validates the mostly-horizontal use case
- `SuperSystemMonitorWidget` remains a follow-up target so the first wave stays scoped to the two widgets already migrated in this worktree

Hard rule during migration:

- do not change service ownership or event semantics
- do not rewrite business state machines just to fit the new transition layer
- only replace local geometry and pulse orchestration where the behavior overlaps the shared motion contract

## Verification Strategy

### 1. Shared-layer verification

Add a minimal QML harness for the shared transition layer.

Suggested location:

- `tests/qml/bar/BarExpandTransitionHarness.qml`

If the repository still lacks a committed harness runner at implementation time, the first implementation task should formalize one under `tests/` before later tasks rely on the harness.

The harness should verify:

- expand performs reverse preload before forward growth
- expand overshoots beyond the final target before settling
- collapse performs reverse preload before forward shrink
- collapse undershoots below the stable collapsed size before settling
- pulse starts during the forward beat when enabled

### 2. Widget integration verification

For each migrated widget, verify:

- the shell still loads with `timeout 5 qs --path .`
- width and height remain synchronized where both axes are animated
- content remains readable during motion
- the widget still returns to exact stable geometry after animation

### 3. Regression focus

Special regression watchpoints:

- `SuperIsland` restore timing and flash/pill coordination
- `WorkspaceWidget` feeling too vertically elastic
- pulse collisions with existing highlight layers
- wrapper-level or panel-level animation double-driving widget geometry

## Risks and Controls

### Risk: duplicated ownership of geometry

If a widget and the shared transition layer both animate width or height, motion will drift or stutter.

Control:

- move geometry ownership fully into the shared transition layer for each adopted axis
- keep widget-side bindings declarative and direct

### Risk: over-generalized API

If the shared component tries to understand widget-specific states, it will become another business layer.

Control:

- keep the API geometry-first and state-agnostic
- pass targets in, receive animated values out

### Risk: visual sameness instead of family resemblance

If all widgets use the exact same amplitude on every axis, the system will feel heavy and artificial.

Control:

- support axis bias and restrained local overrides
- unify motion grammar, not identical geometry magnitudes

## Recommended Implementation Direction

Build a single reusable expansion transition component for bar widgets, drive it from shared theme tokens plus a small global settings section, and migrate widgets one by one starting with `SuperIslandWidget.qml`.

This gives the product one recognizable motion accent without forcing all widgets into the same structure or state model.
