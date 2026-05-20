# Port screen faux-rounded-corner canvas

## Goal

Port the faux screen rounded-corner overlay from `DymicShell` into this `afloat` Quickshell project so each screen can render decorative display-corner masks above the shell UI.

## What I already know

* The source implementation lives in `DymicShell/modules/background/ScreenCornerWindow.qml` and `DymicShell/modules/background/ScreenCornerMask.qml`.
* The source pattern is small and self-contained: one `Variants` over `Quickshell.screens`, four tiny transparent `PanelWindow`s per screen, and one reusable `Shape`-based mask component.
* The source implementation uses `WlrLayershell.layer: WlrLayer.Overlay`, `WlrLayershell.keyboardFocus: WlrKeyboardFocus.None`, and `exclusionMode: ExclusionMode.Ignore` so the decoration stays above UI without claiming input space.
* The current target project is minimal and only has `shell.qml` with a top `PanelWindow`; it does not yet have a theme/config/settings system.
* The only source dependency that affects behavior is `SettingsService.data.appearance.screenCornerRadius`, which defines the mask size.

## Assumptions (temporary)

* This task should keep the current shell minimal and avoid pulling over the full `Theme` / `SettingsService` stack from `DymicShell`.
* The chosen MVP is a fixed local corner radius constant instead of a settings-backed radius.

## Open Questions

* None for MVP.

## Requirements (evolving)

* Add a reusable screen-corner mask component to the target project.
* Add a per-screen window host that renders top-left, top-right, bottom-left, and bottom-right faux rounded corners.
* Keep the corner overlays transparent except for the mask fill.
* Keep the overlay windows non-interactive and out of exclusive layout space.
* Integrate the corner overlay into the shell entry so it renders alongside the existing top bar.
* Use a fixed local corner radius constant for this first port.
* Do not port unrelated background, wallpaper, theme, or settings modules unless required by an explicit decision.

## Acceptance Criteria (evolving)

* [ ] The target project contains a reusable QML component that draws one corner mask.
* [ ] The shell renders faux rounded corners for all four corners of each screen.
* [ ] The corner windows are overlay-layer, transparent, non-focusable, and ignore exclusion space.
* [ ] The existing top bar remains present after the corner overlay is integrated.
* [ ] Corner size comes from a local fixed constant, with no new settings/theme dependency chain.
* [ ] The implementation stays narrowly scoped and does not import the source project's larger background/settings architecture.

## Definition of Done (team quality bar)

* Implementation is present and scoped to the rounded-corner feature.
* Lint / syntax validation is run if available.
* No unnecessary architecture or settings migration is introduced.

## Out of Scope (explicit)

* Porting wallpaper/background windows
* Porting the full settings system
* Porting the full theme token system
* Adding runtime configuration for corner radius
* Reworking the existing top bar design

## Technical Approach

Copy the source feature shape, but collapse its configuration dependency. Add one reusable `ScreenCornerMask.qml` component and one `ScreenCornerWindow.qml` host in the target repo, then instantiate that host from `shell.qml` next to the current top bar. Keep the radius as a small local constant inside the corner host for now.

## Decision (ADR-lite)

**Context**: The source project reads screen-corner radius from a larger settings stack, but the target project is intentionally minimal and does not yet have that architecture.

**Decision**: Port only the rendering behavior and replace the settings-backed radius with a fixed local constant for the first iteration.

**Consequences**: This keeps the change tiny and low-risk, but the corner radius will not be user-configurable until a later settings/theme task introduces a proper configuration source.

## Technical Notes

* Source files inspected:
* `../DymicShell/modules/background/ScreenCornerWindow.qml`
* `../DymicShell/modules/background/ScreenCornerMask.qml`
* `../DymicShell/shell.qml`
* Current target entry inspected:
* `shell.qml`
* Source radius currently comes from `SettingsService.data.appearance.screenCornerRadius`; target project does not yet have an equivalent settings source.
* MVP choice confirmed by user: fixed local radius constant.
