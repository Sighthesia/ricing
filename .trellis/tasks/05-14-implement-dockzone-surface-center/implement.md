# Implement: First DockzoneSurfaceRoot Center Path

## Checklist

### Step 1: Add the new files
- [ ] create `modules/bar/DockzoneSurfaceRoot.qml`
- [ ] create `modules/bar/DockzoneSurfaceModel.js`

### Step 2: Implement first-pass model derivation
- [ ] define pure normalization / build helpers in `DockzoneSurfaceModel.js`
- [ ] keep the helper stateless
- [ ] produce only the fields needed by the first center validation pass

### Step 3: Wire center path to the new owner
- [ ] update `BarSection.qml` (and related center path call sites if needed)
- [ ] route center dockzone rendering through `DockzoneSurfaceRoot.qml`
- [ ] keep left/right paths unchanged unless a minimal compatibility tweak is required

### Step 4: Validate
- [ ] run `qmllint` on affected QML files
- [ ] review for obvious center visual regressions

## Validation

- `qmllint modules/bar/DockzoneSurfaceRoot.qml modules/bar/BarSection.qml modules/bar/BarContent.qml modules/bar/BarWindow.qml shell.qml`
- if `DockzoneSurfaceModel.js` is imported by QML only, validate by `qmllint` on consuming QML files

## Risk Files

- `modules/bar/BarSection.qml`
- `modules/bar/DockzoneSurfaceRoot.qml`
- `modules/bar/DockzoneSurfaceModel.js`
- `modules/bar/BarDockZoneBackground.qml` if shared shape logic is reused or extracted

## Rollback Points

- after Step 1: delete the new files if the structure proves wrong
- after Step 3: route center rendering back to the previous path if the new owner introduces regressions
