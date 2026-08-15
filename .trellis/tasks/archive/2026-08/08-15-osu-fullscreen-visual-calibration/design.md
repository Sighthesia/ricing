# osu Fullscreen Visual Calibration Design

## Design Basis

The primary reference is the local osu!lazer source at `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu`:

- `osu.Game/Overlays/FullscreenOverlay.cs`: 85% width, top-centred continuous surface, no rounded card treatment.
- `osu.Game/Overlays/WaveOverlayContainer.cs`: fullscreen overlay lifecycle and wave ownership.
- `osu.Game/Graphics/Containers/WaveContainer.cs`: four wave layers, angles, movement, 800ms entry and 500ms exit.
- `osu.Game/Overlays/WikiOverlay.cs`, `NewsOverlay.cs`, and `BeatmapListingOverlay.cs`: page-specific structure and colour schemes.
- `osu.Game/Overlays/SettingsPanel.cs`: left-side settings panel, 400px main panel and 600ms transition.
- `osu.Game/Overlays/NowPlayingOverlay.cs`: music is a local overlay rather than fullscreen content.

The design copies the visual system and motion hierarchy, not osu!lazer's online content or business logic.

## Architecture

### Overlay Coordinator

A per-screen, non-visual coordinator owns the active target:

`none | settings | music | wiki | news | beatmap`

It also owns the opener focus reference and an optional pending target. It does not own geometry, animation, content, or input masks.

The coordinator guarantees:

- Only one owner is interactive at a time.
- Repeating the active target closes it.
- Switching among Wiki, News, and Beatmap replaces content inside the existing wave owner.
- Switching across owner types closes the active owner before opening the pending owner.
- Focus is restored only after a final close, not between consecutive owner transitions.
- Unknown targets do not change the active state.

### Surface Owners

Each screen has three persistent compositor owners:

1. `WaveFullscreenWindow` for Wiki, News, and Beatmap.
2. `SettingsWindow` for the left settings panel.
3. `NowPlayingWindow` for the local music overlay.

Each owner uses fixed outer geometry and animates only inner QML items. `PanelWindow` dimensions and layer-shell regions are not driven per frame.

This design supersedes the previous shared-host rule that placed Settings, Music, and fullscreen pages in one loader. The frontend quality guideline must be updated during implementation.

## Wave Fullscreen

### Geometry

- The owner spans the screen so it can capture the two outside close zones without resizing.
- The visible surface is exactly 85% of available screen width and horizontally centred.
- With a top-positioned bar, its final top edge meets the bar's lower edge.
- With a bottom-positioned bar, it stops at the screen top edge; motion is never mirrored.
- The surface is continuous and clipped, with no corner radius, glass border, floating-card margin, or generic glass shadow.

### Wave Layers

Four clipped layers sit behind the body and use the osu!lazer source angles:

- First: `13deg`
- Second: `-7deg`
- Third: `4deg`
- Fourth: `-2deg`

Each page supplies a fixed osu overlay palette. Wiki uses Orange, News uses Purple, and Beatmap uses Blue. The four wave shades and body neutrals are derived from that page palette, not `ColorService` or wallpaper colours.

### Motion

- Entry: body moves from below the screen to its final top position over 800ms with `OutQuint`; waves enter over 800ms with `OutSine`.
- Exit: body moves back below the screen over 500ms with `In`; waves exit over 500ms with `InSine`.
- Reversal starts from current visual progress. It does not reset to either endpoint.
- A route change within the wave owner keeps the shell visible and cross-fades header and page content briefly.
- Reduced motion replaces large translations with a short opacity transition while preserving lifecycle callbacks and route cleanup order.

The two exposed side zones consume pointer input and request the same complete close path as Escape. They never pass the closing click to the desktop.

## Page Templates

The templates reproduce layout and UI styling with minimal representative content.

### Wiki

- Orange overlay palette.
- osu-style title/header and current-location treatment.
- Sidebar/table-of-contents column plus article column at the original visual proportions.
- Representative headings, links, and a few paragraphs only.

### News

- Purple overlay palette.
- osu-style title/header and archive sidebar.
- Vertical article listing with the original cover, date, title, and summary hierarchy.
- Only enough sample cards to demonstrate layout and scrolling.

### Beatmap

- Blue overlay palette.
- osu-style title/header and static filter/search controls.
- Listing area with representative beatmap card proportions, spacing, and information hierarchy.
- Filters expose visual focus/selection states but perform no remote search or real filtering.

All templates prioritise silhouette, density, alignment, spacing, colour, typography hierarchy, and feedback. Content completeness is explicitly out of scope.

## Settings Surface

Settings returns to a dedicated left-side panel:

- Sidebar plus approximately 400px main content, matching the osu!lazer proportion.
- 600ms horizontal entry and exit.
- Existing Afloat settings objects, save callback, control behaviour, keyboard navigation, and focus restoration remain intact.
- The panel overlays the desktop. It does not move external Wayland applications, the bar, islands, or other Afloat surfaces.
- Its window and mask cover only the panel's required geometry and close interaction area.

The visual work covers the container, navigation, header, spacing, density, colours, and states. It does not redesign settings data or persistence.

## Now Playing Surface

Music returns to a dedicated local overlay near the top-bar music entry:

- Existing MPRIS title, artist, progress, previous, play/pause, next, and local shuffle bindings remain intact.
- Layout follows osu!lazer's Now Playing hierarchy instead of the wave fullscreen shell.
- The fixed outer window covers only the player's placement bounds; the input mask follows the visible player.
- Entry, exit, keyboard navigation, disabled controls, Escape, and focus restoration remain interruptible and reduced-motion safe.

## Input And Lifecycle

Escape precedence is:

1. Clear active input/editing state.
2. Return from page-local reversible state.
3. Close the active owner.

Cross-owner transitions use a pending target. The current owner becomes non-interactive as close begins. On close completion, the coordinator either opens the pending target or clears state and restores focus to the original opener.

Loader or component failure leaves the owner in a themed lightweight error state that can still close. It must not leave a fullscreen input mask active with no visible content.

## Responsive And Accessibility Behaviour

- The wave surface remains 85% wide at every supported size.
- Narrow layouts reduce internal spacing, sidebar width, and text scale without changing the visual type.
- Settings clamps internal content when the screen cannot fit the source proportion; it remains a left panel.
- Keyboard focus stays on inner `Item` controls, never directly on `PanelWindow`.
- Reduced motion removes large translations but not state sequencing or focus behaviour.

## Testing Strategy

Pure logic tests cover coordinator target validation, owner classification, toggle behaviour, pending transitions, Escape precedence, geometry, and motion endpoints.

QML component tests cover:

- Four wave angles, layer order, palette assignment, clipping, and entry/exit targets.
- Reversal without endpoint reset.
- Side-zone close without pointer passthrough.
- Same-owner route cross-fade and cross-owner sequencing.
- Settings width, left entry, 600ms targets, and unchanged save bindings.
- Now Playing geometry, service presentation, transport signals, and keyboard behaviour.
- Focus restoration and reduced motion across all owner types.
- Wiki, News, and Beatmap structural identity with minimal content.

Integration verification runs all relevant QML tests sequentially, Python backend tests, `git diff --check`, and `qs -p .`. New QML WARN/ERROR lines are release blockers.

## Risks And Mitigations

- Four rotated layers can exceed clip bounds. Keep them inside a dedicated 85% clipped viewport and test extreme aspect ratios.
- Per-frame layer-shell geometry would stutter. Keep compositor windows fixed and animate inner items only.
- Fullscreen masks can starve desktop pointer input. Activate the fullscreen mask only while opening/open and clear it as close completes; local owners use narrow windows/masks.
- Old shared-owner assumptions remain in tests and frontend guidelines. Migrate both in the same change rather than adding compatibility branches.
- Exact osu fonts may be unavailable. Use the closest bundled/system fallback and preserve size, weight, tracking, and hierarchy without adding a network dependency.

## Rollback Boundary

The coordinator and each surface owner are separate units. If one visual type fails verification, it can remain on its prior dedicated implementation while the other owner types proceed. Do not restore the single mixed fullscreen host as a compatibility fallback.
