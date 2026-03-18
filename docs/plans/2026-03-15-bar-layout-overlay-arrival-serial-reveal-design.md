# Bar Layout Overlay Arrival Serial Reveal Micro-Design

**Date:** 2026-03-15
**Status:** Draft
**Parent docs:**
- `docs/plans/2026-03-15-bar-layout-overlay-arrival-design.md`
- `docs/plans/2026-03-15-bar-layout-overlay-arrival-plan.md`

## Overview

The overlay-arrival direction is still correct, but the final handoff rule for multiple new widgets in the same section is underspecified.

The current failure is not about geometry ownership anymore.
It is about reveal ordering.
When two overlay actors finish close together, both real delegates can begin their enter animation in the same visual lane, which recreates overlap during the first visible frames.

This micro-design narrows the fix to one rule only:

- overlay actors may coexist
- real delegate reveal may not start concurrently within the same section

## Decision

Adopt a service-owned token-baton contract for serial reveal.

This works like a turnstile queue.
Several people can wait in line, but only the person currently holding the gate token may pass through.

In shell terms:

- multiple overlay arrival actors may animate at the same time
- each actor can mark its instance as `readyForDelegate`
- `BarLayoutService` releases exactly one delegate reveal token per section at a time
- once that delegate completes its normal enter animation, the token moves to the next ready instance in that section

## Why This Is The Right Scope

This keeps the original overlay-arrival architecture intact:

- service still owns geometry and runtime arrival state
- `DragOverlay` still owns the first visible frame
- `BarWidgetWrapper` still owns steady-state rendering and its normal enter animation

The only thing changing is the handoff policy between overlay and delegate.

## Rejected Alternatives

### Strict actor queue

Only allow one overlay actor at a time.

Why not:

- simplest technically
- but visually more conservative than needed
- unnecessarily slows insertions when multiple widgets are added quickly

### Wrapper settle inference

Let wrappers infer whether they may reveal by observing neighbor geometry or row movement.

Why not:

- puts timing responsibility back into UI inference
- reintroduces the same class of race we are trying to eliminate
- harder to test than an explicit service token

## Contract

### 1. Arrival snapshot stays until service releases reveal

An arrival snapshot should no longer mean only "overlay actor exists".
It now means "this instance has not fully crossed the overlay-to-delegate boundary yet".

Suggested transient fields:

- `active: bool`
- `phase: "overlay" | "delegate"`
- `readyForDelegate: bool`
- `delegateReleased: bool`

The exact property names may vary, but the semantics should remain explicit.

### 2. Overlay actor completion does not immediately clear the snapshot

When an overlay actor finishes its visual arrival:

- it marks the snapshot as ready
- it asks the service to attempt release for that section
- it does not directly clear the snapshot

This is the key correction.
The baton belongs to the service, not to whichever actor happened to finish first.

### 3. Service owns one reveal baton per section

`BarLayoutService` should maintain a transient per-section reveal lock or baton, conceptually:

- no baton holder for `left`, `center`, `right` at startup
- when a section has ready arrivals and no current holder, release the earliest ready instance in slot order
- keep that holder until the matching wrapper reports enter completion
- then release the next ready instance in the same section

Ordering source must come from `sectionSlots(section)` or equivalent service-owned slot order, not delegate-local order guesses.

### 4. Wrapper reveal gate becomes explicit

`BarWidgetWrapper` should reveal only when both are true:

- no active overlay phase remains for its instance
- the service has released the reveal baton for its instance, or the instance is not participating in serial arrival at all

That means the wrapper no longer interprets generic arrival absence as sufficient by itself.
It also needs explicit release permission for serial-arrival cases.

### 5. Wrapper completion advances the queue

At the end of the wrapper's normal enter animation:

- the wrapper notifies the service that its reveal finished
- the service clears that baton holder
- the service releases the next ready instance in the same section, if any

## Data Flow

1. `addWidget()` inserts a new instance and records overlay-arrival snapshot.
2. `DragOverlay` renders the actor at the service-owned slot.
3. Actor animation finishes and marks the instance `readyForDelegate`.
4. `BarLayoutService` checks whether the section baton is free.
5. If free, the service releases the earliest ready instance in slot order.
6. That wrapper runs its existing enter animation.
7. When the wrapper finishes, it notifies the service.
8. The service passes the baton to the next ready instance in the same section.

## Testing Impact


- both inserted instances can have active overlay actors initially
- the later instance remains hidden while the earlier reveal token is still in flight
- the first wrapper becomes visible before the second wrapper begins reveal
- the second wrapper begins reveal only after the first wrapper completes and the baton advances
- no first-visible overlap occurs between adjacent inserted widgets

Its wait window should account for two serial delegate enters within the same section.

## Non-Goals

- redesigning drag overlay visuals
- changing section geometry math
- changing persistence
- redesigning arrival behavior across different sections
