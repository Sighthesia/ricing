---
name: qml-motion-debug
description: Use when debugging Quickshell or QML motion bugs where state updates occur but the visual transition looks static, too subtle, or wrong.
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

### 9. Decorative Bridge Outlives Panel Body
- If attached bridge geometry is computed from the same live path as the panel body, the bridge can survive a few frames after the body is too small to justify it.
- Common symptom: during collapse tail, both bottom-side bridge shoulders become hairline arcs or tiny floating shards attached to the pill.
- Inspect `panelTop`, `panelBottom`, available corner height, and visible panel height together. The bug is usually geometric, not opacity-related.
- Prefer retiring the bridge for the final tail of collapse using a host-owned threshold on reveal progress or visible panel height.
- Do not try to solve this only by shrinking `cutRadius`; that usually makes the artifact smaller, not cleaner.

### 10. Zero-Duration Animations Can Still Keep Incremental Diff Side Effects
- Do not assume setting list animation durations to `0` disables the whole motion system.
- If the owner still runs incremental `move` / `insert` / `remove` sync, clear-query or broadening-search paths can still leave visible residual overlap even when no animation is perceptible.
- Common symptom: after disabling launcher row animations, narrowing search looks static as expected but clearing the keyword still shows residual rows or stale overlap for one frame.
- Treat this as a state/update-path bug first: disable the incremental branch together with the row animations, or fall back to a full replace while animations are intentionally off.

### 11. Repeated `stop()+start()` Anchor Retargets Cause Tiny Shakes
- If a rapidly updated anchor uses imperative `stop()` + reset `from/to` + `start()` on every snapshot, the visual can keep replaying only the easing front edge and appear to vibrate in place.
- Common symptom: during continuous next/previous navigation, the capsule barely advances, keeps shaking near its old position, then surges toward the final target only after input stops.
- Prefer a root-owned animated property with `Behavior`, so each update retargets from the currently rendered value instead of restarting the whole run.
- If the UI still needs a post-animation settle/compact pass, keep a separate target property and only settle once the animated value is actually close to that target; do not trust a nominal timer duration alone.

### 12. Dynamic Insets Must Follow Live Visible Geometry
- If a title row or sibling lane needs extra clearance during rapid repeated transitions, do not derive that inset only from the target anchor or nominal final layout.
- Common symptom: one fix removes overlap during slow transitions, but rapid repeated navigation still shows retiring capsules crossing into the next lane, while a broader inset causes early clipping, large blank gaps, or abrupt height jumps.
- In DymicShell `window-hint`, compute clearance from the live stage slots that are still visually near the boundary, not from all retiring slots and not from anchor offset alone.
- Clamp the sampling window to the relevant boundary neighborhood; otherwise far-off retiring capsules can reserve space long after they stopped being a real overlap risk.

### 13. Content-Pushed Height Growth Should Not Wait For Retarget Animation
- If an attached or detached panel grows because inner content now needs more space, do not always route that growth through the same reveal retarget animation used for open/close choreography.
- Common symptom: the inner layout computes the larger height correctly, but the shell expands a beat later, so the user sees delayed clearance instead of content visibly pushing the shell open in real time.
- In DymicShell detached `window-hint`, let height growth sync immediately to the measured target, while shrink-back can still animate for a cleaner settle.
- Check the host-owned reveal height retarget path before touching child layout math; the bug is often in the shell wrapper, not in the content item.

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

### Pattern G: Reuse a View List Without Whole-List Motion
Use when a launcher, clipboard list, or similar `ListView` looks correct on first open but later swaps collapse into a single batch motion or a blank pause.

- snapshot retiring rows into a detached outgoing layer before clearing the backing model
- reset the reused view's scroll position and layout before starting the next stagger
- let incoming rows stagger from their own visible-order slots instead of from a one-shot batch owner flag
- if later swaps look more synchronized than the first swap, suspect stale `contentY` / `viewportOrder` rather than easing

### Pattern H: First Open Must Use One Entrance Path
Use when a paged list is correct after the first reveal but flashes, double-enters, or comes up blank on the very first activation.

- choose one owner for the first reveal, usually the page-level activation callback
- keep late `countChanged` or model-refresh handlers from replaying enter while the first reveal is still pending
- if delegates can instantiate before the page is active, keep them in the managed hidden state until the page releases them
- when logs show two visible counts during the same open, verify whether the page activated twice or whether the list simply finished populating after the first stagger started

### Pattern I: Page-Level Reveal Contract
Use when a paged list or deck needs a stable first-open reveal across repeated opens and data churn.

- page activation owns the first reveal window
- delegates may instantiate early, but they stay hidden until the page releases the reveal
- model refreshes may update state during the pending window, but they must not start a second enter path
- once the first reveal completes, later refreshes may re-enter only if the page is still visible and the refresh is not part of the same activation sequence

### Pattern J: Hidden Preview Must Reuse Replace Feedback
Use when a hidden or background preview swaps beneath a `window-hint` or attached overlay.

- do not assign the preview event directly into the steady-state display item if the visible surface is still on screen
- route preview swaps through the same outgoing/incoming replace layers as foreground transient replacement
- trigger the shared background pulse and scale spring for preview swaps too, otherwise the text changes but the whole panel feels static
- let preview events expire while hint or overlay pauses the foreground timer, or the final notification will linger until the owner closes
- keep cached collapse width only for the real collapse tail; do not let an old width snapshot hold the live pill wide throughout the whole hint or overlay session

### Pattern K: Disable Diff Path With Motion Toggle
Use when a repeated list is being temporarily refactored with animations disabled.

- gate the owner-level incremental sync branch on the same animation flag as the delegates
- if row motion is off, prefer full replacement over `move` / `insert` / `remove` churn
- in launcher search, this gate belongs in `modules/launcher/LauncherCore.qml`, not only in `modules/launcher/LauncherResultsList.qml`
- otherwise the UI can still show clear-filter residue even though the outgoing layer and delegate animations are disabled

### Pattern L: WinBoat-Style Filter Motion In QML ListView
Use when a launcher, clipboard list, or similar `ListView` should match WinBoat-style search filtering where surviving rows move up, removed rows retire, and first/clear search changes still feel continuous.

- Treat `src/renderer/views/Apps.vue` in WinBoat as the visual target, not as a literal implementation recipe; Vue `TransitionGroup` keeps the whole list live, but QML `ListView` virtualizes delegates and can drop them during big diff churn.
- In DymicShell, split the problem into three paths inside `modules/launcher/LauncherCore.qml`: high-overlap refine goes `incremental`, first narrowing or clear/reset can go `softReplace`, provider switches may stay `fullReplace`.
- Only allow launcher `incremental` motion when some currently visible retained rows still belong to the next top visible window; if retained rows survive only far below the fold, `ListView` can look blank or mis-animate even though the data diff is correct.
- Reuse detached layers in `modules/launcher/LauncherResultsList.qml` for both outgoing and incoming content when `ListView` virtualization makes a direct live diff unreliable.
- Keep the motion language consistent with WinBoat: removed rows, inserted rows, retained-row enters, and soft-replace incoming rows should all share the same diagonal fade-and-slide family instead of mixing vertical-only and horizontal-only paths.

### Pattern M: High-Frequency Query Changes Need Graceful Interruption
Use when rapid text input keeps restarting launcher or clipboard result motion before the previous transition finishes.

- Do not solve this only by delaying refresh; deferred refresh can leave stale results visible, then make them disappear in one batch after the user finishes typing.
- Do not simply disable row animation during fast typing if the goal is visual continuity; that fixes churn but removes the filtering feedback entirely.
- When a new query arrives while a soft-replace incoming layer is still active, promote that incoming layer into an outgoing fade instead of clearing it immediately.
- Clear older outgoing generations before promoting the newest interrupted incoming layer, otherwise multiple stale snapshot generations can stack visually.
- In launcher search, this handoff belongs in `modules/launcher/LauncherResultsList.qml` near `beginFilterTransition()`, `beginSoftReplace()`, and `runSwapExit()`.
- Prefer: newest interrupted layer fades out in place, newest query starts its own transition, and only one interrupted snapshot generation survives at a time.

## DymicShell-Specific Notes

- Check `services/WindowHintService.qml` first for live hint snapshots.
- Check `modules/bar/widgets/SuperIslandWidget.qml` second for event propagation and loader behavior.
- Check `modules/bar/superisland/*` last for real geometry ownership.
- For hint-like transitions, prefer explicit timeline control over `Qt.callLater()` pulses.
- For `window-hint` style previews, verify that repeated `activeHint` refreshes do not cancel a just-started slot motion.
- For `window-hint` capsule lanes, prefer root-owned anchor retarget with `Behavior` over imperative `NumberAnimation.stop()/start()` when held-state updates can arrive several times within one `moveDuration`.
- For `window-hint` vertical clearance between workspace capsules and the title lane, derive bottom inset from the current `host._workspaceStageSlots` geometry near the lower boundary. Avoid using only `_workspaceSingleSideOffset`, and ignore slots beyond the overflow neighborhood so fast retirements do not create oversized blank space or height pops.
- For detached `window-hint` height changes, inspect `modules/bar/widgets/SuperIslandWidget.qml` `_retargetAttachedPanelHeightIfNeeded()` before tuning card spacing. If the card's `implicitHeight` is correct but shell growth lags, make growth immediate and reserve animation for shrink or explicit open/close choreography.
- For `window-hint` to overlay handoff, compare `IslandOverlayService.mode` and `IslandOverlayService.state` separately before deciding a delayed pulse is still valid.
- For mixed-width capsule lanes, verify the stage wrapper is centered independently from sibling lanes.
- For `window-hint` previews, if the UI becomes blank only during rapid source churn, keep the last visible snapshot until a real close event rather than publishing an empty intermediate snapshot.
- For `window-hint` or overlay-owned preview swaps, route `hiddenPreviewEvent` through replace layers and pulse/spring feedback instead of mutating `_mainDisplayEvent` directly.
- For `window-hint` or overlay sessions, let hidden preview expiry continue even while foreground timers are paused, or the last notification will outlive the surface owner.
- For attached hint close, use cached collapse width only during the actual collapse path; stale width snapshots can cause wide-pill hold or close-time width flash.
- For `window-hint` collapse, verify that `_hintExitAnim` does not reset phase or clear attached content before `_attachedCollapseAnim` finishes.
- For `window-hint` title-overlap fixes, inspect `modules/bar/superisland/IslandWindowHintMotion.js` `workspaceBottomInset()` together with `modules/bar/superisland/IslandWindowHintCard.qml` `_workspaceBaseVisibleStageHeight` / `_workspaceVisibleStageHeight` before changing row gap or trim durations.
- For attached shell collapse, verify that bridge shoulders disappear before visible height falls into the seam-sized range.
- For launcher and clipboard result swaps, if the first open staggers correctly but later swaps drift into whole-list motion, reset the reused `ListView` state before re-entering and verify the outgoing snapshot layer is still retiring independently.
- For launcher search clear-filter bugs, inspect `insertedCount` / `removedCount` before assuming stale outgoing snapshots. A clear from filtered to full results often shows `inserted > 0` and `removed == 0`, which means the overlap comes from insertion churn, not retiring rows.
- When launcher list animations are intentionally disabled, keep `modules/launcher/LauncherCore.qml` and `modules/launcher/LauncherResultsList.qml` on the same feature flag so incremental diff logic does not outlive the motion layer.
- For launcher search paths, separate narrowing and broadening in `modules/launcher/LauncherCore.qml`; a single symmetric `startsWith` refinement check makes it much harder to decide when `incremental` is actually safe.
- For launcher search `incremental`, inspect both `retainedVisibleCount` and whether those retained visible rows still belong to the next top visible window; a retained row that survives only at index `46` does not make top-window incremental motion safe.
- For launcher search `softReplace`, keep incoming and outgoing snapshot layers independent from the live `ListView`, and hide the live list until the snapshot handoff finishes.
- For rapid launcher search updates, do not hard-clear `_incomingItems` during a new filter pass. Promote the interrupted incoming generation into `_outgoingItems`, but clear older outgoing generations first so only the latest interrupted layer remains visible.
- When one repeated list feels faster than a sibling list with the same visual role, compare the shared base delay, step cadence, travel distance, and exit window before changing easing.

## Visual Language Reference

The shared design language and cross-component consistency rules live in `qml-visual-language`.

- Load `qml-visual-language` when a fix or feature needs visual-system decisions.
- Keep this skill focused on diagnosing broken motion, race conditions, ownership conflicts, and handoff timing.
- If a motion bug is actually a design-language mismatch, treat that as a separate concern and follow the visual-language skill.

## Validation

- Run `timeout 5 qs --path .`
- Reproduce the motion change while the shell is live.
- If needed, compare logs from service, host, and leaf in one reproduction pass.
