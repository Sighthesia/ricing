# Bar Layout MVP Reference

## Source Project

Reference repo: `../DymicShell`

## Reference Files Reviewed

* `shell.qml`
* `modules/bar/BarWindow.qml`
* `modules/bar/BarContent.qml`
* `modules/bar/BarSection.qml`
* `modules/bar/BarWidgetWrapper.qml`
* `services/BarLayoutService.qml`
* `services/barlayout/BarLayoutSections.js`
* `services/barlayout/BarLayoutLayoutModel.js`
* `services/barlayout/BarLayoutPersistence.js`
* `services/barlayout/BarLayoutPersistenceBridge.qml`

## Findings

* The reference shell isolates top-level window creation in `shell.qml` and keeps bar behavior in dedicated modules and services.
* `BarWindow.qml` is a transparent `PanelWindow` wrapper whose main job is screen/window ownership and bar height policy.
* `BarContent.qml` is the composition root for the three-section layout and widget registry.
* `BarSection.qml` rebuilds ordered widgets for one section from the shared `layoutModel`.
* `BarWidgetWrapper.qml` owns shared sizing and delegate hosting; the full reference also includes drag, enter, and overlay behavior.
* `BarLayoutService.qml` centralizes section geometry, layout model access, and widget instance identity.
* The full reference service is broader than this task needs. Persistence, drag, picker state, and overlay synchronization can be omitted in the MVP.

## MVP Port Boundary For `afloat`

Port now:

* reusable bar window/content/section/wrapper structure
* minimal layout model singleton
* section geometry helper logic for left/center/right placement
* widget registry with the existing `DynamicIslandDockZone.qml`

Do not port now:

* persistence bridge and disk IO
* drag overlay and drag session logic
* widget picker / context menu / settings panel
* theme/settings/color singletons
* unrelated widgets and services

## Implications For Implementation

* `afloat` needs its own lightweight bar tokens instead of importing DymicShell's `Theme.qml`.
* The first iteration can keep a static default layout containing only one center widget.
* The service API should stay compatible enough with future expansion that later widgets can be added without rewriting the shell root.
