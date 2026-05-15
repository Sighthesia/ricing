# Design: Bar Widget Layout System

## Architecture Overview

The system follows a **Service-owns-state, View-reads-state** pattern. `BarLayoutService` is the single source of truth for layout model, editing mode, and drag state. Views (`BarSection`, `WidgetPickerWindow`, `DragOverlay`) read from the service and dispatch mutations back through its API.

```
┌─────────────────────────────────────────────────────┐
│ BarLayoutService (singleton)                         │
│  - layoutModel (normalized widget list)             │
│  - settingsMode, widgetPickerVisible                │
│  - drag state (isDragging, ghostSection, ghostIndex)│
│  - persistence (FileView + JsonAdapter)             │
├─────────────────────────────────────────────────────┤
│ Mutations (JS library)                              │
│  - addWidget, removeWidget, moveWidget, reorder     │
├─────────────────────────────────────────────────────┤
│ Drag Logic (JS library)                             │
│  - insertionIndexForPointer, beginDrag, endDrag     │
└─────────────────────────────────────────────────────┘
         ▲ read            ▲ dispatch
         │                 │
┌────────┴────────┐  ┌────┴──────────────┐
│ BarSection      │  │ BarWidgetWrapper   │
│ (Repeater)      │  │ (DragHandler)      │
└─────────────────┘  └───────────────────┘
         ▲                      ▲
┌────────┴────────┐  ┌─────────┴─────────┐
│ WidgetPicker    │  │ DragOverlay        │
│ Window          │  │ (ghost + indicator)│
└─────────────────┘  └───────────────────┘
```

## Data Model

### Layout Model Entry
```json
{
  "id": "placeholder",
  "section": "center",
  "order": 0,
  "enabled": true,
  "instanceKey": "placeholder:0",
  "source": "../../modules/bar/widgets/Placeholder.qml"
}
```

### Widget Registry Entry (in BarLayoutLayoutModel.js)
```js
{
  id: "placeholder",
  label: "Placeholder",
  description: "Center placeholder widget.",
  section: "center",        // default section for picker
  source: "../../modules/bar/widgets/Placeholder.qml"
}
```

## Key Design Decisions

### D1: Simplified Drag (vs DymicShell's geometry pipeline)

DymicShell has a complex geometry pipeline with slot-based positioning, arrival animations, and per-pixel geometry contracts. afloat uses a simpler Row-based layout inside DockzoneSurfaceRoot. 

**Decision:** Use a lightweight drag approach:
- Track drag state on BarLayoutService (isDragging, draggedInstanceKey, ghostSection, ghostIndex)
- BarWidgetWrapper gets a DragHandler that reports visual center X to the service
- Service computes insertion index from widget order positions
- On drop, call `moveWidget()` which reorders and persists
- A thin DragOverlay shows the insertion indicator line

### D2: Persistence via existing FileView

Keep the current `FileView` + `JsonAdapter` pattern. Mutations call `saveLayoutModel()` which writes through the adapter. No separate PersistenceBridge needed (unlike DymicShell which uses Process-based IO).

### D3: settingsMode as layout editing gate

All destructive/reorder operations require `settingsMode === true`. This prevents accidental drag during normal use. The mode is toggled via the existing WidgetPickerButton or a future context menu entry.

### D4: Widget Registry as JS constant

Keep the registry in `BarLayoutLayoutModel.js` as `AVAILABLE_WIDGETS` array (already exists). Both the picker and the section renderer resolve source paths from this registry. No separate WidgetConfigService needed for V1.

## Module Boundaries

| File | Responsibility |
|------|---------------|
| `services/BarLayoutService.qml` | State owner, API facade, persistence |
| `services/barlayout/BarLayoutLayoutModel.js` | Widget registry, model normalize/query/mutate |
| `services/barlayout/BarLayoutDrag.js` | **NEW** — Pure drag math (insertion index, ghost state) |
| `services/barlayout/BarLayoutSections.js` | Section width calculation |
| `modules/bar/BarSection.qml` | Section rendering with Repeater |
| `modules/bar/BarWidgetWrapper.qml` | Widget host + DragHandler (in settingsMode) |
| `modules/bar/DragOverlay.qml` | **NEW** — Insertion indicator overlay |
| `modules/bar/WidgetPickerWindow.qml` | Widget selection panel |

## Compatibility

- DockzoneSurfaceRoot continues to own visual rendering (body, ears, animations)
- Row-based layout inside DockzoneSurfaceRoot is preserved; drag just reorders model entries
- FileView persistence format stays backward-compatible (version: 1, widgets array)

## Tradeoffs

| Choice | Gains | Costs |
|--------|-------|-------|
| Row layout (not slot geometry) | Simple, leverage Qt Row | No per-pixel control during drag animation |
| settingsMode gate | Prevents accidental edits | Extra toggle step for users |
| No arrival animations V1 | Simpler implementation | Less polished add-widget feel |
