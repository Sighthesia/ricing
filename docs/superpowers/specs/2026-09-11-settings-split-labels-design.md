# Settings Split Labels Design

## Scope

Settings controls with two text levels use the slider's split presentation: a
muted small label identifies the setting and the value or editor occupies the
lower line. This applies to text fields and other controls that expose a
two-level value presentation.

## Surface treatment

The color scheme row and the theme template picker remain part of the same
appearance surface. Their visible content uses one shared, square background
so the labels and controls read as one block rather than separate cards.

## Invalid preview state

Theme template previews may be unavailable while the preview cache is missing
or being regenerated. The picker keeps a fixed title band above its grid in
that state. The grid may show fallback swatches, but it must not move upward
or overlap the title.

## Verification

The settings panel test verifies split presentation for text fields, shared
appearance surface geometry, and a non-overlapping title/grid relationship
when theme preview data is unavailable.
