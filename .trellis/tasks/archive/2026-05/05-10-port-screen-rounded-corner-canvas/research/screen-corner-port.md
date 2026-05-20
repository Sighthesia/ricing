# Screen corner port research

## Source files

* `DymicShell/modules/background/ScreenCornerWindow.qml`
* `DymicShell/modules/background/ScreenCornerMask.qml`
* `DymicShell/shell.qml`

## Findings

* The feature is self-contained and does not depend on the source project's wallpaper/background window logic.
* The visible behavior comes from two parts only:
* a reusable `Shape`-based corner mask component
* a `Variants` host that creates four tiny transparent `PanelWindow`s per screen
* Each corner window uses:
* `color: "transparent"`
* `exclusionMode: ExclusionMode.Ignore`
* `WlrLayershell.layer: WlrLayer.Overlay`
* `WlrLayershell.keyboardFocus: WlrKeyboardFocus.None`
* The only non-rendering dependency is `SettingsService.data.appearance.screenCornerRadius`, used to size each corner window.
* The target project currently has only a minimal `shell.qml` top bar and no local settings/theme pipeline, so reusing the source configuration chain would create avoidable scope growth.

## Port recommendation

* Port the rendering structure directly.
* Replace the source settings-backed radius with a fixed local constant in the target host.
* Keep the feature in small dedicated QML files so later settings integration can swap only the radius source.

## Constraints for implementation

* Do not port `SettingsService`, `Theme`, wallpaper windows, or unrelated background modules.
* Keep the existing top bar behavior unchanged.
* Keep the overlay windows tiny rather than using one large full-screen input-transparent layer.
