# osu Fullscreen Visual Calibration Design

## Goal

Rebuild Afloat's osu-style overlays from the real local osu!lazer implementation rather than the current mixed rounded-card design. Wiki, News, and Beatmap use the 85% wave fullscreen system; Settings and Music return to their distinct osu!lazer surface types.

## Source Evidence

The design is grounded in `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu`:

- `FullscreenOverlay<T>` defines a top-centred 85% continuous surface without rounded-card styling.
- `WaveOverlayContainer` and `WaveContainer` define four angled reveal layers, 800ms entry, and 500ms exit.
- `WikiOverlay`, `NewsOverlay`, and `BeatmapListingOverlay` define distinct Orange, Purple, and Blue page structures.
- `SettingsPanel` is a left-side panel with a 400px main area and 600ms transition.
- `NowPlayingOverlay` is a local music overlay, not fullscreen page content.

## Selected Architecture

Use a thin per-screen `OverlayCoordinator` with three persistent owner windows:

1. Wave Fullscreen for Wiki, News, and Beatmap.
2. Settings Side Panel.
3. Now Playing.

The coordinator manages only the active target, mutual exclusion, pending cross-owner transitions, Escape, and opener focus. Each owner controls its own geometry, mask, animation, and content. Only one owner may be interactive at a time.

This replaces the previous architecture that loaded Settings, Music, and fullscreen pages into one mixed fullscreen host.

## Wave Fullscreen

The owner is screen-sized but never resized per frame. The visible body is exactly 85% of available screen width and centred horizontally. With a top bar, it meets the bar's lower edge; with a bottom bar, it stops at the screen top edge. Motion is never mirrored.

The surface has no corner radius, glass border, floating-card margin, or generic glass shadow. Header, body, sidebar, and content form one continuous clipped entity.

Four layers reproduce the osu!lazer source angles: `13deg`, `-7deg`, `4deg`, and `-2deg`. Wiki uses Orange, News uses Purple, and Beatmap uses Blue fixed overlay palettes. Wallpaper-derived colours do not replace these schemes.

Entry moves the body from below the screen over 800ms with `OutQuint`; waves use `OutSine`. Exit returns below the screen over 500ms with `In`; waves use `InSine`. Reversal continues from current progress. Reduced motion substitutes a short fade while preserving lifecycle order.

The exposed left and right zones close the overlay through the complete exit animation and consume the triggering click.

## Page Style

Content is deliberately minimal; layout and UI identity are the deliverable.

- Wiki keeps the Orange header, location treatment, sidebar/article proportions, and typographic hierarchy with a few representative paragraphs.
- News keeps the Purple header, archive sidebar, and cover/date/title/summary list proportions with a few sample cards.
- Beatmap keeps the Blue header, static filter controls, listing grid, card proportions, spacing, and information hierarchy.

Same-owner page changes keep the wave shell visible and briefly cross-fade header/content. They do not replay the full wave entrance.

## Settings

Settings uses a dedicated left-side owner with an osu-style sidebar plus approximately 400px main content and a 600ms horizontal transition. It overlays the desktop and does not move external Wayland applications, the bar, islands, or other Afloat surfaces.

Existing settings data, save behaviour, controls, keyboard navigation, Escape, and focus restoration remain unchanged. The visual work covers structure, navigation, spacing, density, colours, and states.

## Now Playing

Music uses a dedicated local owner near the top-bar music entry. Existing MPRIS metadata, progress, previous, play/pause, next, local shuffle, disabled states, keyboard navigation, Escape, and focus restoration remain intact. It does not use the wave fullscreen shell.

## Lifecycle And Input

Repeating the active target closes it. Switching among Wiki, News, and Beatmap changes content in place. Switching owner type closes the current owner before opening the pending target. Focus returns to the opener only after a final close.

Escape first clears input/editing state, then page-local reversible state, then closes the owner. Invalid targets do nothing. A load failure shows a themed closable error state and never leaves an invisible fullscreen mask active.

## Scope

In scope:

- Source-faithful surface geometry, palettes, primary layout, UI styling, motion, input masks, and lifecycle.
- Minimal static content sufficient to demonstrate sidebar, list, grid, and scrolling layouts.
- Existing Settings and MPRIS behaviour preservation.

Out of scope:

- Remote APIs, pagination, real search/filter logic, complete articles, complete beatmap metadata, and osu!lazer sounds.
- Mirroring fullscreen motion for a bottom bar.
- Moving or scaling external windows to simulate Settings pushing the game view.

## Verification

Tests cover coordinator mutual exclusion, pending transitions, Wave geometry and four-layer order, exact motion endpoints, interruption, side-zone close, fixed palettes, reduced motion, page structural identity, Settings persistence/focus, and Now Playing transport/keyboard behaviour.

Run relevant QML tests after every QML change, then all plugin-independent QML tests sequentially, Python backend tests, `git diff --check`, and `qs -p .`. New QML WARN/ERROR lines block completion.

## Risks

- Rotated wave layers may overflow; isolate them in the 85% clipped viewport and test extreme aspect ratios.
- Fullscreen masks may starve desktop input; clear the mask after closing and keep Settings/Music windows narrow.
- Per-frame compositor geometry may stutter; animate only inner items.
- Existing guidelines and tests encode the rejected mixed owner; migrate them with the architecture instead of adding compatibility branches.
