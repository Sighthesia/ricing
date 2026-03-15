# Bar Layout Overlay Arrival Serial Reveal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Finish the overlay-arrival work by making same-section delegate reveal happen in strict service-owned serial order after overlay actors complete.

**Architecture:** Keep overlay actors in `DragOverlay.qml` as the first visible frame and keep `BarWidgetWrapper.qml` as the steady-state owner. Add a small service-owned baton contract in `BarLayoutService.qml` so overlay actors mark instances ready, the service releases one delegate at a time per section, and wrappers notify the service when their enter animation finishes.

**Tech Stack:** QML, Quickshell, `ListModel`, smoke harnesses under `tests/qml/`

**Design doc:** `docs/plans/2026-03-15-bar-layout-overlay-arrival-serial-reveal-design.md`

---

### Task 1: Lock the smoke to serial reveal semantics

**Files:**
- Modify: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Write the failing serial-order assertions**

Update the arrival handoff section so it asserts:

- both inserted instances may have overlay actors initially
- the later wrapper stays hidden after its actor is ready if an earlier wrapper still owns the reveal baton
- the first wrapper begins reveal before the second wrapper begins reveal
- the second wrapper reveals only after the first wrapper finishes enter

**Step 2: Run test to verify it fails**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL because the current implementation still allows same-section handoff timing that does not satisfy the new serial contract.

**Step 3: Keep the test structural**

Assert ordering and overlap behavior only.
Do not assert exact frame counts or animation curves.

---

### Task 2: Add a per-section reveal baton in the service

**Files:**
- Modify: `services/BarLayoutService.qml`
- Test: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Add transient baton state**

Add a runtime-only store representing which instance currently owns delegate reveal per section.

Suggested shape:

```qml
property var _arrivalRevealLocks: ({})
```

**Step 2: Add explicit baton helpers**

Add helpers with service-owned semantics, such as:

```qml
function requestArrivalReveal(instanceKey) { }
function finishArrivalReveal(instanceKey) { }
function _tryReleaseArrivalForSection(sectionName) { }
```

`requestArrivalReveal()` should mark the instance ready and attempt release.
`finishArrivalReveal()` should clear the current section baton and advance the queue.

**Step 3: Order by service slot order**

When releasing the next instance, derive order from `sectionSlots(section)` or equivalent service-owned slot ordering.
Do not infer ordering from delegate creation order.

**Step 4: Clear baton state during cleanup**

Clear reveal-lock state when:

- `resetLayout()` runs
- `applyJson()` runs
- `removeWidget()` removes the current holder
- stale instance cleanup removes an instance key

**Step 5: Run the smoke to verify the failure moves forward**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: still FAIL, but now because `DragOverlay` and `BarWidgetWrapper` do not yet fully honor the baton contract.

---

### Task 3: Make overlay actors request release instead of clearing themselves

**Files:**
- Modify: `modules/bar/DragOverlay.qml`
- Modify: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Keep stable keyed actor lifecycle**

Preserve the stable `instanceKey`-owned actor lifecycle so actor destruction is not driven by `Repeater` index churn.

**Step 2: Change actor completion behavior**

When an overlay actor completes:

- mark the actor instance ready through the service
- do not directly clear the arrival snapshot
- let the service decide whether the baton may move now

**Step 3: Run the smoke to verify RED**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL because wrappers still need to wait for explicit release and notify completion.

---

### Task 4: Gate wrappers on baton release and completion

**Files:**
- Modify: `modules/bar/BarWidgetWrapper.qml`
- Modify: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Add explicit delegate-release permission**

Make `BarWidgetWrapper.qml` reveal only when:

- overlay phase for that instance is no longer active
- the service has released delegate reveal for that instance, or no serial-arrival baton applies

**Step 2: Notify the service when enter finishes**

At the end of the wrapper's normal enter animation:

- call the service completion helper for the wrapper instance
- allow the service to release the next ready instance in that section

**Step 3: Keep width reporting unchanged**

Do not regress runtime width reporting, teardown cleanup, or replacement-delegate reporting behavior.

**Step 4: Run the smoke to verify GREEN**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: PASS.

---

### Task 5: Run full verification

**Files:**
- Verify: `tests/qml/BarLayoutGeometrySmoke.qml`
- Verify: `services/BarLayoutService.qml`
- Verify: `modules/bar/DragOverlay.qml`
- Verify: `modules/bar/BarWidgetWrapper.qml`
- Verify if touched: `modules/bar/BarSection.qml`

**Step 1: Run targeted geometry smoke**

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: PASS.

**Step 2: Run UI structure suite**

```bash
bash tests/run-ui-structure-smoke.sh
```

Expected: PASS.

**Step 3: Run adjacent suites**

```bash
bash tests/run-settings-smoke.sh
bash tests/run-super-island-smoke.sh
bash tests/run-media-control-smoke.sh
```

Expected: PASS.

**Step 4: Run full shell load**

```bash
timeout 10 qs --path .
```

Expected: configuration loads successfully.

**Step 5: Commit only if the user asks**

If the user explicitly asks for a commit, stage only the serial-reveal implementation files and write a concise message describing service-owned serial handoff for overlay-arrival delegates.
