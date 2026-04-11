---
name: list-transition-handoffs
description: Use when modifying animated list filtering, replacement, or search transitions that mix live delegates with detached outgoing/incoming layers, especially when rapid updates cause blank frames, overlap, ghosts, or broken handoff.
---

# List Transition Handoffs

Animated list transitions stay stable only when one generation owns the screen at a time and risky refreshes do not rely on live delegate instantiation finishing immediately.

## When to Use
- You are modifying search, filtering, sorting, provider-switch, or replace motion in a `ListView` or repeated list.
- A list mixes live delegate motion with detached outgoing/incoming snapshot layers.
- Rapid repeated updates cause blank frames, overlap, residual ghosts, or clipped rows.

## Symptoms
- Rows disappear before the next generation is visibly ready.
- Detached incoming overlaps already-visible live rows.
- Rapid updates leave multiple retiring generations on screen.
- Interrupted rows look half-clipped because the real delegate body was animated directly.

## Root Cause
- Live delegates, detached outgoing snapshots, and detached incoming snapshots can each become a temporary source of truth.
- `ListView` delegate instantiation is not synchronous, so visual handoff cannot be based only on model updates or fixed timers.
- Promoting interrupted incoming layers into normal outgoing layers makes half-entered rows retire as if they were fully established.
- Animating real delegate height turns interrupted transitions into clipped row bodies.

## Correct Pattern
- Keep live `ListView` motion only for truly safe in-place refinement where visible surviving rows can reorder without replacing the top window.
- Use detached outgoing/incoming layers for risky replacement paths such as broadening, clear-query recovery, provider switch, or top-window replacement.
- During detached replace, hide only the covered live row content, not the whole list surface.
- Treat rapid repeated updates as cancellation: discard old detached generations instead of merging them forward.
- Keep live row height fixed; put replacement motion into detached layers instead of the real delegate body.
- If interrupted incoming rows must retire, make them weaker than established outgoing rows, and never promote untouched pending rows into full outgoing snapshots.

## Rapid Update Rule
- Detect repeated updates while transitions are still busy.
- When the guard trips, prefer dropping older outgoing/incoming generations over preserving every intermediate transition.
- Losing some intermediate polish is better than allowing old generations to overlap the latest state.

## Verification
- Run `timeout 5 qs --path .`.
- Test both calm and rapid updates.
- Confirm there is no blank frame, no duplicate overlay over live rows, no half-clipped row bodies, and no stale retiring generation after the latest update wins.

## DymicShell Example References
- Current launcher search is the concrete in-repo example of this pattern.
- `modules/launcher/LauncherCore.qml`
- `modules/launcher/LauncherResultsList.qml`
- `modules/bar/ViewportStaggerItem.qml`
- `modules/bar/StaggerItem.qml`
