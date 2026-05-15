# Implement: Validate Center Floating Semantics via Explicit Local Input

## Checklist

### Step 1: Add the temporary floating validation input
- [ ] update `modules/bar/BarContent.qml` to provide a small center floating validation input
- [ ] pass that input only to the center `BarSection`

### Step 2: Extend center semantic mapping
- [ ] update `modules/bar/BarSection.qml` to map content presence + floating intent into `hidden | attached | floating`
- [ ] keep left/right paths unchanged

### Step 3: Extend owner-local progress drivers
- [ ] update `modules/bar/DockzoneSurfaceRoot.qml` so `floating` becomes a real semantic path
- [ ] add owner-local animated `detachProgress`
- [ ] add owner-local animated `morphProgress`
- [ ] keep progress ownership inside the owner

### Step 4: Extend the pure model helper
- [ ] update `modules/bar/DockzoneSurfaceModel.js` to accept owner-supplied detach / morph progress values
- [ ] derive floating-aware motion and ear-local outputs without adding stateful behavior

### Step 5: Validate
- [ ] run `qmllint` on affected QML files
- [ ] run `node --check` on `DockzoneSurfaceModel.js`
- [ ] confirm attached baseline remains stable in code review

## Validation

- `qmllint modules/bar/DockzoneSurfaceRoot.qml modules/bar/BarSection.qml modules/bar/BarContent.qml modules/bar/BarWindow.qml shell.qml`
- `node --check modules/bar/DockzoneSurfaceModel.js`

## Risk Files

- `modules/bar/BarContent.qml`
- `modules/bar/BarSection.qml`
- `modules/bar/DockzoneSurfaceRoot.qml`
- `modules/bar/DockzoneSurfaceModel.js`

## Rollback Points

- after Step 1: remove the temporary center floating validation input
- after Step 3: collapse owner-local detach / morph progress back to neutral defaults
- after Step 4: revert helper inputs to visibility/state-transition only

## Review Gate Before Start

- trigger remains a local validation input, not hover/click/picker behavior
- scope remains center-only
- left/right and service layers remain untouched
