# Quality Guidelines

> Code quality standards for frontend development.

---

## Overview

Quality is driven by the repo's layering rules and hot-reload safety. Keep UI
declarative, keep shared logic in services, and validate the full shell before
considering a change done.

---

## Forbidden Patterns

- Hardcoded feature colors when `Colors.*` already exists.
- Direct `visible` toggles for animated/transient panels when a state machine is
  already used.
- UI-owned persistence timers or direct file writes outside services.
- Duplicating shared behavior instead of extracting a base component/service.
- Ignoring malformed JSON, process failures, or missing keys.
- Mixing `anchors.*` geometry with manual `x`/`y` animation on the same item.
- Stacking `Behavior` and imperative animation on the same property unless the shared
  ownership is intentional and documented.
- Rebuilding `Repeater` or delegate models during active motion when the effect depends on
  persistent local animation state.
- Using `Qt.callLater()` to create user-visible motion when a real animation timeline
  is required.
- Duplicating floating-shell chrome when a shared shell surface component and
  shared shell tokens already exist.
- Introducing a separate media panel chrome path when the standalone panel and
  embedded SuperIsland card can share the same shell treatment.

---

## Required Patterns

- `shell.qml` should only wire top-level windows.
- Use `Theme.*` / `Colors.*` for shared styling and animation values.
- Use shared shell token families (`ThemeCards.shell*`) and shared shell
  surfaces (`FloatingShellSurface.qml`) for floating popups/panels.
- When a shell can appear both standalone and embedded, keep the content
  component single-sourced and parameterize the chrome rather than cloning it.
- Use service singletons for shared state and persistence.
- Use guard clauses and recoverable fallbacks for external input.
- Keep file-level comments short and explain why, not history.
- For visible motion, assign one owner per animated property and keep the timeline in a
  single place.
- Prefer explicit `ParallelAnimation` / `SequentialAnimation` when the transition must
  preserve intermediate visual states across frames.
- For indicator or capsule motion inside repeated rows, keep the animated state root-owned
  or keep delegate identity stable across service refreshes.
- For `ListView` filter/reorder motion, prefer incremental model sync plus a detached outgoing
  layer, keep delegate reuse/state from collapsing the timeline, and sync suppressed delegates
  to their live viewport state before releasing transition ownership.

### Convention: Keep shared media visibility source-driven

When a shared clock/media row is reused by multiple hosts, the default media
visibility must stay driven by `SettingsService.data.superIsland.showMedia`
unless the final owner explicitly needs to override it.

**Good**:
- Let `showMedia` default from `SettingsService.data.superIsland.showMedia`.
- Override media visibility only at the final owner that truly owns the shared
  presentation.

**Avoid**:
- Hardcoding `showMedia: true` in intermediate wrappers or shared loaders.
- Forcing the same media row on and off from multiple layers of the host chain.

**Why**: it keeps embedded and standalone uses of the same clock/media component
consistent and prevents one path from silently bypassing user settings.

**Example**:
```qml
// Shared media row stays settings-driven unless the final owner overrides it.
IslandClockMediaRow {
    showMedia: SettingsService.data.superIsland.showMedia
}
```

### Convention: Use helper extraction for host slimming

When a composition root starts mixing many unrelated derived values, extract the
most stable, pure property clusters into a helper object before touching motion
or service behavior.

**Good**:
- Extract screen/mode/shape constants into a helper object.
- Keep host aliases or bindings so downstream code still sees the same property
names.

**Avoid**:
- Splitting behavior and geometry in the same refactor slice when one of them
depends on local child IDs or animation progress.
- Leaving a large host file untouched just because the extraction is not perfect.

**Why**: this gives you a low-risk first slice that reduces file size and makes
the next extraction boundary obvious.

### Convention: Finish coupled return handoffs in one frame

When a transient or hint return path hands visual ownership back to the steady
idle state, the phase flip, track reset, and baseline event restoration must
settle in the same frame unless one explicit animation owner still controls all
affected properties.

**Good**:
- Let one completion owner finalize position, scale, opacity, and steady-state
  event identity together.
- If exit completion is synchronized to an animation callback, restore the
  baseline track state in that same callback when no later timeline owns the
  remaining properties.

**Avoid**:
- Flipping `phase` to `idle` in one tick and deferring `resetTracks()` or other
  baseline geometry/style restoration to `Qt.callLater()`.
- Splitting return completion so geometry settles in one owner while width,
  scale, or style identity only catches up in a later callback.

**Why**: return-path bugs in SuperIsland showed that next-tick cleanup can make
  the visible clock land at the correct position first, while width/style still
  belongs to the previous owner and catches up a frame later. For coupled
  handoffs, same-frame completion is safer than staggered cleanup.

**Example**:
```qml
function completeWindowHintExit() {
    root.state._phase = "idle"
    root.state._mainDisplayEvent = settledMainEvent
    root.machine.resetTracks()
    root.machine.syncOverlayExtensionReservation()
}
```

### Convention: Centralize shared return target ownership

When a visual element crosses seam boundaries during return/handoff, use
explicit resolve/latch/release helpers for its return target geometry instead
of scattering target computation, locking, and clearing across property
bindings, phase-change handlers, and visibility handlers.

**Good**:
- Use a single resolve function to compute the return target position.
- Use a single latch function to lock the target at the start of a return.
- Use a single release function to clear the target on completion or loss.
- Keep timeline callbacks as thin triggers, not half-completers.

**Avoid**:
- Duplicating target computation inside property bindings and helper functions.
- Locking or clearing target state directly in phase-change or visibility
  handlers instead of through the owning helper.
- Leaving non-full-hint collapse paths without cleanup of attached overlay
  state, even when they do not call the full completion function.

**Why**: when the return target is resolved, latched, and released through
  three explicit helpers, the ownership model is easy to read and extend.
  Splitting these responsibilities across host bindings, timeline callbacks,
  and completion functions creates ambiguity about who owns the return target
  at each step.

**Example**:
```qml
// Resolve the target position through a single helper.
readonly property real _returnTargetCenterY: _resolveReturnTargetCenterY()

function _resolveReturnTargetCenterY() {
    if (_latched > 0) return _latched
    return _computeDefaultTarget()
}

function _latchReturnTarget() {
    _latched = _resolveReturnTargetCenterY()
}

function _releaseReturnTarget() {
    _latched = 0
}
```

---

## Testing Requirements

Run the whole-shell load check when making code changes:

```bash
timeout 5 qs --path .
```

There is no project-local unit test suite defined in this repo.

---

## Code Review Checklist

- Does the change respect the `services/` -> `config/` -> `modules/` flow?
- Are shared tokens and settings reused instead of duplicated?
- Are external inputs guarded and recoverable?
- Are animation and panel behaviors consistent with existing base components?
- Did the author avoid introducing new ad-hoc persistence or state ownership?
- Does each animated property have exactly one geometry owner?
- If motion is driven by service updates, was the full service -> host -> leaf path
  checked?
- If motion lives inside a `Repeater`, was delegate identity kept stable during updates?
