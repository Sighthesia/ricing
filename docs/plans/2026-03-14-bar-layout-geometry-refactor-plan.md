# Bar Layout Geometry Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor bar drag/drop and section layout so all geometry comes from `BarLayoutService`, producing stable insertion, content-adaptive regions, and visually centered center-section behavior.

**Architecture:** Promote `BarLayoutService` from persistence-only state into the runtime geometry source of truth. `BarWidgetWrapper` reports measurements into the service, the service derives section and slot geometry, and `BarContent`, `BarSection`, `DropZone`, and `DragOverlay` render from that shared model instead of reading `Row` positions or equal-third assumptions.

**Tech Stack:** QML, Quickshell, `ListModel`, existing bar modules, smoke harnesses under `tests/qml/`

---

### Task 1: Add geometry-facing smoke coverage

**Files:**
- Modify: `tests/qml/SettingsStructureSmoke.qml`
- Create if needed: `tests/qml/BarLayoutGeometrySmoke.qml`
- Modify if a new harness is added: `tests/run-ui-structure-smoke.sh`

**Step 1: Write the failing test**

Add a smoke harness that instantiates the bar layout stack and asserts the service exposes shared geometry contracts.

Cover at least:
- service exposes a section-geometry lookup API or property
- service exposes slot metadata for a section
- picker anchor geometry comes from service state

Example assertion shape:

```qml
root._assert(typeof BarLayoutService.sectionGeometry === "function"
    || BarLayoutService.sectionGeometries !== undefined,
    "BarLayoutService should expose shared section geometry")
```

**Step 2: Run test to verify it fails**

Run one of:

```bash
timeout 12 qs -p tests/qml/SettingsStructureSmoke.qml
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL because the shared geometry contract does not exist yet.

**Step 3: Keep the new smoke narrow**

Do not assert exact pixel values yet. Only assert presence of the new geometry contract and enough structure to guide the refactor.

**Step 4: Re-run after the contract exists**

Use the same command and expect PASS once the service exposes the first geometry API.

---

### Task 2: Introduce runtime geometry state in `BarLayoutService`

**Files:**
- Modify: `services/BarLayoutService.qml`
- Test: `tests/qml/SettingsStructureSmoke.qml` or `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Add explicit geometry state**

Add service-owned properties for:
- bar metrics such as content width and padding
- measured widget widths keyed by stable instance key
- section geometry output
- slot geometry output
- picker anchors
- drag snapshot state

Prefer named properties and focused helper functions over one giant anonymous object.

**Step 2: Add minimal service API**

Create small helpers such as:

```qml
function setBarMetrics(contentWidth, padding) { }
function setWidgetMeasuredWidth(instanceKey, width) { }
function clearWidgetMeasuredWidth(instanceKey) { }
function sectionGeometry(sectionName) { }
function sectionSlots(sectionName) { }
```

Use guard clauses for invalid input.

**Step 3: Derive geometry from logical layout order**

Implement a first-pass recomputation pipeline that:
- groups enabled widgets by section
- resolves stable order within each section
- assigns measured widths with fallback widths when unknown
- publishes section and slot geometry output

Do not wire drag logic yet; just make the geometry derivation exist and be testable.

**Step 4: Run the targeted smoke**

Run the geometry smoke harness.
Expected: PASS on new geometry structure assertions.

**Step 5: Commit**

```bash
git add services/BarLayoutService.qml tests/qml/SettingsStructureSmoke.qml tests/qml/BarLayoutGeometrySmoke.qml tests/run-ui-structure-smoke.sh
git commit -m "refactor(bar): add shared layout geometry state"
```

Only commit if the user explicitly asks.

---

### Task 3: Move section boundary logic to content-adaptive regions

**Files:**
- Modify: `services/BarLayoutService.qml`
- Modify: `modules/bar/BarContent.qml`
- Test: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Write the failing test**

Add assertions for asymmetric width scenarios.
The test should prove:
- left and right regions are no longer equal thirds
- center region remains visually centered around the bar midpoint
- center interaction width can shrink when side content expands

**Step 2: Run test to verify it fails**

Run:

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: FAIL because section geometry is still synthetic or incomplete.

**Step 3: Implement content-adaptive boundary resolution**

In `BarLayoutService.qml`:
- derive left region from left content width
- derive right region from right content width
- derive center region around bar midpoint
- resolve collisions by shrinking center interaction width before shifting anchors
- clamp all section widths to non-negative values

In `BarContent.qml`:
- replace equal-third hit testing with service-backed section geometry lookups
- replace synthetic picker anchor math with service-backed anchor positions

**Step 4: Run test to verify it passes**

Run the geometry smoke again.
Expected: PASS.

---

### Task 4: Replace insertion-index logic with slot geometry

**Files:**
- Modify: `services/BarLayoutService.qml`
- Modify: `modules/bar/BarSection.qml`
- Test: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Write the failing test**

Add a scenario where neighboring widget widths change and verify insertion index results remain stable for the same logical pointer position.

Example assertion idea:

```qml
root._assert(indexBefore === indexAfter,
    "Insertion index should stay stable when sibling widths change")
```

**Step 2: Run test to verify it fails**

Run the geometry smoke.
Expected: FAIL while `BarSection` still reads transient `Row.children` positions.

**Step 3: Implement minimal code**

In `BarLayoutService.qml`:
- add helper to compute insertion index from derived slots
- exclude the dragged instance when computing drag-time slot targets

In `BarSection.qml`:
- stop using `widgetRow.children` as insertion truth
- render the insertion indicator from service-provided ghost line geometry
- keep widget order rendering in the repeater unless a deeper change proves necessary

**Step 4: Run test to verify it passes**

Run the geometry smoke.
Expected: PASS.

---

### Task 5: Freeze drag geometry in the service during active drag

**Files:**
- Modify: `services/BarLayoutService.qml`
- Modify: `modules/bar/BarWidgetWrapper.qml`
- Modify: `modules/bar/DragOverlay.qml`
- Test: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Write the failing test**

Add assertions that drag state uses a stable dragged width and service-owned ghost geometry.

Cover at least:
- dragged width is captured once at drag start
- floating drag copy width comes from service drag snapshot
- ghost section and index are updated by service computation

**Step 2: Run test to verify it fails**

Run the geometry smoke.
Expected: FAIL because drag geometry still comes partly from wrapper-local state.

**Step 3: Implement minimal code**

In `BarWidgetWrapper.qml`:
- report measured width to the service
- start and stop drag through service helpers
- forward pointer movement instead of directly mutating all drag properties

In `BarLayoutService.qml`:
- add `beginDrag`, `updateDrag`, and `endDrag` style helpers
- freeze dragged width for the active drag session
- publish drag visual and ghost geometry

In `DragOverlay.qml`:
- render the floating copy from service-owned drag geometry
- consume service section geometry for zone placement

**Step 4: Run test to verify it passes**

Run the geometry smoke.
Expected: PASS.

**Step 5: Commit**

```bash
git add services/BarLayoutService.qml modules/bar/BarWidgetWrapper.qml modules/bar/DragOverlay.qml modules/bar/BarSection.qml tests/qml/BarLayoutGeometrySmoke.qml
git commit -m "refactor(bar): unify drag and slot geometry"
```

Only commit if the user explicitly asks.

---

### Task 6: Align drop zones and picker anchoring with shared geometry

**Files:**
- Modify: `modules/bar/DropZone.qml`
- Modify: `modules/bar/DragOverlay.qml`
- Modify: `modules/bar/BarContent.qml`
- Modify: `services/BarLayoutService.qml`
- Test: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Write the failing test**

Add assertions that:
- drop-zone bounds align with service-owned section geometry
- picker anchors align with service-owned section centers
- no zone relies on bar width divided by three

**Step 2: Run test to verify it fails**

Run the geometry smoke.
Expected: FAIL while overlay geometry still uses equal widths.

**Step 3: Implement minimal code**

Update the overlay stack so:
- zone width and x positions come from section geometry
- zone label alignment follows those bounds
- picker positioning uses service anchor output
- any legacy hardcoded third-based math is removed

**Step 4: Run test to verify it passes**

Run the geometry smoke.
Expected: PASS.

---

### Task 7: Add teardown and hot-reload safety for geometry caches

**Files:**
- Modify: `services/BarLayoutService.qml`
- Modify: `modules/bar/BarWidgetWrapper.qml`
- Test: `tests/qml/BarLayoutGeometrySmoke.qml`

**Step 1: Write the failing test**

Simulate widget removal or teardown and assert the service clears stale geometry entries.

**Step 2: Run test to verify it fails**

Run the geometry smoke.
Expected: FAIL if stale width or slot data survives widget removal.

**Step 3: Implement minimal code**

Clear measurement caches when:
- a widget delegate is destroyed
- layout model entries are removed
- drag state references a removed instance

Keep recovery graceful and log concise diagnostics only when needed.

**Step 4: Run test to verify it passes**

Run the geometry smoke.
Expected: PASS.

---

### Task 8: Run full regression verification

**Files:**
- Modify: none unless verification exposes a regression

**Step 1: Run targeted geometry smoke**

```bash
timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml
```

Expected: PASS.

**Step 2: Run existing structural suites**

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

**Step 5: Manual sanity check**

Verify in layout mode:
- insertion line does not jitter while dragging across sections
- center section stays visually centered under asymmetric widths
- edge widgets no longer hug or overflow drop-zone borders
- picker opens beneath the visibly targeted section

---

### Task 9: Prepare git summary only if requested

**Files:**
- Modify: none

**Step 1: Inspect working tree**

Run:

```bash
git status --short
```

**Step 2: If the user asks for commit preparation**

Prepare a summary like:

```text
refactor(bar): unify adaptive layout geometry and drag state
```

Do not create the commit unless the user explicitly asks.
