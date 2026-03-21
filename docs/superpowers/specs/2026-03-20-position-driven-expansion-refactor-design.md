# Position-Driven Expansion Refactor Design

**Date:** 2026-03-20  
**Status:** Proposed

## Goal

Make layout-driven expansion a first-class pattern for components that live inside a normal layout tree and should push their siblings by changing one final extent.

The refactor removes the fragile pattern where container size, reveal content, and state transitions are all owned by different animated sub-elements.

## Related Work

This design complements `docs/superpowers/specs/2026-03-19-dynamic-bar-expansion-design.md`.

That spec keeps shared bar motion in a bar-local transition layer. This refactor adds a separate layout-native expansion contract for components whose natural behavior is: grow the container, let layout push neighbors, keep child content mostly static in its final positions.

## Problem

Expandable UI in this repo falls into three motion families:

1. layout-native sections that reveal more content inside the same stack
2. bar widgets that own their own geometry and staged choreography
3. panels and overlays that must preserve surface/window lifecycle

Problems start when those families are mixed. The common failure mode is one axis of size being owned by the container while child elements also animate that same axis, which creates timing coupling, state resets, and rapid-toggle bugs.

The project needs a clear rule for when a component should be driven by parent layout push-down versus when it should keep an internal state machine or a surface transform.

## Decision

Introduce a dedicated layout-native expansion contract for components that can predefine their final content positions and let sibling reflow create the push-down effect.

Keep the existing contracts:

- `AnimatedPanelBase.qml` for panels and overlays
- `BarExpandTransition.qml` for bar widgets with bar-specific choreography

This is not one animation system for everything. It is one motion contract per geometry ownership model.

## Motion Contracts

### 1. Layout-Native Expansion

Use a position-driven expander when all of the following are true:

- the component lives inside the normal layout tree
- siblings should be pushed by the component's final extent change
- the expanded content can be laid out in its final positions up front
- the component only needs one main axis to change
- the component does not own a window or surface lifecycle

This is the contract the user described: predefine the content positions, reserve an internal exclusive region, and let the container boundary move while the child content stays conceptually fixed.

### 2. Bar-Local Geometry Transition

Use `BarExpandTransition.qml` when the widget is part of the bar and needs bar-specific motion such as overshoot, pulse, flash extension, or multi-stage restore/collapse sequencing.

This is geometry-driven, but not layout push-down. The widget owns its final size and can coordinate extra bar-local tracks.

### 3. Surface-Level Panel Transition

Use `AnimatedPanelBase.qml` when opening and closing a window or panel surface.

These components must preserve Wayland surface stability and should continue to rely on state machines and transform-based presentation instead of container resize animation.

## New Primitive

### `modules/layout/PositionDrivenExpander.qml`

Proposed responsibility:

- own one animated extent value on a single axis
- derive collapsed and expanded extents from two realized measurement items supplied by the caller
- publish the adopted axis through the item's normal layout hint (`implicitHeight` in vertical mode, `implicitWidth` in horizontal mode)
- clip overflow so child content can be laid out at its final positions from the beginning
- let the parent layout reflow neighbors naturally when the extent changes
- keep the caller's business state outside the primitive

Required caller inputs:

- one realized collapsed measurement item
- one realized expanded measurement item
- one boolean `expanded` state
- one axis choice (`Qt.Vertical` or `Qt.Horizontal`)

The measurement items are ordinary QML `Item`s owned by the caller. They may be hidden, clipped, or transparent, but they must stay instantiated for the full lifetime of the expander.

Suggested API shape:

```qml
Item {
    required property Item collapsedSource
    required property Item expandedSource
    required property bool expanded
    property int axis: Qt.Vertical
    property bool clipOverflow: true

    readonly property real collapsedExtent
    readonly property real expandedExtent
    readonly property real animatedExtent
    readonly property bool running
}
```

Implementation note for derived compatibility components:

- the primitive's public API remains `collapsedSource`, `expandedSource`, `expanded`, `axis`, and `clipOverflow`
- if a derived component must preserve a legacy local state fold such as `expanded || forceExpand`, the implementation may use one private bridge property internally
- that bridge must remain private and must not appear as a new public API on the primitive

Ownership table:

- `PositionDrivenExpander`: owns the adopted-axis extent and the `implicit*` value that drives layout
- owner layout parent: owns placement in the stack and consumes the expander's implicit size
- scroll ancestors: clip or scroll only; they never own the adopted axis in v1
- viewport shell: never owns size

Visible contract:

- vertical mode: `implicitHeight = animatedExtent`
- horizontal mode: `implicitWidth = animatedExtent`
- the orthogonal axis remains caller-owned
- the primitive does not animate `width` or `height` directly
- the primitive is the only animated size source on the adopted axis

Measurement source rules:

- `collapsedExtent` is sampled from `collapsedSource.implicitHeight` or `collapsedSource.implicitWidth`, depending on axis
- `expandedExtent` is sampled from `expandedSource.implicitHeight` or `expandedSource.implicitWidth`, depending on axis
- the source must be an instantiated QML `Item` that is already attached to the same scene graph
- `visible: false`, `opacity: 0`, and `clip: true` are allowed
- `null`, `undefined`, `Loader.item === null`, and detached objects are not allowed
- if a source is created by a `Loader`, the loader must already be active and `Loader.item` must already be assigned before sampling
- the primitive samples the bound implicit size directly; it does not walk the child tree itself
- if a source's implicit size changes, the matching extent binding updates immediately
- measurement validity is binary: either the source is realized and attached, or the expander is not eligible

Retarget rules:

- when `expanded`, `collapsedExtent`, or `expandedExtent` changes, the current animation is cancelled and a new one starts from the current `animatedExtent` toward the newest target
- direction changes always restart from the current extent
- every retarget uses the same duration and easing preset as the original direction
- there is no snap threshold and no queued transition
- if the new target equals the current `animatedExtent`, no animation restarts
- the only non-animated moment is the first binding sync when the component is created

Reference pseudocode:

```qml
function sampleExtent(node, axis) {
    return axis === Qt.Vertical ? node.implicitHeight : node.implicitWidth
}

PositionDrivenExpander {
    collapsedSource: collapsedNode
    expandedSource: expandedNode
    expanded: root.expanded
}
```

Canonical integration example:

```qml
ColumnLayout {
    PositionDrivenExpander {
        Layout.fillWidth: true
        expanded: root.open
        collapsedSource: header
        expandedSource: body
    }
}
```

## Layout Integration Rules

- the expander must be a direct child of its owner layout parent
- the owner layout parent is the item that consumes the expander's implicit size on the adopted axis
- `Layout.fillWidth` / `Layout.fillHeight` may be used only on the orthogonal axis
- the adopted axis must not use a separate animated `Layout.preferred*`, `Layout.minimum*`, `Layout.maximum*`, `width`, or `height` binding
- `Layout.minimum*` and `Layout.maximum*` on the adopted axis are allowed only as static clamps
- `Layout.preferred*` on the adopted axis is not allowed
- if both `collapsedExtent` and `expandedExtent` fit inside the same static clamp, the component is eligible on this rule
- if either extent exceeds the static clamp, the component is not eligible
- if a wrapper item sits between the expander and the owner layout parent, the component is not eligible
- supported scroll ancestors in v1 are passive only; they may clip or scroll, but they do not change the sizing authority
- `ListView` and `GridView` are not supported expansion hosts in v1
- if the expander is nested inside a virtualized delegate or cell host, the component is not eligible
- a same-axis clamp that would need to change during the motion is disallowed

Sizing and clipping ownership:

- `PositionDrivenExpander` owns `implicit*` on the adopted axis
- the owner layout parent owns placement and static clamp decisions
- scroll ancestors own clipping and scrolling only
- viewport shells never own size

Decision path:

1. Inspect the component's direct parent.
2. If the direct parent is not the owner layout parent, the component is not eligible.
3. If any wrapper item sits between the expander and the owner layout parent, the component is not eligible.
4. Scroll ancestors do not change ownership; they only clip or scroll.
5. Eligibility is decided only against the owner layout parent's static same-axis clamp or unconstrained size.

Examples:

- `ColumnLayout -> PositionDrivenExpander` => eligible
- `ScrollView -> contentItem -> ColumnLayout -> PositionDrivenExpander` => eligible
- `Flickable -> contentItem -> ColumnLayout -> PositionDrivenExpander` => eligible
- `ColumnLayout -> Wrapper -> PositionDrivenExpander` => not eligible
- `GridView -> delegate -> PositionDrivenExpander` => not eligible

## Eligibility Rules

### A component is eligible for position-driven expansion only if:

- its expanded geometry is measurable from realized content before the animation starts
- the expanded content can be pre-laid out in final positions
- the owner layout parent should absorb the size change
- the same axis is not already owned by several child animations
- it is not a panel/window surface transition
- it can live inside the same scrollable content tree if it is in a scroll container, but it must not be the thing resizing the viewport itself
- its adopted axis can be expressed entirely through implicit size, without a second layout owner on the same axis
- the caller can provide both measurement items as realized nodes for the full lifetime of the component

If the content changes while the component is already open, the same owner retargets to the new measured extent. That is still eligible; what is not allowed is a second child-owned axis animation taking over the resize.

### A component is not eligible if:

- it is a popup, panel, or other independent surface
- it depends on overlay behavior or compositor exclusion policy
- it uses multi-phase content handoff as part of the visual language
- it relies on independent child animations to communicate state
- it is a transient notification or flash-only surface
- it requires a wrapper item to bridge between the expander and the owner layout parent
- it depends on a virtualized view (`ListView`, `GridView`) as its sizing authority in v1

Mixed-motion boundary rule:

- if a component combines push-down layout with internal choreography, only the outer shell is eligible
- the inner choreography must not also own the same adopted axis
- if the content only becomes meaningful after the expansion starts, the component stays out of this refactor wave
- if scrollable overflow forces a viewport resize or surface resize, the component stays out of this refactor wave
- if any descendant also animates the adopted axis during the same motion, the component is not eligible unless that descendant is fully isolated from the size path and does not contribute to layout measurement

## Component Classification

### Layout-native target

This should migrate to the new position-driven contract first:

- `modules/bar/settings/ExpandableGroup.qml`

This component already expresses a normal stack reflow problem. It does not need a separate surface or bar-local choreography.

### Deferred layout-native candidate

This is a plausible follow-up candidate, but it is not part of this refactor wave:

- `modules/bar/settings/FontPickerSection.qml`

Its dropdown body, focus handling, and content-size changes need a separate pass before it can cleanly adopt the new contract.

### Excluded from this refactor

These should stay on their current motion model:

- `modules/bar/settings/SettingsSidebar.qml`

Its submenu motion already uses staggered child choreography and is not the clean push-down pattern this refactor targets.

### Bar-local targets

These should keep the existing bar-local motion contract:

- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/widgets/WorkspaceWidget.qml`
- `modules/bar/widgets/SystemTrayWidget.qml`
- `modules/bar/widgets/MediaControlWidget.qml`

These widgets have compound choreography, flash tracks, or bar-specific lifecycle coupling. They may share some layout rules with the new primitive, but they should not be forced into it.

### Surface-level targets

These should remain on `AnimatedPanelBase.qml` or the existing popup/window pattern:

- `modules/bar/SettingsPanelWindow.qml`
- `modules/bar/WidgetPickerWindow.qml`
- `modules/bar/WidgetSettingsPanel.qml`
- `modules/launcher/LauncherPanel.qml`
- `modules/bar/MediaControlPanel.qml`
- `modules/bar/NotificationHistoryPanel.qml`
- `modules/background/WallpaperPickerWindow.qml`

### Excluded from expansion refactor

These should remain transient or static and not be converted into expansion primitives:

- `modules/notifications/NotificationPopupWindow.qml`
- `modules/notifications/NotificationCard.qml`
- `modules/bar/ContextMenuBackdrop.qml`
- `modules/bar/BarContextMenu.qml`
- `modules/bar/tray/TrayFlashRow.qml`
- `modules/bar/tray/TrayIconButton.qml`
- `modules/bar/widgets/NotificationBell.qml`
- `modules/bar/superisland/IslandNotificationCard.qml`
- `modules/bar/superisland/IslandWorkspaceCard.qml`
- `modules/bar/BarWidgetWrapper.qml`
- `modules/bar/BarSection.qml`

`modules/bar/superisland/IslandMediaCard.qml` is a possible future candidate, but only if it becomes a truly layout-native size switch instead of a content-mode swap.

## Refactor Sequence

### Phase 1: Extract the new contract

- add `modules/layout/PositionDrivenExpander.qml`
- add a small harness under `tests/qml/layout/`
- validate that the expander changes only one extent and pushes siblings cleanly

### Phase 2: Convert the first layout-native section

- migrate `ExpandableGroup.qml`
- verify the new contract before touching any follow-up candidate

### Phase 3: Decide follow-up candidates separately

- evaluate `FontPickerSection.qml` in its own later wave
- do not pull `SettingsSidebar.qml` into this refactor unless its submenu structure is simplified first

### Phase 4: Preserve the bar-local contract boundary

- keep `BarExpandTransition.qml` as the bar motion owner
- do not attempt to replace its flash/pulse choreography with the layout expander
- explicitly annotate where its adopted axis ends and where child-only motion begins

### Phase 5: Keep panel and overlay surfaces untouched

- leave `AnimatedPanelBase.qml` users on their current surface model
- do not convert panel open/close into layout push-down
- do not convert overlay or notification surfaces into expandable containers

## Rules for Child Animation

When a component is migrated to the position-driven contract:

- the adopted axis must have only one geometry owner
- the container may animate extent, but child items must not also animate that same extent
- child motion is allowed only on orthogonal properties such as opacity, color, rotation, or highlight
- the final positions should be declared up front, not computed by a chain of child animations

This is the main simplification goal. It prevents the container from fighting with its own content.

## Risks

- If a migrated component still animates child height or width on the same axis, the complexity returns immediately.
- If the component hides children too early, the push-down effect becomes a jump instead of a transition.
- If expanded content depends on async data, the final geometry may not be knowable up front and the component should stay on a surface-level contract.
- If a component needs multiple visual phases to tell the user what is happening, it is usually not a good fit for the new primitive.

## Validation

### Automated

- add a QML harness for the new expander
- verify sibling reflow happens from a single animated extent
- verify rapid toggle retargeting does not leave stale axis ownership behind
- verify filter/search changes while expanded remeasure cleanly instead of jumping
- verify clipped or scrollable parents keep overflow contained when expanded content exceeds the viewport
- run `timeout 5 qs --path .`

### Manual

- expand and collapse `ExpandableGroup.qml` repeatedly
- verify that neighboring sections move smoothly without their own axis animations
- verify the new contract behaves predictably inside a scrollable settings page
- verify that surface-level panels still open and close exactly as before
- verify that bar widgets retain their existing visual identity

## Non-Goals

- do not replace all UI animation with a single helper
- do not convert panels, popups, or notifications into layout push-down components
- do not remove `AnimatedPanelBase.qml`
- do not remove `BarExpandTransition.qml`
- do not add per-widget motion settings for this refactor

## Outcome

After this refactor, the codebase should have three explicit expandable geometry models:

1. position-driven expansion for layout-native sections
2. bar-local transition for dynamic bar widgets
3. surface-level panel transition for windows and overlays

That separation makes the layout behavior predictable and keeps each expandable component in the cheapest motion model that still fits its job.
