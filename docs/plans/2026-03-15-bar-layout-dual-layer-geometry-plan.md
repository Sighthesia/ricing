# Bar Layout Dual-Layer Geometry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make layout mode treat left, center, and right as full-width docking regions while keeping adaptive widget content placement inside those regions and eliminating the transient centered-overlap effect for inserted widgets.

**Architecture:** Keep `BarLayoutService` as the single geometry source of truth, but split each section into a full contiguous frame and an inner visual content band. `BarContent`, `BarSection`, `DragOverlay`, and `DropZone` consume frame geometry for outer layout and hit areas, while slot math and widget rendering continue to use visual geometry inside the frame.

**Tech Stack:** QML, Quickshell, `ListModel`, smoke harnesses under `tests/qml/`

**Design doc:** `docs/plans/2026-03-15-bar-layout-dual-layer-geometry-design.md`

---

### Task 1: Lock in full-width frame expectations

**Files:**
- Modify: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Write the failing test**

Add assertions that prove section frames are contiguous and cover the full usable width.

Cover at least:

- `left.right === center.left`
- `center.right === right.left`
- `left.left === bar padding`
- `right.right === bar width - bar padding`
- rendered left and right `BarSection` widths follow `sectionGeometry(section).width`

Example assertion shape:

```qml
root._assert(root._approxEqual(leftGeometry.right, centerGeometry.left, 0.5),
    "BarLayoutService should make left and center frames meet without a gap")
```

**Step 2: Run test to verify it fails**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL because the current section geometry leaves frame gaps and the rendered `BarSection` items are still content-sized.

**Step 3: Keep the test focused**

Do not test animation yet.
Only lock in the new frame contract and the rendered outer-section sizing.

**Step 4: Re-run after the contract exists**

Use the same command and expect PASS once the service and section containers publish the full-width frame behavior.

---

### Task 2: Publish contiguous section frames in `BarLayoutService`

**Files:**
- Modify: `services/BarLayoutService.qml`
- Test: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Implement frame geometry separately from visual geometry**

Keep `visualLeft` and `visualWidth` adaptive, but redefine the outer section frame so the three sections cover the whole usable bar width contiguously.

Minimal implementation direction:

```qml
left: usableBounds.left -> centerLeft
center: centerLeft -> centerRight
right: centerRight -> usableBounds.right
```

while visual placement still comes from `_resolveVisualPlacement(...)`.

**Step 2: Keep slot math anchored to the visual band**

Do not move `_slotGeometryOutput(...)` away from `visualLeft`.
Slots should still represent where widgets actually line up inside the frame.

**Step 3: Run the targeted smoke**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: still FAIL or partially pass until `BarContent` and `BarSection` consume the wider frame geometry.

**Step 4: Review for invariants**

Confirm these rules remain true:

- no negative section width
- center visual midpoint remains anchored to the bar midpoint
- picker anchors still derive from section geometry consistently

---

### Task 3: Consume frame geometry in `BarContent` and `BarSection`

**Files:**
- Modify: `modules/bar/BarContent.qml`
- Modify: `modules/bar/BarSection.qml`
- Modify: `services/BarLayoutService.qml`
- Test: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Write or tighten the failing assertions**

Extend the smoke if needed so it proves:

- left, center, and right `BarSection` items use frame `x` and `width`
- the internal widget row is offset by `visualLeft - left`
- insertion indicator local coordinates are relative to the frame, not the visual band origin

**Step 2: Run test to verify it fails**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL while `BarSection` still sizes itself from `widgetRow.implicitWidth` and insertion helpers still treat local coordinates as if the section starts at `visualLeft`.

**Step 3: Write minimal implementation**

In `BarContent.qml`:

- bind each `BarSection` `x` to `sectionGeometry(section).left`
- bind each `BarSection` `width` to `sectionGeometry(section).width`

In `BarSection.qml`:

- stop using outer section width as an implicit content proxy
- keep `widgetRow` inside the section and offset it from the frame origin to the visual band origin

In `BarLayoutService.qml`:

- update `insertionIndexForSectionX()` to use `geometry.left + localX`
- update `insertionIndicatorGeometry()` so `sectionLocalX` is returned relative to `geometry.left`

**Step 4: Run test to verify it passes**

Run the same geometry smoke again.
Expected: PASS for frame coverage and insertion-alignment assertions.

**Step 5: Quick self-review**

Confirm `modules/bar/` still consume service geometry rather than recomputing widths locally.

---

### Task 4: Lock in stable arrival behavior for inserted widgets

**Files:**
- Modify: `tests/qml/BarLayoutGeometrySmoke.qml`
- Modify if needed: `modules/bar/BarWidgetWrapper.qml`
- Modify if needed: `modules/bar/BarSection.qml`

**Step 1: Write the failing test**

Add a layout-mode scenario that inserts or moves a widget into the left section and checks that the arriving delegate does not start from a centered overlap state.

Prefer a structural assertion over a visual guess, for example:

- find the first and second left-section wrappers after insertion
- assert the second wrapper's initial `x` is not near the section midpoint
- assert the second wrapper starts at or after the first wrapper's rendered right edge, within tolerance

Example assertion shape:

```qml
root._assert(secondWrapper.x + 0.5 >= firstWrapper.x + firstWrapper.width,
    "Inserted widget should not begin by overlapping the previous left-section widget")
```

**Step 2: Run test to verify it fails**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL if the arriving widget still expands from a centered docking point or from an ambiguous content-sized parent.

**Step 3: Write minimal implementation**

Fix the arrival behavior with the smallest change that matches the new frame model.

Preferred order:

1. rely on the widened section frame and visual-row offset first
2. if overlap still occurs, suppress only the first width animation for layout-mode arrivals so the delegate lands at its final slot width immediately while keeping enter opacity/scale motion

Keep drag-time width collapse/expand behavior untouched unless the smoke proves it is the actual cause.

**Step 4: Run test to verify it passes**

Run the same geometry smoke again.
Expected: PASS.

**Step 5: Quick self-review**

Confirm the fix does not introduce a new private geometry cache or hardcoded timing literal.

---

### Task 5: Run focused and broader verification

**Files:**
- Verify: `tests/qml/BarLayoutGeometrySmoke.qml`
- Verify: `services/BarLayoutService.qml`
- Verify: `modules/bar/BarContent.qml`
- Verify: `modules/bar/BarSection.qml`
- Verify: `modules/bar/BarWidgetWrapper.qml`
- Verify: `modules/bar/DragOverlay.qml`

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

- the three docking regions cover the full bar width
- center content still appears visually centered under asymmetric widths
- inserting or moving a widget to the right of a left-section widget no longer starts with visible overlap
- picker still opens beneath the expected targeted section

**Step 6: Commit only if the user asks**

If the user explicitly requests a commit, stage only the dual-layer geometry files and create a concise commit message describing full-width section frames and stable arrival behavior in layout mode.
