---
name: per-frame-surface-resize-jank
description: Use when an expand/collapse/grow/shrink animation stutters or drops frames even though per-frame CPU/GPU work looks cheap. Applies when the animated size is driven into a costly-to-commit boundary every frame — a top-level/layer-shell/OS window, a compositor input/blur/visible region, a cross-process or protocol-committed surface, or a per-frame rebuild of a large model/object graph. Covers the fix (fixed outer container, animate inner content) and a frame-delta bisection method to locate the offending per-frame commit.
---

# Per-Frame Surface-Resize Jank

Diagnose and fix animation stutter caused by pushing a per-frame-changing size/geometry across an expensive commit boundary every frame, instead of keeping that boundary fixed and animating cheap inner content.

## The Generic Pattern / Methodology

**Core Concept**

- A smooth animation must do only *cheap* work per frame (move/resize/clip/opacity on scene-graph items the renderer already owns).
- Some boundaries are **expensive to mutate** and must NOT be driven every frame:
  - a top-level / OS / layer-shell **window** size (each resize = a compositor reconfigure roundtrip)
  - a compositor **input/visible/blur region** or mask committed over a protocol/IPC boundary
  - a **mirror/snapshot/cached** layer or any cross-process surface
  - a per-frame **rebuild of a large model/object graph** (fresh allocations → GC pauses)
- The portable shape of the fix: **fix the expensive outer boundary at a constant (large-enough) size, and animate cheap inner content inside it** — grow/clip the content, not the window/region/model.
- The reference smooth implementation in the same codebase usually already does this (e.g. a popup window pinned to full-screen height with content growing inside). Compare against it.

**Universal Checklist** (before tuning easing/spring)

| Question | Why it matters |
|---|---|
| Does the animated size feed a **top-level window** `implicitWidth/Height`? | Per-frame window resize = per-frame compositor reconfigure → periodic spikes. Pin it. |
| Does it feed a **committed region** (input/visible/blur/mask) every frame? | Region commits cross a protocol/IPC boundary; coalesce or pin during the animation. |
| Does the per-frame value flow through a **JS/model rebuild** that allocates objects? | Fresh allocations each frame thrash GC → sporadic long frames. Bypass the rebuild. |
| Is there a **sibling feature that animates smoothly**? | It almost certainly keeps the expensive boundary fixed; mirror its structure. |
| Can the outer boundary be a **fixed, generous size** with content clipped inside? | This is the fix; the extra transparent area is masked/click-through. |

## The Specific Trap / Symptom (Case Study)

A Wayland (Quickshell) top bar grew a dockzone downward to host a hover popup. The expand animation stuttered (frame deltas 44–88 ms instead of ~16 ms) despite a GPU `Shape` outline and a spring. Bisection found the dominant cost was the **bar `PanelWindow.implicitHeight` changing every frame** as the dockzone grew → each frame forced a layer-shell surface resize + compositor reconfigure roundtrip. A secondary cost was routing the per-frame spring value through a JS contract-model rebuild (`buildModel`/`deriveRendererMetrics`) that re-allocated objects each frame and also invalidated *unrelated* sibling sections. The sibling that was smooth (the center "island") used a **fixed full-screen-height window** with its body growing inside.

## The Anti-Pattern vs. Best Practice

- ❌ **Anti-Pattern**: bind an animated size to a top-level window dimension (`implicitHeight: content.implicitHeight`), or recompute a committed region / rebuild a large model object on every animation frame.
- ✅ **Best Practice**: pin the window/region/model to a constant (generously sized) value; animate inner item geometry and **clip**; restrict input with a state-switched mask (resting shape vs full-window-for-click-away); keep the reserved/exclusive zone pinned so layout never reflows.
- ❌ **Anti-Pattern**: feed the per-frame animated value as an *input* to a pure function that allocates a fresh nested object graph (model/metrics) each frame.
- ✅ **Best Practice**: compute the resting model once; apply the animation as a **lightweight additive geometry override** on the already-exposed properties (QML bindings / direct style props), so the hot path allocates nothing.

## Generalizable Rules (Highly Portable)

- **Never animate an expensive commit boundary.** Top-level window size, compositor regions, cross-process surfaces, and large object rebuilds are not per-frame-safe. Keep them fixed; animate inner content.
- **Fixed outer, animated inner.** Give the outer surface a constant generous size; grow/clip content within it. Mirrors the proven smooth sibling.
- **Pin reservation/exclusion separately from visible size.** A fixed tall window must still reserve only its resting footprint (e.g. exclusiveZone = bar height), and mask input to the resting shape until the popup is open.
- **Keep the animation hot path allocation-free.** Don't rebuild model/metrics objects per frame; apply additive overrides to existing properties.
- **For side previews and detail panes, fix the slot before the payload.** Keep the preview area at a constant width once that mode is open, and delay image decode / long-text layout / scroll setup until the host geometry has settled.
- **Warning signs in other code**: an `implicitWidth/Height` of a window/top-level bound to animated content; a region/mask whose `item` geometry is driven by a running animation; a `property var`/model that re-runs a builder on every frame of a transition; "smooth here but janky there" between two surfaces doing nominally the same thing.

## Universal Verification Strategy

- **Frame-delta probe + bisection.** Log `Date.now()` deltas on the animated property's change handler. Even ~16 ms = smooth; sporadic 40–90 ms = real jank. Then bisect by *temporarily neutralising one suspect per run* and re-measuring:
  - freeze the committed region (point blur/mask at a resting size) — spikes gone? region commit was it.
  - stop feeding the value through the model rebuild (additive override) — sibling elements stop firing? model rebuild was a cost.
  - pin the window size — spikes gone? per-frame window resize was the dominant cost.
- **Watch for cross-element contamination.** If *unrelated* siblings' geometry handlers fire every frame during one element's animation, a shared per-frame rebuild or shared committed boundary is the cause.
- **Compare to the smooth sibling.** Diff the janky surface against an existing smooth one; the difference is almost always "the smooth one keeps the expensive boundary fixed."
- **No mouse needed.** Drive the state from a temporary `Timer` toggling the trigger so the animation can be measured headlessly; remove the probe after.
