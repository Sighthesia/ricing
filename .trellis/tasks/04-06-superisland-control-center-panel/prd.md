# SuperIsland Control Center Panel Stabilization

## Goal

Fix two regressions in the `SuperIsland` center lane after the expanded panel has been opened at least once:

- transient messages can leave the flash region non-interactive so the clock/pill cannot be opened again,
- after consecutive transient messages finish, the island width can shrink back with rectangular background artifacts on both sides.

## Confirmed Requirements

- Keep the existing SuperIsland interaction model and visual language.
- Focus on a minimal bug fix instead of redesigning the expanded panel.
- Preserve clock visibility and expand/collapse affordance after panel usage.
- Remove side background artifacts during the final width return to the normal pill.

## Product Intent

- The center lane should always recover to a clean idle state after transient activity.
- Temporary overlay or flash transitions must not poison later idle interactions.
- Width recovery should feel continuous and polished instead of exposing visual leftovers.

## Suspected Problem Areas

- State handoff between expanded panel usage, flash/transient return, and idle baseline recovery.
- Cleanup timing for flash/attached hint layers during repeated transient sequences.
- Geometry/background ownership during the final collapse back to the normal pill width.

## Acceptance Criteria

- [ ] After opening and closing the expanded panel, a later transient message does not block reopening the flash/clock area.
- [ ] When transient content ends, the idle clock becomes visible and interactive again.
- [ ] After consecutive transient messages, width shrink-back does not leave colored side rectangles.
- [ ] `timeout 5 qs --path .` passes after the fix.
