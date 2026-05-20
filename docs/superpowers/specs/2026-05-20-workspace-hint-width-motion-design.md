# Workspace Hint Width Motion Design

## Goal

Reduce the abrupt width entrance and exit feel of the focused workspace capsule while preserving the existing y-axis entrance, switch, and exit motion that already feels correct.

## Scope

This design changes only the width and content reveal motion of focused workspace capsules inside the workspace hint overlay.

In scope:

- Focused capsule width entrance behavior
- Focused capsule width exit behavior
- Outgoing focused capsule handoff width behavior
- Title-row reveal timing inside the focused capsule
- Pure Qt helper tests for the new width-motion math

Out of scope:

- Y-axis motion
- Viewport step queue semantics
- Release hide timing
- Workspace data/service contracts
- Opacity model changes unrelated to width reveal timing

## Constraints

- Do not change the current y-axis entrance/exit animation behavior.
- Do not change `WorkspaceHintViewportState.qml`.
- Do not change `WindowHintService.qml`.
- Do not add a new state machine, timer, or replacement visual instance.
- Keep the existing outgoing focused capsule content handoff behavior.
- Keep all motion continuous and avoid new hard cuts.

## Problem

The focused workspace capsule currently reads as too abrupt in width motion.

The main reason is that width and content visibility are effectively perceived as one event:

- the capsule shell expands toward focused width
- the title-card content becomes available at nearly the same time

This makes the object feel like it suddenly snaps open, even when the underlying continuous values are technically animated.

## Selected Approach

Use a two-stage width motion model while leaving the y-axis motion chain untouched.

Stage 1: shell-first expansion

- The capsule shell grows early from neighbor width toward a stable focused-shell width.
- This gives the object a readable physical body before the full title row is revealed.

Stage 2: content reveal

- The title-row reveal expands more slowly and slightly later than the shell.
- This makes the focused capsule feel like one persistent object opening up rather than a width snap.

Exit uses the reverse ordering:

- The title-row reveal retracts first.
- The shell width returns to neighbor width after that.

## Rejected Alternatives

### Single non-linear width curve

This would be the smallest change, but it only softens the overall width interpolation. It does not create a clear shell-first, content-second feel, so it is unlikely to remove the abruptness enough.

### Content-first, shell-following motion

This risks making the content feel detached from the capsule body. The object continuity is weaker than the shell-first approach and is more likely to look laggy.

## Architecture

### Unchanged motion chain

The following remain unchanged:

- `relativeOffset`
- `focusProgressForOffset()` as the base continuous focus metric
- capsule `y`
- `Behavior on y`
- viewport queue stepping
- release hide timer behavior
- `expanded` release semantics introduced by the current fix

### New width-motion layers

Two derived progress values will be introduced in `WorkspaceHintViewportModel.js`:

- `shellWidthProgressForOffset(relativeOffset)`
- `contentRevealProgressForOffset(relativeOffset)`

Both are pure derived helpers based on the current continuous visual focus position. They do not introduce additional state.

### Responsibilities

`shellWidthProgressForOffset(relativeOffset)`:

- reaches visible growth earlier during entrance
- holds slightly longer during exit
- drives shell geometry so the capsule body becomes readable first

`contentRevealProgressForOffset(relativeOffset)`:

- starts later during entrance
- retracts earlier during exit
- drives the reveal width of the title-card row

## QML Integration

### Files expected to change

- `modules/workspace-hint/WorkspaceHintViewportModel.js`
- `modules/workspace-hint/WorkspaceHintCapsule.qml`
- optional minimal property wiring in `modules/workspace-hint/WorkspaceHintWindow.qml`

### Capsule-level properties

`WorkspaceHintCapsule.qml` will add two derived properties:

- `_shellWidthProgress`
- `_contentRevealProgress`

These values will be used separately rather than relying on a single width interpolation for both shell and content.

### Width composition

The capsule shell width will be driven by `_shellWidthProgress`.

The title-card region will be wrapped in a dedicated clipped reveal container whose width is driven by `_contentRevealProgress`.

This means:

- the capsule shell can become physically larger before the title row is fully revealed
- the title row can retract before the shell fully returns to neighbor width

### Content layout rule

The workspace number remains stable and readable as part of the capsule body.

Only the title-card region is progressively revealed/retracted. This avoids the perception that the entire focused identity of the capsule is being horizontally chopped.

## Handoff Compatibility

The current outgoing focused capsule handoff logic remains in place:

- `useFocusedGeometry`
- `_usesPreviousVisualContent`

The new width-motion layering must remain compatible with that behavior.

Expected result during focus handoff:

- the outgoing focused capsule keeps focused-shell qualification while it is still in the handoff zone
- its title reveal retracts earlier than its shell width
- the incoming focused capsule establishes shell presence before fully opening its title reveal

## Visual Timing Intent

The exact numeric curve can be tuned during implementation, but the intended shape is:

- shell width begins early and feels stable quickly
- content reveal begins after shell establishment
- content reveal closes before shell fully collapses on exit

The resulting perception should be:

- enter: body first, content second
- exit: content first, body second

## Testing Strategy

Add pure Qt tests in `tests/qml/tst_workspace_hint.qml` for:

- shell progress clamps to `0..1`
- content progress clamps to `0..1`
- shell progress is ahead of content progress around partial-focus offsets
- outgoing focus geometry remains eligible during handoff
- release collapse semantics remain intact

Do not add Quickshell-dependent tests for this change.

## Verification

Implementation is complete only when all of the following are true:

- focused capsule width no longer feels like a sudden full-width snap
- the current y-axis motion feel remains unchanged
- outgoing focused capsule still shrinks out smoothly
- multi-step workspace switching still animates continuously
- `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_workspace_hint.qml -o -,txt -v1` passes
- `qmllint modules/workspace-hint/WorkspaceHintWindow.qml modules/workspace-hint/WorkspaceHintCapsule.qml modules/workspace-hint/WorkspaceHintViewportState.qml` passes

## Risks

### Over-coupling shell and content again

If shell width and content reveal still share one effective progress curve, the abruptness will remain. The implementation must keep them independently derived.

### Hard clip feel on the title row

If the reveal container is too mechanically clipped, the title row may look sliced rather than progressively revealed. The reveal width and existing opacity behavior must work together as one continuous transition.

### Accidental y-axis regression

Touching viewport timing, `y`, spring behavior, or release timing would risk breaking the part that already feels correct. Those paths must stay untouched.

## Success Criteria

- Pressing `mod` makes the focused capsule feel like it opens up, not snaps wide.
- Releasing `mod` preserves the current y-axis exit feel while width retracts more softly.
- Switching workspaces preserves the outgoing and incoming handoff continuity.
- The focused capsule remains the same visual object across expand, handoff, and collapse.
