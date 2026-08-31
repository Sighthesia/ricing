# Task 2 Report: Animate Popup Geometry Without Resizing The Surface

## Status

Implemented and verified.

## Modified Files

- `modules/bar/BarPopupHost.qml`
  - Added independent `displayX`, `displayY`, `displayWidth`, and `displayHeight` properties.
  - Kept `PanelWindow` full-screen with its existing `implicitWidth`, `implicitHeight`, anchors, and margins.
  - Changed `popupContainer` to consume displayed geometry only.
  - Added retargetable position and size `NumberAnimation` instances using `MotionTokens.medium` and `Easing.OutQuint`.
  - Added reduced-motion immediate settling.
  - Retargeting restarts animations from their current displayed values without resetting them to the previous target.
  - Target height continues to use the selected popup slot's measured height plus the existing divider geometry.

## Commit

- `fix(bar): animate popup geometry within fixed host`

## Tests

Command:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Exact result:

```text
INFO: Launching config: "/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tst_bar_popup_host.qml"
INFO: Shell ID: "421a27bca9eabf70d9b377d49544e1e9" Path ID "421a27bca9eabf70d9b377d49544e1e9"
WARN: <Unknown File>: QML ProxyFloatingWindow: Setting `width` is deprecated. Set `implicitWidth` instead.
WARN: <Unknown File>: QML ProxyFloatingWindow: Setting `height` is deprecated. Set `implicitHeight` instead.
INFO: Configuration Loaded
PASS: showIntent opens host (top)
PASS: top bar direction is down
PASS: TwoLayerPopup direction Down for top bar
PASS: anchorX stored
PASS: screenWidth stored
PASS: intent preserved
PASS: popup reveal visible while open
PASS: popup container visible while open
PASS: hover content height positive
PASS: identity layer slides from behind bar
PASS: content layer shares slide offset
PASS: reveal is geometric (opacity channel off)
PASS: reveal drives toward open
PASS: content surface paints settings section color
PASS: sidebarData alias exists
PASS: contentData alias exists
PASS: initial open initializes current intent
PASS: hover height selects hover implicit height
PASS: replacement keeps host open
PASS: replacement keeps surface active
PASS: replacement exposes latest intent
PASS: replacement keeps current intent
PASS: replacement keeps original popup owner
PASS: replacement records pending intent
PASS: replacement keeps slot height for current kind
PASS: replacement increments transition serial
PASS: replacement target remains screen-clamped
PASS: replacement target keeps current kind height
PASS: invalid anchor keeps host anchor
PASS: invalid bar position keeps host direction
PASS: invalid anchor geometry uses fallback
PASS: dismissImmediately closes host
PASS: dismissImmediately clears surface
PASS: context open initializes current intent
PASS: context height selects context implicit height
PASS: context target follows context height
PASS: bottom bar direction is up
PASS: TwoLayerPopup direction Up for bottom bar
PASS: still open after intent swap
PASS: orientation is Vertical
PASS: bottom geometry stays above bar
PASS: bottom geometry clamps at screen edge
PASS: requestClose while popupHovered keeps open
PASS: close after both hovers released
PASS: TwoLayerPopup direction Up after bottom bar
PASS: reopen before cleanup keeps open
PASS: reopen intent preserved immediately
PASS: reopen direction is down
PASS: TwoLayerPopup direction Down after race reopen
PASS: new intent survives old clear timer
PASS: still open after old timer window
PASS: anchor updated after race
PASS: hover bridge still intact after race
PASS: context popup stays visible
PASS: context content height positive
Totals: 55 passed, 0 failed
```

Command:

```bash
qmllint modules/bar/BarPopupHost.qml
```

Exact result: no output, exit status `0`.

## Self-Review

- The outer `PanelWindow` remains screen-sized and does not receive per-frame popup geometry changes.
- `popupContainer` is driven exclusively by `display*` properties.
- `target*` values are computed independently and are updated before animation retargeting.
- Position and size animations are independently restartable and preserve the current displayed value on interruption.
- Bottom-bar placement is calculated with the new target height.
- Motion uses the shared `MotionTokens` duration, `Easing.OutQuint`, and reduced-motion gating.
- `git diff --check` passed.

## Concerns

- The existing behavior harness still reports two unrelated `ProxyFloatingWindow` deprecation warnings about `width` and `height`; `BarPopupHost.qml` already uses `implicitWidth` and `implicitHeight`, and `qmllint` reports no issues.
- The task harness validates target geometry and fixed host behavior, but does not measure an in-progress animation frame; the implementation keeps displayed values separate so retargeting remains interruptible by construction.
