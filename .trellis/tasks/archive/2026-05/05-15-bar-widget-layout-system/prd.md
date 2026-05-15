# Bar Widget Layout System

## Goal

Implement a complete widget layout management system for the bar, enabling users to select widgets from a picker, reorder them via drag-and-drop, remove widgets, and toggle a dedicated layout editing mode. Reference DymicShell's proven patterns while adapting to afloat's existing architecture (FileView persistence, DockzoneSurfaceRoot rendering).

## Context

afloat already has:
- `BarLayoutService` with `layoutModel`, `availableWidgets`, `addWidgetToSection()`, persistence via `FileView`/`JsonAdapter`
- `BarSection` rendering widgets per section via Repeater
- `WidgetPickerWindow` listing available widgets
- `BarWidgetWrapper` hosting loaded widget content

Missing capabilities (from DymicShell reference):
- Drag-and-drop reorder within and across sections
- Widget removal
- Layout editing mode (settingsMode) with visual feedback
- Richer widget registry with metadata

## Requirements

### R1: Layout Mode Toggle
- A `settingsMode` boolean on `BarLayoutService` that gates editing interactions
- Visual indicator when layout mode is active (section highlights, widget shake/outline)
- Entry via context menu or dedicated button; exit via Escape or toggle

### R2: Widget Picker Enhancement
- Show all registered widgets with label and description
- Filter/search capability
- Insert into the section that triggered the picker open
- Close on widget selection or Escape

### R3: Drag Reorder
- In layout mode, widgets become draggable via long-press or immediate drag
- Visual ghost/indicator at the drop position
- Support reorder within a section and move across sections
- Persist new order immediately after drop

### R4: Widget Removal
- In layout mode, each widget shows a remove affordance (X button or context menu)
- Removal updates the layout model and persists

### R5: Widget Registry
- Centralized widget metadata: `{id, label, description, source, defaultSection}`
- Single source of truth consumed by both BarSection rendering and WidgetPicker
- Extensible for future widgets without touching layout logic

### R6: Persistence
- Layout changes (add, remove, reorder, move) persist to `layout.json` via existing FileView mechanism
- Graceful fallback to default layout on corrupt/missing file

## Constraints

- Must work with Quickshell's Wayland PanelWindow model (no X11 assumptions)
- Preserve existing DockzoneSurfaceRoot animation system
- Keep BarLayoutService as the single shared state owner
- No new external dependencies

## Acceptance Criteria

- [ ] User can enter/exit layout mode via a toggle action
- [ ] In layout mode, widgets show visual editing affordances
- [ ] User can drag a widget to reorder within its section
- [ ] User can drag a widget to move it to a different section
- [ ] Drop position is indicated visually during drag
- [ ] User can remove a widget in layout mode
- [ ] Widget picker shows all registered widgets with metadata
- [ ] Adding a widget inserts it into the target section
- [ ] All layout changes persist across shell restarts
- [ ] Escape key exits layout mode and closes picker
- [ ] Default layout is restored if persistence file is missing/corrupt
