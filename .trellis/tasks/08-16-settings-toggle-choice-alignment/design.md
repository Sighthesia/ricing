# Settings Toggle And Choice Geometry

## Ownership

`LazerSettingsRow` remains the geometry owner for the card, content padding, reset reservation, and presentation mode. `LazerSettingsToggle` remains a single `44x20` visual control. `LazerSettingsChoice` remains a single label-owning surface and continues exposing `headerItem` as the source for popup placement.

## Toggle Flow

1. Row computes the actual inline content host bounds after content padding and reset-slot reservation.
2. The inline control host is vertically centered against that content host's actual height.
3. The Toggle capsule fills its own `44x20` root, so mapped capsule center and Row content center can be asserted independently of local `y` bindings.

The fix must live at the Row/control-host boundary unless evidence proves the Toggle root itself violates its size contract. This avoids adding a second wrapper or duplicating visual geometry.

## Choice Flow

1. Row supplies the Choice root with the available content width and hides only the external label.
2. Choice root and `headerSurface` occupy the same bounds; padding belongs inside the surface's label/value column.
3. `LazerSettingsContent.showDropdownFor()` maps the same `headerItem` to Content coordinates and uses its mapped `x` and `width` for the popup.

The implementation must remove any geometry discrepancy between the outer Choice item and its visible header surface. It must not create a second hover/focus background or a separate popup anchor.

## Compatibility

- Preserve `rowPresentation`, `controlOwnsLabel`, `fieldLabel`, `headerItem`, `menuOpen`, `openMenu()`, `closeMenu()`, and `valueSelected` contracts.
- Preserve `SettingsOverlayBridge` as a transport/lifecycle singleton; it does not become a geometry owner.
- Preserve fixed panel geometry, per-screen Content ownership, keyboard navigation, focus behavior, tooltip behavior, and reset-slot input isolation.

## Test Design

- Map Toggle capsule and Row content host into the same coordinate space and compare centers, dimensions, and right-edge reservation.
- Map Choice root and header surface into Row/Content coordinates and compare left edges and widths.
- Open a real Choice through the Content owner and assert popup geometry derives from the same header source.
- Keep existing dropdown selection, keyboard, focus, and page-level settings tests unchanged except for new geometry assertions.

## Rollback

Reverting the Row/Choice geometry changes returns the previous alignment behavior without touching persisted settings, service APIs, or panel ownership.
