# Bar Layout Slot-Driven Arrival Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure a widget inserted in layout mode becomes visible only when it has actually reached the service-owned target slot, eliminating the transient overlap at the docking origin.

**Architecture:** Add a one-shot arrival snapshot to `BarLayoutService` for new layout-mode insertions. `BarWidgetWrapper` reads that snapshot, compares its actual bar-space geometry against the target slot, and only starts its enter animation once the delegate is truly in place; then the snapshot is cleared and normal layout resumes.

**Tech Stack:** QML, Quickshell, `ListModel`, smoke harnesses under `tests/qml/`

**Design doc:** `docs/plans/2026-03-15-bar-layout-slot-driven-arrival-design.md`

---

### Task 1: Lock in a failing arrival snapshot smoke

**Files:**
- Modify: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Write the failing test**

Extend the current arrival regression so it checks service-owned arrival state instead of only raw `Row.add` behavior.

Cover at least:

- `BarLayoutService` exposes an arrival helper such as `arrivalGeometry(instanceKey)`
- the newly inserted left-section widget has an active arrival snapshot
- the wrapper is still hidden before its actual bar-space geometry matches the target slot
- the first visible frame does not overlap the previous left-section widget

Example assertion shape:

```qml
root._assert(arrival !== null && arrival.active,
    "BarLayoutService should publish one-shot arrival geometry for the newly inserted widget")
```

and later:

```qml
root._assert(secondWrapper.opacity <= 0.01,
    "Inserted widget should remain hidden until it reaches the service-owned arrival slot")
```

**Step 2: Run test to verify it fails**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL because the service does not yet expose arrival geometry and the wrapper still becomes visible while positioned at the docking origin.

**Step 3: Keep the test structural**

Do not assert the animation curve.
Assert slot alignment, visibility gating, and non-overlap only.

**Step 4: Re-run after the first contract exists**

Use the same command and expect the failure to move from missing API to missing wrapper consumption.

---

### Task 2: Add one-shot arrival geometry to `BarLayoutService`

**Files:**
- Modify: `services/BarLayoutService.qml`
- Test: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Add transient arrival state**

Introduce a small service-owned runtime store such as:

```qml
property var _arrivalGeometries: ({})
```

and public helpers such as:

```qml
function arrivalGeometry(instanceKey) { }
function clearArrivalGeometry(instanceKey) { }
```

Return a stable empty object or `null` for missing keys.

**Step 2: Record arrival geometry after insertion**

In `addWidget()`:

1. append the new item and stable `instanceKey`
2. recompute geometry contracts
3. look up the new item's slot from `sectionSlots(section)`
4. store a one-shot arrival snapshot for that `instanceKey` when layout mode is active

The stored geometry should be in bar coordinates, not row-local coordinates.

**Step 3: Reconcile stale arrival state**

Extend the existing stale-geometry cleanup path so arrival snapshots disappear when the instance no longer exists in `layoutModel`.

Also clear arrival state from:

- `resetLayout()`
- `applyJson()`
- `removeWidget()` when applicable

**Step 4: Run the targeted smoke**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: still FAIL because the wrapper has not yet started consuming the arrival snapshot.

**Step 5: Quick self-review**

Confirm arrival geometry remains transient runtime state and does not affect persistence.

---

### Task 3: Consume service-owned arrival geometry in `BarWidgetWrapper`

**Files:**
- Modify: `modules/bar/BarWidgetWrapper.qml`
- Modify if needed: `modules/bar/BarSection.qml`
- Modify: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Write or tighten the failing assertions**

Ensure the smoke now checks the full reveal gate:

- before slot alignment: wrapper remains hidden
- after slot alignment: wrapper becomes visible
- on first visible frame: wrapper does not overlap the prior left-section widget
- after reveal: arrival snapshot is cleared

**Step 2: Run test to verify it fails**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL because the wrapper still starts its enter animation before slot alignment.

**Step 3: Write minimal implementation**

In `BarWidgetWrapper.qml`:

- add a helper that fetches `BarLayoutService.arrivalGeometry(wrapper.instanceKey)`
- map the wrapper's current left edge into `BarContent` coordinates using `findBarContent()` and `mapToItem(...)`
- treat the wrapper as arrival-gated only while an active arrival snapshot exists
- do not start the enter animation until the actual bar-space left and width are close to the arrival snapshot values
- once aligned, clear the arrival snapshot and run the existing enter animation

Suggested readiness shape:

```qml
function _arrivalReady(arrival, barContent) {
    let actualLeft = wrapper.mapToItem(barContent, 0, 0).x
    return Math.abs(actualLeft - arrival.barLeft) <= 0.5
}
```

If width mismatch also proves relevant, include width tolerance too.

Only touch `BarSection.qml` if you need to remove an earlier transition-only workaround that is no longer necessary.

**Step 4: Run test to verify it passes**

Run the geometry smoke again.
Expected: PASS.

**Step 5: Quick self-review**

Confirm the wrapper still uses service geometry as truth and does not introduce a second long-lived layout cache.

---

### Task 4: Run focused and broader verification

**Files:**
- Verify: `tests/qml/BarLayoutGeometrySmoke.qml`
- Verify: `services/BarLayoutService.qml`
- Verify: `modules/bar/BarWidgetWrapper.qml`
- Verify if touched: `modules/bar/BarSection.qml`

**Step 1: Run targeted geometry smoke**

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

**Step 4: Run full shell load verification**

```bash
timeout 10 qs --path .
```

Expected: configuration loads successfully.

**Step 5: Manual sanity checklist**

Verify in live layout mode:

- inserting a widget into the left docking region no longer shows a transient overlap at the docking origin
- the new widget's first visible frame is already in its final slot
- center and right sections still behave the same as before
- picker insertion still targets the expected section

**Step 6: Commit only if the user asks**

If the user explicitly requests a commit, stage only the slot-arrival files and create a concise commit message describing service-driven first-frame slot alignment for layout-mode insertion.
