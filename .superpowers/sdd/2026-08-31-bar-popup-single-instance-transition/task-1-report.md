# Task 1 Report: Establish Intent And Geometry Contracts

## Modified Files

- `modules/bar/BarPopupHost.qml`
  - Added `currentIntent`, `pendingIntent`, `transitionSerial`, and `replacingContent` state.
  - Added target geometry properties: `targetX`, `targetY`, `targetWidth`, and `targetHeight`.
  - Added meaningful intent identity comparison and validated intent-field fallback helpers.
  - Added `popupHeightForIntent()`, `targetGeometryFor()`, and `updateTargetGeometry()`.
  - Changed the popup container to consume explicit target geometry while preserving the fixed full-screen host and single `TwoLayerPopup` owner.
  - Replacement updates preserve the existing popup instance and record the latest intent as pending state for later transition tasks.
- `tst_bar_popup_host.qml`
  - Added plain hover/context intent replacement checks without calling `dismissImmediately()`.
  - Added assertions for host ownership, pending intent, transition serial, and target clamping.

## Commit

- Commit: `c7c9300`
- Message: `feat(bar): track popup replacement intent separately`

## Tests

Command:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Exact result:

```text
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
PASS: replacement keeps host open
PASS: replacement keeps surface active
PASS: replacement exposes latest intent
PASS: replacement keeps original popup owner
PASS: replacement records pending intent
PASS: replacement increments transition serial
PASS: replacement target remains screen-clamped
PASS: dismissImmediately closes host
PASS: dismissImmediately clears surface
PASS: bottom bar direction is up
PASS: TwoLayerPopup direction Up for bottom bar
PASS: still open after intent swap
PASS: orientation is Vertical
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
Totals: 42 passed, 0 failed
```

The harness also emitted the pre-existing Quickshell warnings:

```text
WARN: QML ProxyFloatingWindow: Setting `width` is deprecated. Set `implicitWidth` instead.
WARN: QML ProxyFloatingWindow: Setting `height` is deprecated. Set `implicitHeight` instead.
```

Additional self-check:

```bash
timeout 25 /usr/lib/qt6/bin/qmllint modules/bar/BarPopupHost.qml
```

Output contained only the existing `PanelWindow is not creatable` and unresolved `margins` warnings; no new QML errors were reported.

## Self-Review

- Confirmed the focused behavioral harness reports `42 passed, 0 failed`.
- Confirmed replacement uses the same `popupItem` object before and after switching from hover to context intent.
- Confirmed target X geometry remains clamped to the configured screen margins.
- Confirmed context and hover popup heights are selected independently by intent kind, without taking the maximum across both menus.
- Confirmed `git diff --check` passed before commit.
- Confirmed unrelated worktree changes were not staged or modified.

## Concerns

- `root.intent` is exposed as the newest intent immediately to satisfy the existing public contract and Task 1 harness; the visible-content application of `pendingIntent` is intentionally deferred to the later animation task.
- The `PanelWindow`/`margins` lint warnings predate this task and remain unresolved.
- The report is intentionally outside the Task 1 commit because the brief requires the commit to contain only the host and harness changes.

## Follow-up Fixes

- `updateIntent()` now updates host anchor, screen dimensions, bar height, margin, and direction only when the incoming field is valid; invalid or missing anchor/barPosition values preserve the host fallback.
- `currentIntent` remains the displayed intent during replacement while every replacement request updates `pendingIntent`, including the latest request.
- `updateTargetGeometry()` now uses the explicit 260px popup width and the sidebar/content `implicitHeight` contract instead of transient rendered layer dimensions.
- The harness now checks current/pending intent ownership, hover/context implicit heights, invalid anchor and barPosition fallback, bottom placement, and screen-edge geometry.

## Follow-up Verification

Command:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Exact result:

```text
WARN: QML ProxyFloatingWindow: Setting `width` is deprecated. Set `implicitWidth` instead.
WARN: QML ProxyFloatingWindow: Setting `height` is deprecated. Set `implicitHeight` instead.
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
PASS: hover height selects hover implicit height
PASS: replacement keeps host open
PASS: replacement keeps surface active
PASS: replacement exposes latest intent
PASS: replacement keeps current intent
PASS: replacement keeps original popup owner
PASS: replacement records pending intent
PASS: replacement increments transition serial
PASS: replacement target remains screen-clamped
PASS: context height selects context implicit height
PASS: invalid anchor keeps host anchor
PASS: invalid bar position keeps host direction
PASS: invalid anchor geometry uses fallback
PASS: dismissImmediately closes host
PASS: dismissImmediately clears surface
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
Totals: 50 passed, 0 failed
```

Additional verification:

```bash
```

Exact result: no output, exit status 0.

```bash
timeout 25 /usr/lib/qt6/bin/qmllint modules/bar/BarPopupHost.qml
```

Exact result: existing warnings only: `PanelWindow is not creatable`, unresolved grouped property `margins`, and its unresolved type warning; no new QML errors.

## Follow-up Commit

- Commit: final hash recorded after this report update.
- Message: `fix(bar): preserve popup geometry fallbacks`

## Targeted Review Fixes

- Visible identity and action bindings now consume `currentIntent`; `intent` remains the newest requested payload while `pendingIntent` waits for the later content transition.
- Initial opening initializes `currentIntent`, and replacement geometry continues to use the current displayed kind.
- The content slot selects only the hover or context menu height for `currentIntent`, with a legal minimum height of `1` when no intent is available. Geometry is refreshed when the measured slot height changes.
- The harness now verifies initial current-intent ownership, old-current/new-pending replacement state, current-kind height retention, and context-kind height selection.

## Targeted Review Verification

Command:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Result: `55 passed, 0 failed`.

The harness emitted only the existing `ProxyFloatingWindow` width/height deprecation warnings.

Additional checks:

```bash
qmllint modules/bar/BarPopupHost.qml
git diff --check
```

Both completed successfully. `qmllint` produced no output for this file.

## Concerns

- The existing Quickshell `ProxyFloatingWindow` width/height deprecation warnings remain outside this targeted fix.
- `contentData` is a QML `data` alias and is not directly property-reflectable as the slot Item in the harness; height assertions use the host's height-selection contract instead.
