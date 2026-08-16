# Runtime Settings Default Contract

## Architecture

`SettingsService` is the single runtime owner for both persisted category objects and their canonical defaults. It will expose category default maps and one `resetCategorySetting(category, key, value)` operation. The operation validates the category/key against its map, assigns the canonical default to the matching `JsonAdapter` object, and calls the existing `save()` debounce.

`TopBar.qml` remains a thin composition host. Its `LazerSettingsOverlay` will bind the three maps and reset operation onto `panel`, completing the existing `LazerSettingsPanel` input contract without changing overlay ownership or geometry.

## Data Flow

1. A category page calls `defaultOf(key)` for both its Row and numeric Slider.
2. The Row exposes reset state from its existing `defaultValue`, `currentValue`, and callback bindings.
3. The Slider derives its marker from its own `defaultValue` using `Logic.sliderFraction()`.
4. A reset click flows Page -> Panel wrapper -> SettingsService category reset -> persisted JsonObject -> `save()`.

## Validation Rules

- Unknown category, absent key, or a value not equal to the canonical default is ignored by the service reset API; callers cannot inject arbitrary values through the reset path.
- Defaults remain plain maps to avoid exposing mutable service configuration to controls.
- The pages keep their existing fallback display values for unloaded settings objects; Slider default markers remain hidden until a real configured default is supplied.

## Compatibility

- Do not change `LazerSettingsRow`, `LazerSettingsSlider`, reset z-order, thumb/marker layers, tooltip `nubItem`, or control input behavior.
- Do not change the shape or persistence location of `SettingsService` category objects.
- Existing standalone Panel/page tests may continue injecting their own maps and reset callbacks; add host-path coverage rather than replacing that test seam.

## Rollback

Removing the TopBar bindings returns the panel to its current no-default runtime behavior. Removing the service API is self-contained because it has no consumers outside the settings host.
