---
name: qml-indicator-motion
description: Use when building or debugging moving active indicators, sliding circular highlights, or stretch-then-settle pills behind workspace tabs, icon rows, or segmented controls in DymicShell.
---

# QML Indicator Motion

Build active-indicator motion as a root-owned overlay, not as per-delegate local state.

## Use For

- Moving circular or pill highlights behind workspace buttons or icon rows.
- Recreating the `end-4/dots-hyprland` style stretch-then-settle active indicator.
- Cases where a focused-item background jumps because delegates get recreated.
- Cases where fast switching should keep the indicator moving smoothly across updates.

## Reference Pattern

- Inspiration source: `end-4/dots-hyprland` "illogical impulse"
- Reference file: `https://github.com/end-4/dots-hyprland/blob/main/dots/.config/quickshell/ii/modules/ii/bar/Workspaces.qml`
- Supporting model idea: `AnimatedTabIndexPair` with different lead/trail durations

## Core Rule

- Keep the moving indicator outside the repeated delegates.
- Let the root own the animated lead/trail state.
- Let delegates only provide stable geometry inputs such as icon count, step width, or current focus index.

## Good Ownership Split

| Layer | Owns |
| --- | --- |
| Root item | active index, lead index, trail index, indicator geometry |
| Row/container | step width, total width, clipping |
| Delegate | icon rendering only |

## Recommended Structure

```qml
property real _focusLeadIndex: -1
property real _focusTrailIndex: -1

Behavior on _focusLeadIndex {
    NumberAnimation { duration: 100; easing.type: Easing.OutSine }
}

Behavior on _focusTrailIndex {
    NumberAnimation { duration: 300; easing.type: Easing.OutSine }
}
```

```qml
Rectangle {
    x: Math.min(root._focusLeadIndex, root._focusTrailIndex) * stepWidth
    width: Math.abs(root._focusLeadIndex - root._focusTrailIndex) * stepWidth + indicatorSize
}
```

## Why This Works

- The leading edge reaches the target faster.
- The trailing edge catches up later.
- The indicator stretches during travel and settles back at the destination.
- Because the state lives at the root, service refreshes do not reset the motion every time delegates rebuild.

## DymicShell Notes

- In `modules/bar/superisland/IslandWindowHintCard.qml`, the workspace focus indicator should stay root-owned.
- Prefer `Colors.highlight`-derived fills over local hardcoded colors.
- If the indicator sits inside a clipped row, animate the overlay item and keep icon delegates simple.
- If fast switching still looks jumpy, check whether the repeated capsules themselves are being recreated from fresh arrays.

## When Not To Use It

- Do not use this pattern for full capsule enter/exit choreography where content identity changes mid-flight.
- Do not use it when each item has different measured widths unless you also promote actual geometry tracking to the root.

## Adaptation Ladder

1. Start with fixed-width steps.
2. Move the indicator overlay outside delegates.
3. Split one animated index into lead/trail indices.
4. Only after that, consider variable-width geometry tracking.

## Validation

- `timeout 5 qs --path .`
- Verify the indicator moves smoothly during repeated focus changes.
- Verify delegate rebuilds no longer cause visible jumps.
