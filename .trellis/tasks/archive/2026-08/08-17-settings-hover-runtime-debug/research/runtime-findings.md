# Settings Hover Runtime Findings

## Environment

- Live Quickshell instance: real Wayland Settings overlay on `eDP-1`.
- Diagnostics were enabled through the `settings` IPC target.
- `qmltestrunner` remains unusable as a verdict in this environment; these
  findings come from structured live-shell snapshots.

## Confirmed Geometry

- Settings overlay: `570x1029`, open and masked by `settingsOverlay`.
- Content starts at scene X `170`, width `400`.
- Viewport starts at scene Y `100`, width `400`, height `885`.
- Appearance Row and control scene rectangles match their painted layout.
- Existing Row and control HoverHandlers receive pointer input in the live
  panel, ruling out a universal mask, viewport mapping, or handler starvation
  failure.

## Diagnostic Trap

A temporary Overlay-root `HoverHandler` was added to observe the global pointer
position. During the fourth interaction round, its point lay inside Row and
control scene rectangles while those descendants reported `hover: false`.
This happened even with `blocking: false`.

The observer changed the input routing it was intended to measure. It was
removed immediately. Final diagnostics only read geometry and the point/state
of existing Row/control handlers; they add no PointerHandler.

## Tooltip Observations

- Row description requests use priority 1 and Slider nub requests priority 2.
- Some snapshots captured tooltip fade-out or requests from rows outside the
  four sampled rows. These frames are insufficient to prove a stale-request
  bug and do not justify another Tooltip arbitration change.
- Null Tooltip sources are rejected at the bridge boundary so they cannot
  leave invisible request records.

## Decision

The component-refactor gate was not met. Runtime evidence shows the existing
Window, viewport, Row, and control ownership boundaries can receive input.
The task retains a default-off, privacy-safe diagnostic path and does not add
another speculative behavior fix or restructure the Row/control framework.
