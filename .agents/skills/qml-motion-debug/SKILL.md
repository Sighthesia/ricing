---
name: qml-motion-debug
description: Debug Quickshell or QML motion bugs when state updates happen but the visual transition looks static, too subtle, or wrong. Use for issues involving anchors, x/y offsets, Behavior conflicts, same-frame resets, or service-to-widget animation handoff.
---

# QML Motion Debug

Use this skill when animation state changes are correct but the user still does not see the intended motion.

## Primary Failure Modes

### 1. Split Geometry Ownership
- Do not mix `anchors.*` geometry with manual `x` / `y` animation on the same item.
- If an item must move, give it explicit `width`, `height`, `x`, and `y` ownership.
- If an item must stretch with anchors, animate a child wrapper instead of the anchored root.

### 2. Double Animation Ownership
- Do not stack `Behavior on x/y/scale/opacity` and imperative `NumberAnimation` / `ParallelAnimation` on the same property unless the ownership is deliberate.
- Prefer one owner per animated property.
- If motion feels like a faint ghost or residue, suspect competing animation systems first.

### 3. Same-Frame Reset
- Do not use `Qt.callLater()` to create visible motion when the intermediate state must survive across frames.
- If the animation depends on users seeing a start pose, use `ParallelAnimation` or `SequentialAnimation`.
- A property set to start state and reset in the same update path often collapses into an instant content swap.

## Debugging Ladder

Work from outermost cause to innermost rendering node.

1. **State layer**
   - Confirm the service emits a new snapshot.
   - Log IDs, indices, revisions, and directional context.
   - Example: focused window ID, workspace ID, previous/next IDs.

2. **Host layer**
   - Confirm the parent widget receives the update.
   - Check whether it replaces the subtree, updates a loader, or swaps event objects.
   - Verify the animated component instance is not being recreated unexpectedly.

3. **Leaf layer**
   - Confirm the actual visual item owns the property being animated.
   - Check `x`, `y`, `scale`, `opacity`, `width`, `height`, and `clip` boundaries.
   - If the property changes in logs but not on screen, inspect anchors and competing bindings.

Do not tune duration or easing before all three layers are verified.

## Logging Pattern

Use temporary logs in three places at once:

- service snapshot refresh
- host event/update handler
- leaf animation trigger

Good log fields:

- `revision`
- `workspaceId`
- `currentWindowId`
- `currentIndex`
- `direction`
- current phase / loader state
- travel distance for the animated property

Remove all temporary logs before finishing.

## Motion Checklist

Before shipping a motion fix:

- [ ] The service update is visible in logs.
- [ ] The host widget receives the new event without replacing the wrong subtree.
- [ ] Each animated property has exactly one owner.
- [ ] No animated property is both anchor-controlled and manually offset.
- [ ] Intermediate animation states survive across frames.
- [ ] `timeout 5 qs --path .` still passes.

## Recommended Fix Patterns

### Pattern A: Animate a Child Wrapper
Use when the visible item must stay anchored.

```qml
Item {
    anchors.fill: parent

    Item {
        width: parent.width
        height: parent.height
        x: animatedOffset
        scale: animatedScale
    }
}
```

### Pattern B: Use Explicit Timeline
Use when entry and exit states must be perceptible.

```qml
ParallelAnimation {
    NumberAnimation { target: root; property: "_entryOffset"; to: 0 }
    NumberAnimation { target: root; property: "_entryScale"; to: 1 }
    NumberAnimation { target: root; property: "_entryOpacity"; to: 1 }
}
```

### Pattern C: Keep Outgoing and Incoming Layers Separate
Use when the old focus must visibly leave while the new focus arrives.

- snapshot outgoing content
- render incoming content in a separate layer
- animate both layers independently
- clear the outgoing layer on animation finish

## DymicShell-Specific Notes

- Check `services/WindowHintService.qml` first for live hint snapshots.
- Check `modules/bar/widgets/SuperIslandWidget.qml` second for event propagation and loader behavior.
- Check `modules/bar/superisland/*` last for real geometry ownership.
- For hint-like transitions, prefer explicit timeline control over `Qt.callLater()` pulses.

## Validation

- Run `timeout 5 qs --path .`
- Reproduce the motion change while the shell is live.
- If needed, compare logs from service, host, and leaf in one reproduction pass.
