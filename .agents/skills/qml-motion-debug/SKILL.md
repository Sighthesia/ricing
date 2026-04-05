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

### 4. Follow-Up Snapshot Cancels Live Motion
- If a service emits multiple snapshots for one user action, do not let a later neutral snapshot immediately clear an animation that just started.
- Common symptom: the first diff computes a non-zero direction, but a second refresh computes `0` and clears the outgoing/incoming layers before the user sees any motion.
- Prefer letting the active timeline finish, or coalesce service refreshes before deciding to cancel motion.

### 5. Empty Snapshot Should Not Replace Visible Content
- If the service can produce transient empty or partially-empty snapshots, do not publish them over the last visible frame unless the UI is truly closing.
- When a hold-style preview is active, keep the last visible snapshot alive and treat the empty snapshot as a no-op until release.
- This prevents high-frequency source updates from turning a live preview into a blank panel.

### 6. Positioner Width Hides Real Alignment
- `Column`, `Row`, and other positioners size themselves from the widest child.
- A narrower stage inside that positioner can appear left-aligned even when its own internal items are centered.
- When one animated lane is narrower than its siblings, wrap it in a full-width container and center the real stage inside the wrapper.

### 7. Mode Changes Before State Settles
- Do not assume `state === opening/open` is the earliest reliable signal that an overlay handoff has started.
- In DymicShell overlay flows, `mode !== none` can become true one step earlier than the final session state.
- If a delayed hint pulse or flash timer should not survive overlay takeover, cancel it as soon as the mode becomes active, not only after the session is fully open.
- Keep the suppression narrow: stop the stale delayed pulse, but do not also suppress legitimate live-update pulse or spring feedback for the underlying hint interaction.

### 8. Early Cleanup Beats Slow Collapse
- If one timeline clears `visible`, opacity, or phase before the geometry collapse finishes, the user will perceive a disappearance instead of a shrink-back.
- Common symptom: the panel starts collapsing correctly, reaches a medium size, then seems to turn transparent before arriving at the bar.
- Compare all exit durations involved. In DymicShell, a quick `highlightDuration` helper can finish well before a `moveDuration` or `springDuration` host collapse.
- For detached `window-hint` flows, treat host collapse as the source of truth and defer final cleanup until that collapse animation finishes.
- If needed, extract final reset into one helper such as `_completeWindowHintExit()` and call it only from the owning collapse timeline.

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
- whether a follow-up snapshot cleared the animation
- parent stage width versus animated child width
- overlay `mode` versus overlay `state`
- which animation actually performs final cleanup
- duration mismatch between helper fade and host collapse

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

### Pattern D: Ignore Neutral Refresh While Motion Runs
Use when one interaction causes multiple service refreshes.

- start motion from the first meaningful diff
- if a later refresh computes no direction, do not immediately clear the active motion
- update the steady-state snapshot, but let the current timeline finish unless the data truly invalidates it

### Pattern E: Center a Narrow Animated Stage Explicitly
Use when a stage lives inside a wider `Column` or `Row`.

```qml
Column {
    width: Math.max(workspaceStageWidth, titleStageWidth)

    Item {
        width: parent.width

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: workspaceStageWidth
            height: parent.height
        }
    }
}
```

### Pattern F: Cancel Delayed Pulse On Early Overlay Handoff
Use when an overlay opens while a hold preview still has delayed emphasis pending.

- detect the earliest overlay handoff signal, often `mode !== none`
- cancel only the delayed timer or pending pulse flag tied to the old surface
- keep steady-state hint replacement feedback enabled for real content changes
- avoid broad guards that remove all pulse or spring feedback from the hint itself

## DymicShell-Specific Notes

- Check `services/WindowHintService.qml` first for live hint snapshots.
- Check `modules/bar/widgets/SuperIslandWidget.qml` second for event propagation and loader behavior.
- Check `modules/bar/superisland/*` last for real geometry ownership.
- For hint-like transitions, prefer explicit timeline control over `Qt.callLater()` pulses.
- For `window-hint` style previews, verify that repeated `activeHint` refreshes do not cancel a just-started slot motion.
- For `window-hint` to overlay handoff, compare `IslandOverlayService.mode` and `IslandOverlayService.state` separately before deciding a delayed pulse is still valid.
- For mixed-width capsule lanes, verify the stage wrapper is centered independently from sibling lanes.
- For `window-hint` previews, if the UI becomes blank only during rapid source churn, keep the last visible snapshot until a real close event rather than publishing an empty intermediate snapshot.
- For `window-hint` collapse, verify that `_hintExitAnim` does not reset phase or clear attached content before `_attachedCollapseAnim` finishes.

## Visual Language Reference

The shared design language and cross-component consistency rules live in `qml-visual-language`.

- Load `qml-visual-language` when a fix or feature needs visual-system decisions.
- Keep this skill focused on diagnosing broken motion, race conditions, ownership conflicts, and handoff timing.
- If a motion bug is actually a design-language mismatch, treat that as a separate concern and follow the visual-language skill.

## Validation

- Run `timeout 5 qs --path .`
- Reproduce the motion change while the shell is live.
- If needed, compare logs from service, host, and leaf in one reproduction pass.
