# Integrate media signals, lyrics display, and spectrum into SuperIsland

## Goal

Enhance SuperIsland's media card with album art, progress bar, and transport controls; add a new compact lyrics card with synced lyrics and cava spectrum visualization.

## Requirements

- Enhance `IslandMediaCard` with album artwork, progress bar, and playback controls (reuse existing `MediaParts.*` components)
- Create `IslandLyricsCard` — compact lyrics strip with synced lyrics from `NeteaseWebLyricsService` and 6-bar symmetric spectrum from `CavaService`
- Register lyrics card in `SuperIslandCardComponentRegistry` with routing logic: show lyrics card when `MediaControlService.hasLyrics && settings.showLyrics && settings.preferLyrics`

## Acceptance Criteria

- [ ] IslandMediaCard shows artwork, title, artist, progress bar, and prev/play/next controls in non-compact mode
- [ ] IslandMediaCard shows artwork + title + state badge in compact mode
- [ ] IslandLyricsCard renders synced lyrics with StrictlyEnforceRange ListView
- [ ] IslandLyricsCard shows 6-bar symmetric cava spectrum
- [ ] CardComponentRegistry routes media events to lyrics card when lyrics are available
- [ ] Shell validates: `timeout 5 qs --path .`

## Technical Approach

- Reuse `MediaControlService` for all media state (title, artist, artUrl, progress, playbackState, canGoPrevious, etc.)
- Reuse `MediaParts.MediaArtwork`, `MediaParts.MediaProgressStrip`, `MediaParts.MediaFlashControls`
- Reuse `CavaService.bars` for spectrum data
- Use `NeteaseWebLyricsService._lyricLines` + `currentLyricIndex` for synced lyrics
- CavaService refCount managed by card visibility

## Out of Scope

- Python lyrics_fetcher.py (DymicShell already has browser-bridge lyrics)
- New settings (existing `mediaControl.showLyrics/preferLyrics` suffice)
- Hub media page / expanded overlay changes

## Technical Notes

- Reference: `quickshell/Modules/DynamicIsland/LyricsContent/LyricsContent.qml` for lyrics pattern
- Reference: `quickshell/Modules/DynamicIsland/MediaContent/MediaContent.qml` for media UI pattern
- Existing: `modules/bar/media/MediaPanelContent.qml` shows full media panel pattern
- Existing: `modules/bar/media/MediaFlashControls.qml` has transport controls
- Existing: `modules/bar/media/MediaProgressStrip.qml` has seekable progress bar
