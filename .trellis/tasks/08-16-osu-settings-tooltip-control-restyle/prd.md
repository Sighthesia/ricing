# Stabilize osu settings tooltips and restyle controls

## Goal

Make the osu! settings panel visually coherent and interaction-stable: tooltips must not oscillate between overlapping sources, and the panel palette, Toggle, Slider, navigation, and search chrome must match the requested purple settings language.

## Background

- The previous tooltip task fixed natural text measurement, viewport-local placement, source following, scroll behavior, Slider Nub anchoring, and per-screen ownership.
- `SettingsOverlayBridge.currentTooltip()` and `LazerSettingsContent.ownedBestTooltipRequest()` currently let the last same-priority request win. A row and a nested/adjacent control can therefore repeatedly replace each other while both requests remain valid.
- Current settings visuals still use pink `LazerTheme.osuPink`, a grey row/control language, a `50x15` outlined Nub, a `5px` Slider track, left-side search icon, and two top-right header buttons.
- Local osu!lazer sources confirm the fixed `70/170px` sidebar model and provide interaction reference. The explicit colors and control geometry in this PRD are authoritative when they differ from current upstream osu!lazer.

## Requirements

### R1. Stable tooltip ownership

- Preserve the existing singleton transport, per-screen owner isolation, viewport-local geometry, natural text measurement, scroll following, and Slider `nubItem` identity.
- Keep the active tooltip source while it remains valid when another source requests the same priority; equal-priority requests must not repeatedly replace one another.
- A higher-priority request may preempt immediately. Slider value priority `2` continues to override row-description priority `1`.
- When the active source dismisses, becomes hidden, leaves the viewport, changes page, or is destroyed, select a deterministic best remaining owned request or close the tooltip.
- Repeated updates from the active source may update text without changing source ownership or restarting visibility animation.

### R2. Settings palette

- Add the settings accent token `readonly property color accentColor: "#765BFF"` and use it for settings highlights instead of pink.
- Use `#25222E` for default control trough/background surfaces.
- Use `#18161D` for the content panel and `#131217` for the sidebar rail.
- Use `#8A8795` for unselected navigation text and icons.
- Do not alter unrelated top-bar/music/osu pink tokens outside the settings surface.

### R3. Toggle presentation

- Render Toggle rows as one full-width horizontal line: white `14px` label on the left and the switch aligned to the far right.
- The switch is `44x20`, radius `10`; checked fill is `#765BFF`, unchecked fill is `#25222E`.
- Replace the current outlined/morphing `50x15` Nub presentation for Toggle. Preserve pointer, keyboard, focus, disabled, persistence, and reset behavior.

### R4. Slider presentation

- Render Slider rows as two columns. The left column contains a white `13px` label and a `12px` current-value line; the right Slider region receives approximately half of the usable row width.
- The Slider trough is a `24px`-high capsule-like surface with radius `4` and color `#25222E`; the travelled portion uses `#765BFF`.
- The Thumb is an embedded `4x20` light vertical bar at the progress edge with a subtle radius, not the current hollow Nub.
- Preserve stepped/reversed ranges, keyboard changes, pointer scrubbing, drag behavior, default reset, disabled state, persistence, and a value tooltip anchored to the moving Thumb identity.
- Value text continues to use each control's existing formatted value/suffix contract.

### R5. Row surfaces

- Remove the grey rounded rectangle/card-like background beneath settings components. Rows remain unframed; only controls that need a trough, field, dropdown, or switch surface paint one.
- Keep the existing revert zone, search participation, enabled/disabled behavior, and settings persistence.

### R6. Sidebar and header chrome

- Unselected navigation entries have no small dot/pill indicator; their text and icon use `#8A8795`.
- The selected navigation state may retain a clear purple selection treatment, but no inactive indicator remains visible.
- Remove the content header's top-right collapse chevron and close `x` controls. Closing remains available through `Esc` and the sidebar bottom Back action; sidebar expansion remains available through the sidebar's own collapse control.

### R7. Search field

- Place the search icon at the far right of the search field.
- Use placeholder text `输入以搜索`.
- Preserve search focus, filtering, keyboard access, clear-query behavior, and the existing no-results state. When a query is present, the clear affordance may replace the right-side search icon so both do not overlap.

### R8. Compatibility and motion

- Preserve the fixed Settings owner surface, `70/170/400/570` layout contract, page persistence, category switching, multi-screen isolation, focus restoration, reduced-motion behavior, and all settings save/reset contracts.
- Perceptible color, focus, hover, and value changes follow existing motion tokens; tooltip position updates remain immediate.

## Out of Scope

- Rebuilding Choice, TextField, dropdown menu, page data, settings schema, or backend services beyond palette/row integration required by this task.
- Changing the full application palette or replacing non-settings uses of `LazerTheme.osuPink`.
- Changing panel width, sidebar widths, category names, persistence semantics, or adding new settings.
- Recreating osu!lazer pixel-for-pixel where it conflicts with the explicit requested geometry and colors.

## Technical Notes

- Prefer stable arbitration over a long hover debounce: equal priority cannot preempt a valid owner; higher priority can.
- The generic `LazerSettingsRow` should own label placement and select a presentation mode exposed by the injected control, avoiding duplicate labels and per-page layout forks.
- Toggle and Slider retain their existing public value signals. Slider's exported anchor changes from the old Nub visual to the new Thumb item while keeping the `nubItem` compatibility name if tests/consumers rely on it.

## Acceptance Criteria

- [ ] Two simultaneous same-priority requests under one Content owner do not alternate ownership while the active source remains valid.
- [ ] Slider priority `2` immediately overrides row priority `1`, then deterministically falls back or closes when the Slider dismisses.
- [ ] Active-source text updates do not restart tooltip fade or change source identity.
- [ ] Existing tooltip measurement, viewport clamping, scroll following, offscreen close, foreign-owner isolation, reduced motion, and overlay lifecycle tests remain green.
- [ ] Settings content is `#18161D`, sidebar is `#131217`, accent is `#765BFF`, control troughs are `#25222E`, and inactive nav foreground is `#8A8795`.
- [ ] Toggle rows show a left `14px` label and right-aligned `44x20` capsule with the specified checked/unchecked fills.
- [ ] Slider rows show a `13px` label plus `12px` value on the left and an approximately half-width Slider on the right.
- [ ] Slider uses a `24px` trough, purple travelled fill, and embedded `4x20` light Thumb; no hollow Nub remains.
- [ ] Grey rounded component/card backgrounds are absent from settings rows.
- [ ] Inactive navigation entries show no dot/pill indicator and use `#8A8795` for icon/text.
- [ ] The content header has no top-right collapse or close button; `Esc`, sidebar Back, and sidebar collapse still work.
- [ ] Search placeholder is exactly `输入以搜索`; the search icon is right-aligned and never overlaps the clear affordance or typed text.
- [ ] Existing settings values, persistence, reset, filtering, keyboard controls, focus restoration, category switching, and fixed surface geometry remain functional.
- [ ] Relevant QML tests, Python backend tests, `qmllint`, `git diff --check`, and `qs -p .` smoke loading pass without new WARN/ERROR lines.
