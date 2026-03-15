# Bar Layout Overlay Arrival Actor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the first visible frame of a newly inserted layout-mode widget come from a service-owned overlay actor parked at the final slot, then hand off cleanly to the real delegate with no transient overlap.

**Architecture:** Keep `services/BarLayoutService.qml` as the single source of truth for runtime slot geometry. Extend the existing transient arrival snapshot into an overlay-arrival actor contract, render that contract in `modules/bar/DragOverlay.qml`, and gate `modules/bar/BarWidgetWrapper.qml` until the overlay actor finishes and clears the snapshot.

**Tech Stack:** QML, Quickshell, `ListModel`, smoke harnesses under `tests/qml/`

**Design doc:** `docs/plans/2026-03-15-bar-layout-overlay-arrival-design.md`

---

### Task 1: Replace the current arrival smoke with an overlay-handoff smoke

**Files:**
- Modify: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Write the failing assertions for service actor state**

Update `_runArrivalAssertions()` so it no longer treats the real delegate as the first visible arrival surface.

Assert all of the following after inserting two left-section widgets in layout mode:

- `BarLayoutService.arrivalGeometry(instanceKey)` returns an active arrival snapshot for each new instance
- the snapshot is overlay-oriented runtime state, not just slot coordinates
- the matching real wrappers remain hidden while the snapshot is active

Use assertion shapes like:

```qml
root._assert(firstArrival !== null && firstArrival.active === true,
    "BarLayoutService should publish an active overlay-arrival snapshot for the first inserted widget")
root._assert(firstArrivingWrapper.opacity <= 0.01,
    "Real delegates should remain hidden while the overlay-arrival actor is active")
```

**Step 2: Write the failing assertions for overlay ownership**

In the same smoke flow, locate the arrival actor item inside `DragOverlay` and assert:

- an arrival actor item exists while the snapshot is active
- the actor is visible
- the actor width and `x` come from the service snapshot within tolerance

Do not assert exact animation curves or durations.

**Step 3: Run the smoke and verify RED**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL because `DragOverlay` does not yet render an arrival actor and the current code still clears arrival state from the real delegate path.

**Step 4: Keep the smoke structural**

Make the test prove only the contract:

- overlay actor exists
- wrapper is hidden during overlay phase
- handoff clears the snapshot
- wrapper becomes visible after handoff
- no overlap is shown on reveal

Do not lock the test to a particular easing curve, scale value, or timer length.

---

### Task 2: Convert service arrival state into an overlay-actor contract

**Files:**
- Modify: `services/BarLayoutService.qml`
- Test: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Preserve the current public entry point unless a rename is intentional**

Keep `arrivalGeometry(instanceKey)` as the public reader for now, but change the payload so it describes an overlay-arrival actor instead of a delegate-first reveal gate.

The returned object should include at least:

```qml
{
    active: true,
    instanceKey: instanceKey,
    widgetId: widgetId,
    section: section,
    barLeft: slot.left,
    barWidth: slot.width,
    barCenterX: slot.centerX,
    phase: "overlay"
}
```

If a clearer API such as `arrivalActor(instanceKey)` is introduced, keep a compatibility wrapper or update every caller in the same task.

**Step 2: Record the actor snapshot in `addWidget()`**

In `addWidget(widgetId, section)`:

1. append the new model entry with a stable `instanceKey`
2. call `_recomputeGeometryContracts()`
3. resolve the inserted slot from `sectionSlots(section)`
4. when `settingsMode` is active, store the overlay-arrival snapshot for that slot

Do not persist this snapshot to disk.

**Step 3: Add one-shot actor helpers**

Add explicit helpers for the transient actor lifecycle, for example:

```qml
function clearArrivalGeometry(instanceKey) { }
function completeArrivalGeometry(instanceKey) { }
```

`completeArrivalGeometry()` should either clear the snapshot immediately or flip it out of the active overlay phase in one step.

**Step 4: Reconcile stale actor state aggressively**

Make sure `_cleanupStaleGeometryState()` or equivalent cleanup removes snapshots whose `instanceKey` no longer exists in `layoutModel`.

Also clear the arrival snapshot from:

- `resetLayout()`
- `applyJson()`
- `removeWidget()`

If the removed widget is the active actor instance, cleanup must happen in the same code path.

**Step 5: Run the smoke and verify the failure moved forward**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: still FAIL, but now for missing overlay rendering or missing handoff behavior rather than missing service state.

---

### Task 3: Render the overlay arrival actor in `DragOverlay`

**Files:**
- Modify: `modules/bar/DragOverlay.qml`
- Modify: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Tighten the failing smoke around overlay rendering**

Add or update assertions so the smoke proves:

- the arrival actor is rendered from `DragOverlay`
- it uses the inserted widget's source from `widgetRegistry`
- it is positioned from `barLeft` and `barWidth`
- it disappears after handoff

**Step 2: Run the smoke and verify RED**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL because the overlay actor item does not exist yet.

**Step 3: Add a single transient arrival actor item**

In `modules/bar/DragOverlay.qml`:

- add one arrival actor item alongside the existing floating drag copy
- bind it to the active arrival snapshot exposed by `BarLayoutService`
- resolve its component source from `widgetRegistry[snapshot.widgetId]`
- position it from `snapshot.barLeft` and size it from `snapshot.barWidth`

Use the smallest visual treatment that proves the handoff, such as a short fade/scale or an immediate settle using existing `Theme.anim.*` tokens.

**Step 4: Add actor completion -> service handoff**

When the actor finishes its short reveal/settle:

- call the service completion helper
- ensure the overlay actor stops rendering on the next binding tick

If the widget source fails to load, clear the snapshot and fall back to the real delegate path instead of leaving the widget hidden.

**Step 5: Run the smoke and verify the failure moved again**

Run the same smoke command.

Expected: FAIL, but now because the real delegate still reveals too early or does not wait for overlay completion.

---

### Task 4: Gate the real delegate until the overlay handoff completes

**Files:**
- Modify: `modules/bar/BarWidgetWrapper.qml`
- Modify: `tests/qml/BarLayoutGeometrySmoke.qml`
- Modify if needed: `modules/bar/BarSection.qml`

**Step 1: Tighten the failing handoff assertions**

Make `tests/qml/BarLayoutGeometrySmoke.qml` prove the full reveal order:

- while `arrivalGeometry(instanceKey)` is active, the real wrapper is hidden
- when the overlay actor completes, the snapshot is cleared or marked inactive
- only after that does the wrapper run its normal reveal
- the revealed wrapper does not overlap the previously placed left widget

**Step 2: Run the smoke and verify RED**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL because `BarWidgetWrapper.qml` still owns arrival clearing inside `tryStartEnterAnimation()`.

**Step 3: Remove delegate-first arrival ownership**

In `modules/bar/BarWidgetWrapper.qml`:

- stop clearing arrival state based on wrapper `x`/width alignment
- treat an active arrival snapshot as a hard hide gate
- keep width reporting active while hidden so service geometry remains accurate

The wrapper should only ask one question: "Is my overlay-arrival actor still active?"

**Step 4: Start the normal reveal only after service handoff**

Once the arrival snapshot is gone or inactive:

- allow `tryStartEnterAnimation()` to proceed
- keep the existing enter animation rather than introducing a second steady-state path

If `modules/bar/BarSection.qml` contains leftover transition work added only to fight `Row.add` timing, remove or simplify it in the same task.

**Step 5: Run the smoke and verify GREEN**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: PASS.

---

### Task 5: Verify teardown, reset, and adjacent regressions

**Files:**
- Verify: `tests/qml/BarLayoutGeometrySmoke.qml`
- Verify: `services/BarLayoutService.qml`
- Verify: `modules/bar/DragOverlay.qml`
- Verify: `modules/bar/BarWidgetWrapper.qml`
- Verify if touched: `modules/bar/BarSection.qml`

**Step 1: Re-run the targeted geometry smoke**

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: PASS.

**Step 2: Run structural smoke suites**

```bash
bash tests/run-settings-smoke.sh
bash tests/run-ui-structure-smoke.sh
```

Expected: PASS.

**Step 3: Run adjacent regression suites**

```bash
bash tests/run-super-island-smoke.sh
bash tests/run-media-control-smoke.sh
```

Expected: PASS.

**Step 4: Run a full shell load check**

```bash
timeout 10 qs --path .
```

Expected: configuration loads successfully.

**Step 5: Manual sanity checklist**

Verify in live layout mode:

- inserting a widget in the left section no longer flashes at the docking origin
- the first visible frame is the overlay actor already parked in the correct slot
- the handoff to the real delegate is visually clean
- reset, removal, and hot reload do not leave stale hidden widgets or stale overlay actors
- center and right sections still behave as before

**Step 6: Commit only if the user asks**

If the user explicitly requests a commit, stage only the overlay-arrival files and write a concise message describing the service-driven overlay handoff.

---

### Notes for execution

- Prefer updating the existing `arrivalGeometry()` call sites over introducing a brand new parallel API unless the rename materially improves clarity.
- Do not persist arrival actor state; it is runtime-only geometry.
- Do not add timing literals unless they are marked `// FIXME: use Theme.anim.*`.
- Keep the overlay actor path strictly transient; steady-state rendering must remain owned by the normal bar delegate.
