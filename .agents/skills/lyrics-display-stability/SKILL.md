---
name: lyrics-display-stability
description: Use when changing compact or expanded lyrics display, especially if lyric text, track metadata, or media pulses flicker during sparse lyric timing or weak source updates.
---

# Lyrics Display Stability

Keep lyric display latched to session availability, not to the cadence of lyric line changes.

## When to Use
- Working on `services/MediaControlService.qml`.
- Working on `modules/bar/widgets/MediaControlWidget.qml` or `modules/bar/media/MediaPanelContent.qml`.
- The media widget or panel flashes back to player metadata, `No Media`, or stale text while lyrics are active.
- Sparse lyric timing causes intermittent pulses, content swaps, or source flips mid-song.

## Symptoms
- `MediaControlService._lyricsSourceLatched` drops during long gaps between lyric lines.
- `MediaControlWidget` briefly switches between lyric text and media metadata even though the same song is still active.
- The compact widget pulses or re-announces during playback without a real track change.
- The expanded panel flashes `No Media`, player identity, or untranslated metadata between lyric updates.

## Root Cause
- Lyric sessions can stay valid for many seconds even when `currentLyric` and `nextLyric` do not change.
- If the display latch expires based only on property-change frequency, sparse lyric timing looks like source loss.
- Once the latch drops, the widget falls back to generic media metadata and may trigger extra content swaps or announcement pulses.

## Transferable Lesson
- Treat lyric display as a session-level state machine, not as a stream that must update every line to remain trusted.
- Use grace windows to survive transient empties, but reset only when the source actually disappears or changes sessions.

## Correct Pattern
- Keep the lyrics source latched while the source still reports an active session or cached lyric content.
- Let grace timers expire only after confirming the signal is truly gone; do not tie expiry to lyric line frequency.
- Keep lyric-only text changes from triggering full artwork or metadata swap animations.
- Separate display-layer latching from source-specific bridge recovery; NetEase bridge rules belong in `netease-web-lyrics-stability`.

## Verification
- Play a song with multi-second gaps between lyric lines and confirm the widget does not flash back to player metadata.
- Watch the compact widget and expanded panel while playback continues; neither should pulse or swap content without a real track change.
- Run `timeout 5 qs --path .` after modifying services or QML display code.

## References
- `services/MediaControlService.qml`
- `modules/bar/widgets/MediaControlWidget.qml`
- `modules/bar/media/MediaPanelContent.qml`
