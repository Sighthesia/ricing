---
name: shared-summary-model-delegates
description: Use when repeated UI delegates should render per-item derived state, but the view keeps collapsing to one active item because each delegate recomputes data through local lookups instead of consuming a shared summary model.
---

# Shared Summary Model Delegates

Keep repeated overview rendering driven by one shared summary model, not by per-delegate lookup helpers.

## A. The Generic Pattern / Methodology

| Item | Guidance |
| --- | --- |
| Core Concept | Derive collection summaries once in shared state, then pass each delegate a stable row payload. |
| Universal Checklist | 1. Build one summary list near the service boundary. 2. Include identity, active state, and per-item derived payload in each row. 3. Bind repeaters directly to that summary model. 4. Pass delegates the row object instead of asking them to look themselves up again. 5. Remove helper lookups that implicitly depend on global active state. |

## B. The Specific Trap / Symptom (The Trigger)

| Context | Summary |
| --- | --- |
| Workspace overview in DymicShell | Non-active workspaces kept showing active-workspace content because delegates were deriving state through helper lookups tied too closely to global active workspace data instead of receiving stable per-workspace summaries. |

## C. The Anti-Pattern vs. Best Practice

| Pattern | Explanation |
| --- | --- |
| ❌ The Anti-Pattern (Why it failed) | Let each delegate recompute its own membership or content through `parent` lookups, helper functions, or narrow active-state caches. |
| ✅ The Best Practice (The Fix) | Build a shared summary model once and make each delegate render only its own row payload. |

## D. Generalizable Rules (Highly Portable)

### Agnostic Rules

- Derive repeated view summaries once, near the data source.
- Delegates should render, not rediscover, their own item membership.
- If only the active item is correct, suspect the binding path before the raw model.
- Shared summary rows should carry enough data that delegates do not need back-channels to parent state.

### Warning Signs

- Every delegate appears to read the same list.
- Moving logic into helpers does not fix stale non-active items.
- The raw source model is correct but repeated UI still collapses to one active item.

## E. Universal Verification Strategy

### Agnostic Testing Logic

1. Switch active items and confirm inactive delegates keep their own derived content.
2. Verify the summary model changes per row, not just globally.
3. If a delegate cannot render without helper lookups back into parent state, the model is probably too narrow.
4. Run `timeout 5 qs --path .` after changes.

## References
- `services/NiriService.qml`
- `services/WindowHintService.qml`
- `modules/bar/widgets/WorkspaceWidget.qml`
- `modules/bar/widgets/WorkspaceOverviewPill.qml`
