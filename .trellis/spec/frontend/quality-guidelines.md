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

---

## Required Patterns

- `shell.qml` should only wire top-level windows.
- Use `Theme.*` / `Colors.*` for shared styling and animation values.
- Use shared shell token families (`ThemeCards.shell*`) and shared shell
  surfaces (`FloatingShellSurface.qml`) for floating popups/panels.
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
