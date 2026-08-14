# Lazer Music Overlay Design

## Goal

Add an osu!lazer-inspired top-bar button and a real MPRIS-backed music control overlay to the existing Quickshell bar.

## Scope

In scope:

- Reusable `OsuTopBarButton.qml`
- Reusable `OsuMusicOverlay.qml`
- A non-exclusive per-screen overlay window anchored beneath the utility music button
- Existing MPRIS title, artist, playback state, progress, previous, play/pause, and next integration
- Local shuffle toggle and playlist request signal
- Pointer, keyboard, tooltip, click-flash, open/close, and reduced-motion behavior
- Bundled generic control icons
- QML component tests and shell startup verification

Out of scope:

- Persisting shuffle state
- Implementing backend shuffle, because the current media service has no shuffle interface
- Implementing a playlist browser; the playlist control emits a signal for future integration
- Seeking by clicking or dragging the progress bar
- Album artwork, volume controls, lyrics, and player selection

## Selected Architecture

Use a dedicated button component and one persistent non-exclusive `PanelWindow` per screen.

`OsuTopBarButton` is separate from the generic `IconButton` because its active pink fill, click flash, and two-line tooltip form a distinct interaction contract. Other top-bar buttons remain unchanged.

The music window uses `exclusionMode: ExclusionMode.Ignore`, so it never reserves workspace or pushes application windows. It is 340px wide and 130px high, right-aligned beneath the utility music button. Its input mask is empty when closed and restricted to the card while open or closing.

Each screen owns its own open state and local shuffle state. MPRIS data remains global through the existing services.

## OsuTopBarButton

Public interface:

- `isActive: bool`
- `hovered: bool` read-only from pointer state, with a test override
- `isFlashing: bool`
- `iconSource: url`
- `titleText: string`
- `subtitleText: string`
- `clicked()`

Visual states:

- Rest: transparent background; white icon at 0.8 opacity.
- Hover: `#333744` capsule, 6px radius; icon becomes fully opaque.
- Active: `#EB1C60` capsule and fully white icon.
- Disabled: follows the shared disabled opacity and blocks activation.

The background and icon opacity transition through the shared 100ms/160ms motion tokens. Active is the persistent base state; hover and press feedback layer over it.

### Click Flash

Every pointer or keyboard activation starts one interruptible flash sequence:

1. Set the persistent white overlay to opacity 0.6 and `isFlashing` to true.
2. Fade overlay opacity to 0 over the shared 160ms medium duration using an outward easing.
3. Set `isFlashing` to false when the fade completes.

The active background color transitions independently over 160ms. The flash does not delay the `clicked()` signal or active-state toggle.

Under reduced motion, the flash is an opacity-only 100ms fade and no scale/translation feedback runs.

### Tooltip

When pointer hover remains active for 200ms and `isActive` is false, one persistent tooltip becomes visible below the button. The 200ms value is an interaction delay, not a visual animation duration.

Tooltip content:

- Centered title, white, bold, 12px
- Centered subtitle, `#A0A0A0`, 10px
- Dark rounded bubble, sized from content

The tooltip enters and exits through the shared 100ms opacity transition, with a 2px Y movement only when reduced motion is off. It closes immediately when hover ends or the button becomes active.

The button supports Tab focus plus Enter/Space activation and exposes an accessible name from `titleText`.

## OsuMusicOverlay

Public presentation properties:

- `titleText: string`
- `artistText: string`
- `playing: bool`
- `progress: real`, clamped to `0..1`
- `shuffleActive: bool`
- `canGoPrevious: bool`
- `canTogglePlayback: bool`
- `canGoNext: bool`

Public signals:

- `shuffleRequested(bool active)`
- `previousRequested()`
- `playPauseRequested()`
- `nextRequested()`
- `playlistRequested()`
- `closeRequested()`

Geometry and visual treatment:

- 340x130px fixed card
- `#12131A` dark translucent background
- Subtle border, 10px radius, and soft shadow
- Track title centered, white, bold, 16px, one-line elide
- Artist centered, `#A0A0A0`, 12px, one-line elide
- Centered horizontal controls
- 4px full-width progress bar at the bottom edge
- Played progress `#FFD000`; remaining progress a dark translucent track

Controls are Shuffle, Previous, Play/Pause, Next, and Playlist. Shuffle uses gold when locally active. Play/Pause uses a larger circular white outline. Disabled MPRIS actions remain visible at reduced opacity but cannot activate.

If no player is present, title is `暂无播放内容`, artist is empty, progress is zero, and transport controls are disabled. Shuffle and Playlist remain usable as local/future actions.

## Media Integration

The host binds display data to `Services.MediaControlService`:

- Title and artist from its normalized media metadata
- Playing state from `playbackState === "playing"`
- Progress from its normalized `progress`
- Capability booleans from `canGoPrevious`, `canTogglePlayback`, and `canGoNext`

Transport signals call `Services.MediaService.previous()`, `playPause()`, and `next()`.

Shuffle toggles only the screen-local `shuffleActive` state because no backend shuffle interface exists. Playlist emits a request signal but opens no additional surface in this release.

## Window And Positioning

`UtilityZone` exposes the music button's active state and emits `musicOverlayRequested(bool open)` when it toggles.

`TopBar` owns the matching `musicOverlayOpen` and `shuffleActive` properties for each screen scope. A dedicated `PanelWindow`:

- Uses the same screen as the utility zone
- Has `implicitWidth: 340` and enough fixed implicit height for the 130px card plus entrance offset
- Anchors to top and right
- Uses `exclusionMode: ExclusionMode.Ignore`
- Positions its right edge to match the utility music button/utility group
- Starts immediately below the 46px bar
- Uses a transparent window background

The card remains one persistent instance. Opening animates opacity `0 -> 1` and Y offset `-4 -> 0` over 160ms with shared outward easing. Closing reverses over 100ms. Reduced motion removes Y movement and preserves opacity.

The window does not resize per frame. Its outer geometry is fixed; only the inner card transforms. The input mask becomes active for the card before opening interaction is enabled and becomes empty immediately when close starts.

## Keyboard Behavior

- Music top-bar button participates in the existing Tab order.
- Enter and Space toggle the panel and trigger click flash.
- Tab and Shift+Tab move through Shuffle, Previous, Play/Pause, Next, and Playlist.
- Left/Right arrows move between controls without triggering press-scale feedback.
- Enter and Space activate the focused control.
- Escape closes the panel and restores focus to the music top-bar button.
- Disabled transport controls are skipped and cannot activate.

## Tokens

Extend `LazerTheme` with:

- `osuButtonActive: #EB1C60`
- `osuButtonHover: #333744`
- `musicBackground: #12131A`
- `musicGold: #FFD000`
- `musicMuted: #A0A0A0`

All visual animation durations use the existing base motion tokens. The requested 180ms flash and 200ms panel duration are normalized to the existing 160ms medium token. Tooltip hover delay remains exactly 200ms because it is a delay, not an animated visual transition.

## Component Structure

- `modules/lazerbar/OsuTopBarButton.qml`
- `modules/lazerbar/OsuMusicOverlay.qml`
- `modules/lazerbar/MusicControlButton.qml`
- `modules/lazerbar/UtilityZone.qml`
- `modules/lazerbar/TopBar.qml`
- `modules/lazerbar/LazerTheme.qml`
- `modules/lazerbar/icons/shuffle.svg`
- `modules/lazerbar/icons/previous.svg`
- `modules/lazerbar/icons/play.svg`
- `modules/lazerbar/icons/pause.svg`
- `modules/lazerbar/icons/next.svg`
- `modules/lazerbar/icons/playlist.svg`
- `tests/qml/tst_osu_top_bar_button.qml`
- `tests/qml/tst_osu_music_overlay.qml`

Major QML declarations receive short English intent comments.

## Testing

`OsuTopBarButton` tests cover:

- Rest, hover, active, and disabled colors/opacities
- Active base state remaining visible under hover/press
- Flash starts at 0.6 and completes at zero
- Rapid repeated activation retargets the same flash layer
- Tooltip stays hidden before 200ms, appears afterward, and closes on hover leave or active state
- Enter/Space activation
- Reduced-motion transform suppression

`OsuMusicOverlay` tests cover:

- Title, artist, progress clamping, and empty-player presentation
- Shuffle local toggle and gold state
- Transport signal emission and disabled blocking
- Play/pause icon state
- Playlist signal emission
- Focus order, Arrow navigation, and Escape close request
- Open/close opacity and Y targets
- Reduced-motion Y suppression

Integration verification covers:

- Music button opens exactly one overlay on its screen
- The overlay does not reserve workspace
- Closing clears its input region immediately
- Real MPRIS metadata and controls update the panel
- `qs -p .` loads without WARN or ERROR lines
- All new and relevant existing QML tests pass

## Risks

### Multi-window alignment

The overlay and utility zone are separate windows. Their right-margin calculation must share one geometry source so the card remains visually anchored when utility entries collapse responsively.

### Tooltip clipping

The utility button's host is only bar-height. Its tooltip must either be hosted by the music overlay window or use a dedicated non-exclusive tooltip surface; it cannot be drawn below a 46px window and assumed visible.

### Media plugin tests

Plain `qmltestrunner` cannot load the Quickshell MPRIS plugin in this environment. Component tests therefore inject presentation state and assert signals. Real service wiring is verified through `qs -p .` and existing backend service behavior.

## Success Criteria

- The music entry feels like an osu!lazer top-bar control, including pink active state, quick white flash, and delayed two-line tooltip.
- The card appears directly beneath the music entry without moving or reserving desktop workspace.
- Real MPRIS title, artist, progress, previous, play/pause, and next work.
- The card remains responsive, interruptible, keyboard accessible, and reduced-motion safe.
