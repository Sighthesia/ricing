# Super Island Widget — Design Document

**Date:** 2026-03-09  
**Status:** Implemented and revised after interaction review

## Overview

Super Island is still the center-bar primary component, but the final V1 behavior is now split into two different classes of information instead of treating every event as equal.

The component now has:

- a stable Pill baseline for durable center content
- a full transient round-trip flow for important content such as media and notifications
- a separate weak-hint path for high-frequency window switching

This revision exists because window and workspace switching turned out to be too noisy to keep occupying the center Pill with the same priority as media and notifications.

## Final Product Model

### 1. Baseline Pill

The Pill is the stable center surface.

V1 baseline order:

1. idle time
2. future baseline-capable content if explicitly added later

Current implementation keeps the Pill stable unless a primary transient event is active.

### 2. Primary transient flow

Media and notification events use the main transient round-trip model:

1. old baseline content moves down into flash
2. new content enters the Pill from outside
3. the new content stays in the Pill for 1.5 seconds
4. the new content exits the Pill along the reverse path
5. the old content returns from flash back into the Pill

Only one primary transient is allowed at a time.

If another primary transient arrives while one is already active:

- the current flow is allowed to complete
- only the latest pending transient is kept
- the pending transient starts after the return animation completes

## Window Switching Reclassification

Window switching no longer participates in the primary transient model.

This is the biggest design correction in the current revision.

### Why it changed

When window switching occupied the Pill, frequent navigation made the center component feel noisy and prevented media and notification content from surfacing in time.

That behavior conflicted with the intended role of Super Island as a center component for higher-value events.

### Final window behavior

Window switching is now a weak hint:

- it does not take over the Pill
- it renders only in the flash area
- it is visually lighter than the main transient path
- it can be interrupted immediately by more important content

This keeps navigation feedback available without letting it dominate the center surface.

## Workspace Behavior

Workspace switching is no longer represented as its own standalone content block.

Instead:

- workspace information is folded into the window hint
- the hint shows the workspace number alongside the window content
- if there is no focused window, no workspace hint is shown

This avoids creating a second high-frequency content type that would otherwise compete with the center component’s primary role.

## Event Classes

### Primary transient events

Current V1 primary transients:

- notifications
- media changes

These may use the full Pill plus flash round-trip behavior.

### Weak hint events

Current V1 weak hints:

- focused window change
- workspace switch when it results in a focused window

These use flash-only rendering and are intentionally weaker than the primary transient path.

### Ignored navigation states

- workspace switch with no focused window

These do not render in Super Island.

## Scheduling Rules

### Primary transient scheduler

Primary transients use a single active slot and a single pending slot.

Rules:

1. only one primary transient may be active
2. while one is active, only the latest pending transient is retained
3. a pending transient starts only after the current round-trip finishes

### Window hint scheduler

Window hints are weaker and more disposable.

Rules:

1. window hints do not claim the Pill
2. when a window hint is already active, newer window hints hot-update the same hint slot
3. if a stronger primary transient arrives, the window hint may be replaced immediately

## Rendering Rules

### Pill

The Pill renders:

- baseline content during idle
- current primary transient during the hold phase

It does not render standalone workspace content.

### Flash area

The flash area renders two different meanings depending on event class.

For primary transients:

- the old baseline content during the round-trip flow

For window hints:

- the current weak navigation hint only

## Current Implementation Notes

Implemented in:

- `services/SuperIslandService.qml`
- `modules/bar/widgets/SuperIslandWidget.qml`
- `services/MediaService.qml`
- `modules/bar/superisland/*.qml`
- `SuperIslandServiceSmoke.qml`

Current implementation also includes:

- a smoke harness for round-trip behavior
- a latest-pending assertion for primary transients
- a buffer to prevent pending start from racing the return animation
- a widget-side baseline guard so pending transitions do not accidentally use the previous transient as flash source

## Known Follow-up

The runtime model is implemented, but the widget settings panel does not yet expose a dedicated Super Island section for toggling window-switch hints.

That is a separate follow-up task and should not change the current behavior model described here.