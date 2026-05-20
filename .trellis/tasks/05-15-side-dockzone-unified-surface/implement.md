# Implement: Migrate Side Dockzones into Unified Surface Ownership

## Checklist

### Step 1: Extend section-aware model derivation
- [ ] update `modules/bar/DockzoneSurfaceModel.js` for left/right unified geometry
- [ ] preserve the visible-body vs transparent-container distinction
- [ ] keep helper functions pure and stateless

### Step 2: Extend unified render ownership
- [ ] update `modules/bar/DockzoneSurfaceRoot.qml` so it can render left and right silhouettes
- [ ] absorb side bottom-ear ownership into the same owner tree
- [ ] keep center behavior stable

### Step 3: Route side sections through the unified owner
- [ ] update `modules/bar/BarSection.qml` so left/right stop using `BarDockZoneBackground.qml` as the primary owner
- [ ] preserve section-specific semantics and content placement

### Step 4: Remove overlay workaround
- [ ] stop composing `modules/bar/BarBottomEarWindow.qml` in active rendering flow
- [ ] delete or retire the module only if the migration is stable within this task

### Step 5: Adjust container sizing
- [ ] update `modules/bar/BarWindow.qml` and/or `modules/bar/BarContent.qml` only as needed to allow a larger transparent geometry container
- [ ] keep visible body alignment at `barHeight`

### Step 6: Validate
- [ ] run `qmllint` on affected QML files
- [ ] run `node --check` on `DockzoneSurfaceModel.js`
- [ ] confirm left/right still render with broadly correct silhouettes

## Validation

- `qmllint modules/bar/BarWindow.qml modules/bar/BarContent.qml modules/bar/BarSection.qml modules/bar/DockzoneSurfaceRoot.qml shell.qml`
- `node --check modules/bar/DockzoneSurfaceModel.js`

## Risk Files

- `modules/bar/BarWindow.qml`
- `modules/bar/BarContent.qml`
- `modules/bar/BarSection.qml`
- `modules/bar/DockzoneSurfaceRoot.qml`
- `modules/bar/DockzoneSurfaceModel.js`
- `modules/bar/BarBottomEarWindow.qml`

## Rollback Points

- after Step 2: revert root/model side rendering and keep legacy side path
- after Step 3: restore legacy left/right routing in `BarSection.qml`
- after Step 4: temporarily re-enable `BarBottomEarWindow.qml`
- after Step 5: collapse the main bar window back to `barHeight`

## Review Gate Before Start

- side migration remains architecture-first, not full polish
- overlay workaround is removed in the same task by explicit choice
- larger transparent geometry container is allowed, but visible bar body height still reads as `barHeight`
