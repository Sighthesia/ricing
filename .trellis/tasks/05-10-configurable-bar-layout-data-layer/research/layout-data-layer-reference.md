# Layout Data Layer Reference

## Source Project

Reference repo: `../DymicShell`

## Files Reviewed

* `services/barlayout/BarLayoutLayoutModel.js`
* `services/barlayout/BarLayoutPersistence.js`
* `services/barlayout/BarLayoutPersistenceBridge.qml`

## Key Findings

* DymicShell uses `instanceKey` as the stable identity for widget instances so duplicate widget types can coexist safely.
* The reference model persists a normalized serialized layout instead of persisting section buckets directly.
* Startup restore prefers an in-memory persisted snapshot first, then falls back to disk.
* Disk persistence is written atomically through a temp file and rename flow into `.state/layout.json`.

## Implications For `afloat`

* `afloat` should adopt `instanceKey` now even if the initial default layout is still tiny.
* The layout schema should be independent from the current renderer so later editing flows can mutate entries without changing the rendering contract again.
* The persistence bridge can be much smaller than DymicShell's version as long as it preserves three behaviors:
  * startup load
  * save current layout
  * atomic disk write

## Recommended MVP Boundary

Include now:

* stable widget entry schema with `instanceKey`
* default layout normalization helpers
* local persistence and restore

Exclude now:

* drag-specific mutation helpers
* picker/add/remove UI flows
* overlay synchronization and panel state
