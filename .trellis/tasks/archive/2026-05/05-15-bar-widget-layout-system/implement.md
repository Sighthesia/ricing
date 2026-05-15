# Implementation Plan: Bar Widget Layout System

## Phase 1: Service Layer Enhancement

### 1.1 Extend BarLayoutService.qml
- [ ] Add `settingsMode` property (bool, default false)
- [ ] Add `toggleSettingsMode()` function
- [ ] Add drag state properties: `isDragging`, `draggedInstanceKey`, `ghostSection`, `ghostIndex`
- [ ] Add `beginDrag(instanceKey)`, `updateDrag(visualCenterX)`, `endDrag()` API
- [ ] Add `removeWidget(instanceKey)` function
- [ ] Add `moveWidget(instanceKey, toSection, toOrder)` function
- [ ] Emit `layoutModelChanged` signal on mutations for view rebinding

### 1.2 Create BarLayoutDrag.js
- [ ] `insertionIndexForPointer(pointerX, widgetCenters)` — binary search for drop index
- [ ] `beginDragState(instanceKey, widgetId)` — returns initial drag state object
- [ ] `updateDragState(visualCenterX, sectionWidgets)` — returns ghost section/index
- [ ] `endDragResult(ghostSection, ghostIndex, draggedInstanceKey)` — returns move params

### 1.3 Extend BarLayoutLayoutModel.js
- [ ] Add `moveWidgetInSection(layoutModel, instanceKey, toOrder)` — reorder within section
- [ ] Add `moveWidgetToSection(layoutModel, instanceKey, toSection, toOrder)` — cross-section move
- [ ] Add `removeWidgetByKey(layoutModel, instanceKey)` — remove and renormalize

**Validation:** Service compiles, `addWidgetToSection` / `removeWidget` / `moveWidget` round-trip correctly with FileView persistence.

## Phase 2: Drag Interaction in BarWidgetWrapper

### 2.1 Add DragHandler to BarWidgetWrapper
- [ ] Gate DragHandler with `Services.BarLayoutService.settingsMode`
- [ ] On drag start: call `BarLayoutService.beginDrag(instanceKey)`
- [ ] On drag move: compute visual center X, call `BarLayoutService.updateDrag(centerX)`
- [ ] On drag end: call `BarLayoutService.endDrag()`
- [ ] Collapse wrapper width to 0 during drag (hide from Row flow)

### 2.2 Visual feedback in settingsMode
- [ ] Show subtle border/outline on each widget when settingsMode is active
- [ ] Change cursor to grab/grabbing during drag
- [ ] Show remove button (X) overlay on each widget

**Validation:** Widgets become draggable in settings mode, visual feedback appears.

## Phase 3: DragOverlay

### 3.1 Create DragOverlay.qml
- [ ] Thin Item overlaying BarContent at z:999
- [ ] Visible only when `BarLayoutService.isDragging`
- [ ] Draw insertion indicator line at computed ghost position
- [ ] Optionally show floating copy of dragged widget (stretch goal)

### 3.2 Wire into BarContent/BarSection
- [ ] Add DragOverlay as child of BarContent (or BarWindow)
- [ ] BarSection exposes section pixel bounds for hit-testing

**Validation:** Insertion indicator appears at correct position during drag.

## Phase 4: Widget Picker Enhancement

### 4.1 Improve WidgetPickerWindow UI
- [ ] Show widget description alongside label
- [ ] Add search/filter TextInput
- [ ] Show instance count badge per widget
- [ ] Close picker after adding widget

### 4.2 Settings mode integration
- [ ] Opening picker auto-enters settingsMode
- [ ] Escape closes picker and exits settingsMode

**Validation:** Picker shows all widgets with metadata, adding works, Escape flow works.

## Phase 5: Integration & Polish

### 5.1 Context menu / toggle entry point
- [ ] WidgetPickerButton toggles settingsMode (or add a dedicated layout-mode button)
- [ ] Escape exits settingsMode globally

### 5.2 Remove widget flow
- [ ] Click X on widget in settingsMode → calls `removeWidget(instanceKey)`
- [ ] Confirm removal for singleton widgets (optional V1)

### 5.3 End-to-end persistence test
- [ ] Add widget → restart → widget persists
- [ ] Reorder → restart → order persists
- [ ] Remove → restart → widget gone
- [ ] Corrupt file → default layout restored

**Validation:** Full user flow works: enter layout mode → add/reorder/remove → exit → changes persist.

## Rollback Points

- Phase 1 is self-contained; if drag proves too complex, the service enhancements still provide remove/move API for future use.
- DragOverlay can be disabled (visible: false) without breaking layout.
- settingsMode can be reverted to always-false to disable editing.
