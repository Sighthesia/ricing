---
name: async-layer-sync-lag-debugging
description: Use when a secondary render layer that updates on an asynchronous or coalesced/throttled commit path (compositor blur/mask region, low-frequency mirror/shadow copy, polish-cycle-driven geometry) visibly lags, stutters, overflows, or pops relative to a main layer that renders synchronously every frame, especially during fast size/shape animations.
---

# Async Layer Sync-Lag Debugging

Debug visual artifacts caused by two render layers updating on different clocks: a main layer that updates per frame (scene-graph / GPU) and a secondary layer that updates on an asynchronous, coalesced, or throttled commit path.

## The Generic Pattern / Methodology

**Core Concept**

- Many UI stacks have a *main layer* (drawn synchronously every frame) and one or more *secondary layers* whose updates are committed on a different, lower-frequency or asynchronous clock:
  - compositor blur / visible / input region (Wayland `setVisibleRegion`, mask)
  - polish-cycle / layout-pass driven geometry that gets coalesced
  - mirrored copies, cached shadows, snapshot/thumbnail layers
  - any value pushed across a process/IPC/protocol boundary on commit
- The two clocks are not synchronized. During a *continuous per-frame animation* the secondary layer samples the main layer's value at a lower, irregular rate, so it **trails** the main layer.
- The artifact is direction- and speed-dependent: it is worst where the trailing layer is momentarily *larger* or *misaligned* relative to the shrinking/moving main layer (e.g. collapse/shrink overflow), and least visible where the layers happen to agree.

**Universal Checklist** (before touching parameters)

| Question | Why it matters |
|---|---|
| Which layer renders **per frame**, which renders on a **coalesced/async** path? | Identifies the two clocks; the fix lives on the async layer. |
| Is the commit path **guaranteed per-frame**, or can it coalesce/skip? | Coalescing is the root cause of stutter; confirm via framework source/docs, not assumption. |
| In which **direction** (grow vs shrink) and at which **speed** does the artifact appear? | Lag artifacts are asymmetric; the fix usually only needs to act in one direction. |
| Which **edges/axes** actually move during the animation? | Pinned edges never overflow and need no correction. |
| Does the value being committed **step** (jump to target) or **ramp** (per-frame)? | Stepping the async value causes pop/disappear; it must ramp continuously. |

## The Specific Trap / Symptom (Case Study)

In the afloat dynamic-island center surface, the main silhouette is a `QtQuick.Shapes.Shape` redrawn by the scene graph **every frame** during the expand/collapse spring. The blur is a `BackgroundEffect.blurRegion` reported to the Wayland compositor, committed on Qt's **coalesced polish cycle** (`schedulePolish` → `onWindowPolished` → `setVisibleRegion`), which is *not* guaranteed per frame. After the Canvas→Shape migration sped up the main layer, the blur's pre-existing async lag became visible: on collapse the blur trailed the shrinking body and **spilled past the silhouette** ("one frame behind, stuttering").

Failed attempts (the trap is that none of these address the clock mismatch):

| Attempt | Why it failed |
|---|---|
| Tune spring `mass`/`damping` | Lag is in the commit clock, not the motion curve. |
| Critical damping + larger `epsilon` to shorten the tail | The layer still ramps per frame → still samples on the coalesced clock → still stutters. |
| Freeze blur to a fixed **target-sized** rect while animating | Target is a *step* value → blur jumped to final size instantly → "sudden disappear/appear". |
| Clamp blur to `min(live, target)` | `target` still a step → instant snap to final size on collapse onset → "blur vanishes". |

## The Anti-Pattern vs. Best Practice

- ❌ **Anti-pattern 1**: Treat a cross-clock lag as a *motion-curve* problem and tune the animation easing/spring. The async layer ignores your curve; it samples whenever its commit fires.
- ❌ **Anti-pattern 2**: Make the async layer jump to the **target** (step) value. This trades stutter for a pop/disappear, because the async layer is now discontinuous.
- ✅ **Best practice**: Keep the async layer **ramping continuously** with the main layer (no step), but bias it by a **velocity-adaptive lead** in the artifact-prone direction:
  - lead amount ∝ the main layer's **per-frame change speed** in that direction
  - **zero at rest and at motion onset** (no pop, no permanent inset)
  - **largest mid-animation** (absorbs the worst lag)
  - **zero again once settled** (layers sit flush)
  - apply only on the **moving edges**; pinned edges get no lead

- If the async layer is not actually shrinking/growing but is being **translated by an overlap-driven push**, do **not** reuse a velocity lead that remembers the last delta. That can stick the blur in the middle or leave it permanently offset. Use a **self-zeroing direct offset** from the current push amount, or temporarily disable the async layer during motion if the region commit path still cannot keep up.

```qml
// Per-frame shrink speed as a lead proxy; only acts while shrinking.
property real leadW: 0
property real _lastW: width
onWidthChanged: { leadW = Math.max(0, _lastW - width) * leadFactor; _lastW = width }
// async layer source size = live size - lead (clamped >= 0)
```

## Generalizable Rules (Highly Portable)

- **Locate the clock first.** When two layers disagree only *during motion*, find which one commits asynchronously/coalesced before changing anything. Confirm the commit cadence from framework source/docs.
- **Never step an async-committed value during a continuous animation.** Step values (jump-to-target) on a trailing layer produce pop/disappear. Keep it continuous.
- **Correct in the failing direction only.** Lag artifacts are asymmetric (overflow on shrink, gap on grow). A one-sided, velocity-proportional correction beats a symmetric fixed margin.
- **Make the correction self-zeroing at the endpoints.** Any lead/inset/offset that is non-zero at rest leaves a permanent visual defect; tie it to velocity so it vanishes when motion stops.
- **Prefer current-state offsets over remembered delta when the main layer is being pushed, not resized.** A stale lead on a translated blur region can freeze in the middle or fail to recover; a direct binding to the current push amount is safer when the source geometry remains stable.
- **Don't fix a cross-clock problem with motion-timing knobs.** Spring/easing/duration changes cannot synchronize two independent clocks.

**Warning signs this class of bug exists elsewhere**

- A property is mirrored into a compositor region, mask, cached effect, snapshot, or across IPC, *and* that property is also animated per frame.
- An artifact appears only during fast transitions and disappears at rest.
- Speeding up the main layer (e.g. Canvas→Shape, CPU→GPU) suddenly *reveals* a lag that was previously hidden by both layers being slow.

## Universal Verification Strategy

- **Exercise the failing direction at speed.** Trigger the fastest version of the transition (e.g. rapid collapse) repeatedly; the artifact is speed-gated, so slow manual stepping can hide it.
- **Check both endpoints and the midpoint.** Confirm: flush at rest, no pop at onset, no overflow/gap mid-motion, flush again after settling.
- **Vary the lead/correction factor and observe the trade.** Too small → residual overflow mid-motion; too large → visible inset/gap. The correct value is the smallest that removes the artifact across the speed range.
- **Confirm pinned edges are untouched.** Edges that don't move during the animation must remain flush (no spurious correction).
- **Verify reset behavior explicitly.** For any offset/lead that is driven by motion, test motion stop, reversal, and unrelated state changes. If the secondary layer only recovers when an unrelated event happens (e.g. another overlay toggles), the compensation is not self-zeroing enough.
