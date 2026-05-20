# Widget Picker Reference

## Source Project

Reference repo: `../DymicShell`

## Files Reviewed

* `modules/bar/WidgetPickerWindow.qml`
* `services/BarLayoutService.qml`

## Key Findings

* The reference picker is a full-featured panel built on the same shell theming and motion stack as the rest of DymicShell.
* It drives layout changes through `BarLayoutService` state, not through the picker window itself.
* The picker contains search, cards, staggered motion, and close controls that are unnecessary for the first `afloat` version.

## Implications For `afloat`

* `afloat` should keep the picker much smaller: a simple window, a simple list, and a single add action.
* The picker should call into `BarLayoutService` for add/persist behavior and remain a thin UI layer.
* The first version should not copy the reference panel styling or animation stack.

## Recommended MVP Boundary

Include now:

* a minimal picker window
* a list of currently stable supported widget entries
* a single add action that writes through `BarLayoutService`

Exclude now:

* search
* card grid and hover-reveal effects
* advanced animation stack
* settings-mode plumbing from the reference project
