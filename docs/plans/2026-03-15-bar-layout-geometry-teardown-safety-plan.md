# Bar Layout Geometry Teardown Safety Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make bar geometry and drag caches safe under widget teardown, model removal, and hot reload so no stale runtime geometry survives after an instance disappears.

**Architecture:** Keep the approved dual-guard contract. `BarWidgetWrapper` eagerly clears the last width it reported when a delegate goes away or changes identity, while `BarLayoutService` reconciles all geometry-facing caches against the current `layoutModel` and clears active drag state when the dragged instance disappears.


**Design doc:** `docs/plans/2026-03-15-bar-layout-geometry-teardown-safety-design.md`

---

### Task 1: Lock in delegate-destruction cleanup

**Files:**
- Modify if needed: `modules/bar/BarWidgetWrapper.qml`

**Step 1: Write the failing test**

Add or tighten a teardown probe that creates a temporary `BarWidgetWrapper`, lets it report width for a stable `instanceKey`, destroys it, and then asserts the width cache is gone.

Use an assertion shaped like:

```qml
root._assert(BarLayoutService.measuredWidthForInstance(clockInstanceKey) === 0,
    "BarLayoutService should clear cached widget width when a widget delegate is destroyed")
```

**Step 2: Run test to verify it fails**

Run:

```bash
```

Expected: FAIL because the destroyed delegate still leaves a cached width behind.

If the current branch already passes, strengthen the assertion so it exercises the exact missing behavior instead of skipping the red step.

**Step 3: Write minimal implementation**

Keep `BarWidgetWrapper` as the eager reporter only.
Ensure it clears the last reported key on destruction and before replacing it during `instanceKey` churn.

Minimal implementation shape:

```qml
Component.onDestruction: wrapper.clearReportedMeasuredWidth()
```

and:

```qml
if (wrapper._reportedInstanceKey && wrapper._reportedInstanceKey !== wrapper.instanceKey) {
    BarLayoutService.clearWidgetMeasuredWidth(wrapper._reportedInstanceKey)
}
```

**Step 4: Run test to verify it passes**


**Step 5: Quick self-review**

Confirm `BarWidgetWrapper.qml` still only reports lifecycle events and does not add any private geometry cache.

---

### Task 2: Lock in model-removal and drag cleanup

**Files:**
- Modify: `services/BarLayoutService.qml`

**Step 1: Write the failing test**


- `measuredWidthForInstance(instanceKey) === 0`
- `sectionSlots(sectionName)` no longer contains the removed key
- `dragSnapshot.active === false` when the removed key was the dragged instance

**Step 2: Run test to verify it fails**

Run:

```bash
```

Expected: FAIL because at least one stale cache entry or drag reference survives the removal.

**Step 3: Write minimal implementation**

Implement service-side reconciliation only where the model is authoritative.
Use a helper that derives the active instance-key set from `layoutModel`, drops stale width cache entries, and clears drag state when the active drag key disappears.

Implementation shape:

```qml
function _cleanupStaleGeometryState() {
    let activeInstanceKeys = _layoutInstanceKeySet()
    // drop stale measured widths
    if (draggedInstanceKey && !activeInstanceKeys[draggedInstanceKey]) {
        _clearDragState()
    }
}
```

Call that helper from the geometry recompute path so slot output is rebuilt from the current model only.

**Step 4: Run test to verify it passes**


**Step 5: Quick self-review**

Confirm `services/BarLayoutService.qml` is still the only long-lived owner of geometry state and that cleanup does not mutate unrelated settings state.

---

### Task 3: Lock in hot-reload-style model replacement

**Files:**
- Modify if needed: `services/BarLayoutService.qml`

**Step 1: Write the failing test**

Add a hot-reload-style case that mutates the model wholesale using `resetLayout()` or `applyJson()` after seeding an extra width cache entry and active drag state.

Assert that the replaced-away key no longer exists in:

- `geometryMeasuredWidths`
- `sectionSlots(...)`
- `dragSnapshot`

**Step 2: Run test to verify it fails**

Run:

```bash
```

Expected: FAIL because stale geometry survives model replacement.

**Step 3: Write minimal implementation**

Ensure every model-replacement path re-establishes the same order:

1. mutate `layoutModel`
2. ensure stable `instanceKey` values exist
3. recompute geometry contracts
4. emit `layoutChanged()` only after the service state is coherent

Minimal implementation points:

- `applyJson()`
- `resetLayout()`
- any startup path that falls back to default layout

**Step 4: Run test to verify it passes**


**Step 5: Quick self-review**

Confirm the hot-reload path does not add ad-hoc timers or UI-local recovery code.

---

### Task 4: Run focused and broader verification

**Files:**
- Verify: `services/BarLayoutService.qml`
- Verify: `modules/bar/BarWidgetWrapper.qml`


```bash
```

Expected: PASS.


```bash
```

Expected: PASS.

**Step 3: Run adjacent regression suites**

```bash
```

Expected: PASS.

**Step 4: Run full shell load verification**

```bash
timeout 10 qs --path .
```

Expected: configuration loads successfully.

**Step 5: Commit only if the user asks**

If the user explicitly requests a commit, stage only the Task 7 files and create a concise commit message describing teardown and hot-reload safety for shared bar geometry.
