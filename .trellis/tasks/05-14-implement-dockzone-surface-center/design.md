# Design: First Center Dockzone Integration of DockzoneSurfaceRoot

## Architecture

Add the first concrete surface-local owner and helper pair:

```text
modules/bar/
├── BarWindow.qml
├── BarContent.qml
├── BarSection.qml
├── BarDockZoneBackground.qml
├── DockzoneSurfaceRoot.qml      # new
└── DockzoneSurfaceModel.js      # new
```

The center path becomes:

```text
BarContent
└── BarSection (center)
   └── DockzoneSurfaceRoot
      ├── consumes semantic inputs
      ├── builds surface model via DockzoneSurfaceModel.js
      └── renders current center body + top ears + content region
```

## Boundaries

### `DockzoneSurfaceRoot.qml`

- owns the center surface-local structural state
- exposes only high-level semantic inputs from `BarSection`
- calls `DockzoneSurfaceModel.js` to derive a stable model object
- renders the current center dockzone shape and content region

### `DockzoneSurfaceModel.js`

- pure functions only
- normalizes semantic inputs
- builds contract-shaped model data
- derives geometry and content-region values
- no lifecycle ownership, no mutable runtime state

### Existing files

- `BarSection.qml` should switch only the center path to the new owner
- `BarDockZoneBackground.qml` may remain temporarily for left/right or for shared shape extraction, depending on what minimizes churn
- `BarLayoutService.qml` remains unchanged as a shell-wide input source

## Inputs

Recommended first-pass public inputs for `DockzoneSurfaceRoot.qml`:

- `section`
- `screenName`
- `surfaceState`
- `surfaceHeight`
- `contentWidth`
- `contentHeight`

Optional if needed by the first pass:

- `layoutInputs`

## Trade-offs

- Benefit: validates owner/model boundary with the lowest-risk center path
- Benefit: keeps left/right edge-specific complexity out of the first pass
- Cost: shape logic may temporarily exist in both new and old structures until later migration

## Validation Strategy

Success for this task is not a full visual redesign.

Success means:

- the center dockzone is owned by the new surface root
- the model helper is actually used
- the visual result does not obviously regress
- the next task can expand the same structure to left/right paths
