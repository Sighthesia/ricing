# Implement: Center Surface Visibility and Attachment Progress Drivers

## Checklist

### Step 1: Update task context and state boundary
- [ ] confirm center path remains the only migrated surface path
- [ ] keep shell-wide layout state out of `BarLayoutService.qml`

### Step 2: Extend the pure model helper
- [ ] update `modules/bar/DockzoneSurfaceModel.js` to accept owner-supplied canonical driver values
- [ ] keep all derivation functions pure and stateless
- [ ] preserve neutral `morphProgress` and `detachProgress` defaults

### Step 3: Add owner-local animated progress drivers
- [ ] update `modules/bar/DockzoneSurfaceRoot.qml` to own animated `visibilityProgress`
- [ ] update `modules/bar/DockzoneSurfaceRoot.qml` to own animated `stateTransitionProgress`
- [ ] derive root-level opacity / scale / translation from those drivers
- [ ] keep body and ears under the same global motion envelope

### Step 4: Wire semantic state into the center path
- [ ] update `modules/bar/BarSection.qml` only if needed to pass semantic `surfaceState`
- [ ] keep left/right legacy path untouched
- [ ] ensure stable `attached` visuals remain equivalent to the current center appearance

### Step 5: Validate
- [ ] run `qmllint` on affected QML files
- [ ] run JS syntax validation on `DockzoneSurfaceModel.js`
- [ ] manually inspect for obvious binding loops or invalid transitions in the code

## Validation

- `qmllint modules/bar/DockzoneSurfaceRoot.qml modules/bar/BarSection.qml modules/bar/BarContent.qml modules/bar/BarWindow.qml shell.qml`
- `node --check modules/bar/DockzoneSurfaceModel.js`

## Risk Files

- `modules/bar/DockzoneSurfaceRoot.qml`
- `modules/bar/DockzoneSurfaceModel.js`
- `modules/bar/BarSection.qml` if semantic state routing changes

## Rollback Points

- after Step 2: revert helper inputs to static placeholder progress values
- after Step 3: collapse root motion bindings back to stable attached semantics
- after Step 4: remove any new center `surfaceState` plumbing if it causes churn beyond this task

## Review Gate Before Start

- planning artifacts match the agreed limited scope: visibility/attachment only
- no floating/detach/morph behavior is required in this task
- sub-agent manifests include the contract spec and relevant frontend guidelines
