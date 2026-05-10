# Research: dynamic-island-shape

- **Query**: Locate the dynamic island implementation in the sibling project and describe the files/components that define the outer shape, edge-attached curved decorations, and dock zone geometry.
- **Scope**: internal
- **Date**: 2026-05-10

## Findings

### Files Found

| File Path | Description |
|---|---|
| `Modules/DynamicIsland/DynamicIsland.qml` | Main island window; builds the outer shape, masks, ears, and detached record dock zone. |
| `Modules/DynamicIsland/Hub/HubContent.qml` | Inner hub content whose implicit size drives the island expansion when the hub is shown. |
| `shell.qml` | Instantiates `DynamicIsland {}` so the module is active in the shell. |

### Code Patterns

- The island is defined as a `PanelWindow` in `Modules/DynamicIsland/DynamicIsland.qml:23-40`, with `anchors.top/left/right` and `exclusiveZone: -1`.
- The main body shape is the `root` item inside `maskContainer` (`DynamicIsland.qml:203-324`). Its size is dynamic (`width: targetW`, `height: targetH`, `radius: targetR`), and the content is clipped with `clip: true` at `DynamicIsland.qml:239`.
- The curved “ear” decorations are separate `Canvas` items on both sides of the body:
  - left ear: `DynamicIsland.qml:180-201`
  - right ear: `DynamicIsland.qml:552-573`
  Each ear paints a quarter-round corner using `ctx.arc(...)` with `width == height == earRadius`.
- The island’s outer silhouette is composed by combining the center rounded rectangle with the two ear canvases. The center background is `solidRootBg` (`DynamicIsland.qml:272-286`), and the final body hole/shape is controlled by `OpacityMask` with `rootHoleWrapper` (`DynamicIsland.qml:288-310`).
- The shadow layer mirrors the same structure with `shadowSource`, `rootShadow`, `shadowHoleWrapper`, and ear canvases (`DynamicIsland.qml:49-168`).
- The dock/record attachment zone is `detachedRecordContainer` (`DynamicIsland.qml:576-647`), positioned immediately to the left of `maskContainer` via `anchors.right: maskContainer.left` and animated with `anchors.rightMargin`. It becomes visible only when `root.isRecording` is true.
- The island width/height are mode-dependent. `targetW` and `targetH` choose between collapsed, notification, volume, lyrics, hub, tools, audio, and expanded sizes (`DynamicIsland.qml:242-263`). The hub width/height come directly from `HubContent` via `hub.implicitWidth` / `hub.implicitHeight`.
- `HubContent.qml` sets `implicitWidth` and `implicitHeight` based on `currentIndex` (`HubContent.qml:28-40`), so the island’s outer shape expands to fit the selected hub tab.

### External References

- None.

### Related Specs

- None discovered in this research pass.

## Caveats / Not Found

- No separate geometry helper or reusable shape component was found; the outer shape is composed directly in `DynamicIsland.qml` with `Rectangle`, `Canvas`, and `OpacityMask`.
- I did not find a dedicated dock-zone file; the record dock area is embedded in the island module itself.
