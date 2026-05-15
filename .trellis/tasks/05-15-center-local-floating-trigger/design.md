# Design: Wrapper-Level Local Floating Trigger for Center

## Goal

Replace the temporary center floating validation boolean with a real but still local trigger source, implemented at the shared widget-wrapper boundary for the center path.

## Architecture

```text
BarWidgetWrapper (center delegates only)
   -> local hover / pointer intent signal
BarSection (center)
   -> aggregates wrapper-level intent into floatingValidationIntent
BarContent
   -> no longer owns a manual validation boolean as the primary trigger source
DockzoneSurfaceRoot
   -> continues consuming `surfaceState`
```

## Why `BarWidgetWrapper`

`BarWidgetWrapper.qml` is the narrowest shared boundary around center content:

- it already hosts all managed widgets
- it is more future-proof than wiring to `Placeholder.qml`
- it stays local to the center content path

This lets the floating trigger follow center content generally, not one specific widget implementation.

## Boundaries

### `BarWidgetWrapper.qml`

Responsibilities:

- detect local hover / pointer intent for its hosted widget
- expose that intent upward in a minimal reusable way

It should not:

- know about dockzone state names
- own floating progress
- talk to services

### `BarSection.qml`

Responsibilities:

- aggregate wrapper-level interaction intent for center content
- combine that with `sectionModel.length > 0`
- continue mapping into `hidden | attached | floating`

It should remain the semantic mapping layer.

### `BarContent.qml`

Responsibilities:

- stop being the primary owner of the temporary floating validation switch
- remain a simple composition root unless a tiny compatibility prop is still needed during migration

## Data Flow

1. A center `BarWidgetWrapper` detects local pointer presence.
2. The wrapper exposes that presence to its parent section.
3. `BarSection.qml` aggregates whether any center wrapper is currently expressing floating intent.
4. `BarSection.qml` maps:
   - no content -> `hidden`
   - content and no local trigger -> `attached`
   - content and local trigger -> `floating`
5. Existing owner/model flow remains unchanged downstream.

## Trigger Policy

First-pass local trigger should be conservative:

- hover or pointer presence over center content
- center-only
- no click-to-toggle memory

This is local, reversible, and closer to a real interaction than a hardcoded flag, while still avoiding a broad interaction system.

## Trade-offs

- Benefit: replaces the artificial validation boolean with a real local signal.
- Benefit: stays reusable across future center widgets.
- Benefit: preserves current owner/model architecture.
- Cost: introduces a small amount of local interaction plumbing.
- Cost: hover-based trigger may still be considered provisional product behavior until later UX decisions are settled.

## Compatibility Notes

- Left/right paths remain untouched.
- Services remain untouched.
- `DockzoneSurfaceRoot.qml` and `DockzoneSurfaceModel.js` should not need semantic redesign; they already consume `floating`.

## Rollback Shape

- remove wrapper-level interaction exposure
- restore the local temporary boolean path if needed
- keep downstream floating semantics intact
