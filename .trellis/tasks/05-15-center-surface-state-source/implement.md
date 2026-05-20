# Implement: Map Center Surface State from Content Presence

## Checklist

### Step 1: Add the local semantic mapping
- [ ] update `modules/bar/BarSection.qml` to compute a center content-presence flag from `sectionModel`
- [ ] map that flag to a semantic `surfaceState` string for the center path only

### Step 2: Preserve existing ownership boundaries
- [ ] keep progress animation ownership in `DockzoneSurfaceRoot.qml`
- [ ] avoid changes to `BarLayoutService.qml`
- [ ] keep left/right legacy paths unchanged

### Step 3: Validate
- [ ] run `qmllint` on affected QML files
- [ ] ensure there are no binding loops or invalid references introduced by the new mapping

## Validation

- `qmllint modules/bar/DockzoneSurfaceRoot.qml modules/bar/BarSection.qml modules/bar/BarContent.qml modules/bar/BarWindow.qml shell.qml`

## Risk Files

- `modules/bar/BarSection.qml`

## Rollback Points

- after Step 1: revert the center semantic mapping to hardcoded `surfaceState: "attached"`

## Review Gate Before Start

- scope remains center-only
- semantic source remains content presence, not widget-picker visibility
- no new service or feature helper is introduced unless implementation reveals a concrete need
