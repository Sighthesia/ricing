---
name: launcher-search-transitions
description: Use when modifying launcher app/clipboard search transitions, especially when filtering paths mix live ListView motion with detached outgoing/incoming layers or rapid typing causes blank frames, overlap, or residual ghosts.
---

# Launcher Search Transitions

Launcher search motion is stable only when one generation owns the screen at a time and live ListView motion is limited to truly safe narrowing cases.

## When to Use
- You are changing launcher search filtering, reorder, or provider-switch animation.
- Narrowing, broadening, or clearing the query causes blank frames, overlap, or residual ghosts.
- Rapid typing makes outgoing and incoming rows stack or linger.

## Symptoms
- Rows disappear before the next generation is ready.
- Clearing or broadening search shows detached incoming over already-visible live rows.
- Rapid typing leaves multiple retiring generations on screen.
- List items appear half-clipped because real delegate height is being animated.

## Root Cause
- `modules/launcher/LauncherCore.qml` routes different query changes through `incremental`, `softReplace`, and recovery paths.
- `modules/launcher/LauncherResultsList.qml` maintains live delegates plus detached `_outgoingItems` and `_incomingItems`; if multiple generations survive together, overlap is inevitable.
- `ListView` delegate instantiation is not synchronous, so detached layers must not be cleared until live handoff is actually safe.
- Animating real delegate height makes interrupted transitions leave clipped half-rows.

## Correct Pattern
- Keep live `ListView` motion only for safe same-provider narrowing where surviving visible rows can truly reorder in place.
- Use detached outgoing/incoming layers for risky paths such as broadening, clear-query recovery, and top-window replacement.
- During `softReplace`, hide only the covered live row content, not the entire `ListView`.
- Treat rapid repeated input as a cancellation case: discard old detached generations instead of merging them forward.
- Do not animate real launcher delegate height; keep live rows at fixed height and put replace motion in detached layers.
- If interrupted incoming rows must retire, make them weaker than normal outgoing rows; never promote untouched `pendingIncoming` rows into full outgoing snapshots.

## Rapid Input Rule
- Use a short recent-input window in `modules/launcher/LauncherCore.qml` to detect repeated refreshes while transitions are still busy.
- When that guard trips, call `beginFilterTransition(..., true)` / `beginExpandTransition(..., true)` so `modules/launcher/LauncherResultsList.qml` drops old detached incoming/outgoing generations instead of preserving them.
- Prefer losing some intermediate polish over letting old generations overlap the latest query.

## Verification
- Run `timeout 5 qs --path .`.
- Manually test:
  - `空 -> q`
  - `q -> qt`
  - `qt -> q`
  - `q -> 清空`
  - very rapid repeated typing and deletion
- Confirm there is no blank frame, no duplicate overlay over live rows, and no half-clipped row bodies.

## References
- `modules/launcher/LauncherCore.qml`
- `modules/launcher/LauncherResultsList.qml`
- `modules/bar/ViewportStaggerItem.qml`
- `modules/bar/StaggerItem.qml`
