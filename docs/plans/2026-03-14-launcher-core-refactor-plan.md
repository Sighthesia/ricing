# Launcher Core Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor `modules/launcher/LauncherCore.qml` into smaller internal presentation components while keeping launcher behavior and public integration unchanged.

**Architecture:** Keep `LauncherCore.qml` as the coordinator for provider routing, deferred result swapping, and selection state. Extract a search-header component and a results-list component so input rendering and row rendering stop living in the same file, while `LauncherPanel.qml`, `LauncherService.qml`, and provider interfaces stay unchanged.


---

### Task 1: Add a failing structural assertion for the refactored launcher internals

**Files:**

**Step 1: Write the failing assertion**


Use a pattern like:

```qml
let core = panelLoader.item.contentChildren[1]
root._assert(core !== null, "LauncherPanel should instantiate LauncherCore")
root._assert(core._searchHeader !== null,
    "LauncherCore should expose a dedicated search header component")
root._assert(core._resultsList !== null,
    "LauncherCore should expose a dedicated results list component")
```

Adjust the exact access path to match the real object tree once inspected, but keep the test focused on structural presence rather than behavior.


Run:

```bash
```

Expected: FAIL because the extracted child components do not exist yet.

---

### Task 2: Extract the search header component

**Files:**
- Create: `modules/launcher/LauncherSearchHeader.qml`
- Modify: `modules/launcher/LauncherCore.qml`

**Step 1: Create `LauncherSearchHeader.qml`**

Move the current search-row UI out of `LauncherCore.qml` into a dedicated component that renders:

- the mode badge
- the text field
- the key handlers for up/down/enter/escape

Expose only the small API the parent needs, for example:

- input text property
- focus/open helper
- `textEdited` signal
- `moveSelectionUp` signal
- `moveSelectionDown` signal
- `activateRequested` signal
- `closeRequested` signal

Keep it presentation-focused; do not let it call providers directly.

**Step 2: Wire `LauncherCore.qml` to the new component**

Replace the inline search-row block with `LauncherSearchHeader` and bind its signals back into the existing coordinator functions/state.

Preserve these behaviors exactly:

- open panel sets the text from `LauncherService.prefillText`
- the text field gains focus on open
- typing still schedules `_refreshResults()`
- up/down still moves selection and positions the list view
- return still activates the current item
- escape still closes the launcher


Run:

```bash
```

Expected: still FAIL on the results-list assertion, but the search-header assertion should now pass.

---

### Task 3: Extract the results list component

**Files:**
- Create: `modules/launcher/LauncherResultsList.qml`
- Modify: `modules/launcher/LauncherCore.qml`

**Step 1: Create `LauncherResultsList.qml`**

Move the current `ListView` block and its delegate rendering into a dedicated component.

The component should accept:

- the display model
- selected index
- a callback or signal path for hover selection
- a callback or signal path for activation

Keep list rendering, highlight visuals, and row mouse interaction in this file.

**Step 2: Keep coordinator logic in `LauncherCore.qml`**

Do not move these responsibilities out of the coordinator:

- `_resultData`
- `_pendingDisplayItems`
- `_pendingResultData`
- `_selectedIndex`
- `_refreshResults()`
- `_applyPendingResults()`
- `_activateCurrent()`
- provider ownership

Only update `LauncherCore.qml` so it renders `LauncherResultsList` instead of the inline list block and routes signals to the existing coordinator methods.


Run:

```bash
```


---

### Task 4: Clean up `LauncherCore.qml` ordering and public shape

**Files:**
- Modify: `modules/launcher/LauncherCore.qml`
- Verify: `modules/launcher/LauncherSearchHeader.qml`
- Verify: `modules/launcher/LauncherResultsList.qml`

**Step 1: Normalize file structure**

Reorder `LauncherCore.qml` to follow repo guidance:

1. imports
2. top-level purpose comment
3. root id
4. public mutable properties
5. readonly/private properties
6. signals
7. child declarations
8. functions
9. `Connections`

Keep private names prefixed with `_`.

**Step 2: Keep the new files focused**

Ensure the extracted components stay presentation-focused and avoid duplicate coordinator logic.


Run:

```bash
```

Expected: PASS.

---

### Task 5: Run full verification for the refactor

**Files:**
- Verify: `modules/launcher/LauncherCore.qml`
- Verify: `modules/launcher/LauncherSearchHeader.qml`
- Verify: `modules/launcher/LauncherResultsList.qml`


```bash
```

Expected: PASS.


```bash
```

Expected: PASS.

**Step 3: Run full-shell load check**

```bash
timeout 10 qs --path .
```

Expected: PASS aside from pre-existing environment warnings.
