# Implement: Wrapper-Level Local Floating Trigger for Center

## Checklist

### Step 1: Add local wrapper interaction intent
- [ ] update `modules/bar/BarWidgetWrapper.qml` to expose a small local hover / pointer intent signal
- [ ] keep the signal generic and not dockzone-specific

### Step 2: Aggregate intent in the center section
- [ ] update `modules/bar/BarSection.qml` to consume wrapper-level intent for center delegates
- [ ] map any active center wrapper intent into `floatingValidationIntent`
- [ ] keep left/right legacy paths unchanged

### Step 3: Retire the temporary manual trigger path
- [ ] update `modules/bar/BarContent.qml` so it no longer acts as the primary floating trigger owner
- [ ] keep composition simple

### Step 4: Validate
- [ ] run `qmllint` on affected QML files
- [ ] confirm no new service or global state was introduced
- [ ] confirm center attached baseline remains stable when no wrapper is hovered

## Validation

- `qmllint modules/bar/BarWidgetWrapper.qml modules/bar/BarSection.qml modules/bar/BarContent.qml modules/bar/DockzoneSurfaceRoot.qml modules/bar/BarWindow.qml shell.qml`

## Risk Files

- `modules/bar/BarWidgetWrapper.qml`
- `modules/bar/BarSection.qml`
- `modules/bar/BarContent.qml`

## Rollback Points

- after Step 1: remove wrapper-level interaction signal
- after Step 2: restore the prior local validation boolean path

## Review Gate Before Start

- trigger remains local and center-only
- no new service or cross-bar interaction system appears
- downstream floating semantics remain untouched
