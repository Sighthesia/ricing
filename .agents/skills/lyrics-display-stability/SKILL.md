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
- The compact media pill flickers near lyric boundaries even after animation triggers are narrowed.
- The compact media pill falls one line behind after anti-flicker changes that over-prioritize stable cached text.
- Switching the primary lyric source to translation still leaves the compact pill mostly showing original lyrics, or vice versa.
- The expanded panel flashes `No Media`, player identity, or untranslated metadata between lyric updates.
- Pausing playback jumps the compact lyric readout back to the first credit line or song intro.
- The expanded panel loses stable song metadata because lyric-first text replacement leaks out of the compact pill.

## Root Cause
- Lyric sessions can stay valid for many seconds even when `currentLyric` and `nextLyric` do not change.
- If the display latch expires based only on property-change frequency, sparse lyric timing looks like source loss.
- Once the latch drops, the widget falls back to generic media metadata and may trigger extra content swaps or announcement pulses.
- The compact pill and expanded panel need different text ownership: lyric-first replacement is useful in the pill, but unstable in the expanded panel.
- The compact pill and expanded panel also need different lyric selection policy: a single-line pill should prefer the current stable line, while a two-line panel can safely expose current plus next.
- Reusing panel-style `next`-line preview or secondary-line signatures in the compact pill makes the visible text jump even when the user cannot see the secondary lyric line.
- Cross-track fallback between original and translated lyrics makes compact display policy unstable: fixing flicker by reordering a mixed candidate list often reintroduces one-line lag.
- A compact pill cannot safely use a generic `_firstNonEmpty([...])` chooser that mixes `current`, `next`, `stable`, original, and translated candidates in one place.
- Pause transitions can emit weak NetEase lyric updates that rewind the lyric cursor even while the real MPRIS player is already paused at the correct position.

## Transferable Lesson
- Treat lyric display as a session-level state machine, not as a stream that must update every line to remain trusted.
- Use grace windows to survive transient empties, but reset only when the source actually disappears or changes sessions.
- When two surfaces share one media model, keep display policy local to the surface instead of pushing a single lyric-first text policy everywhere.
- In shared media models, "which lyric lines exist" and "which lyric lines this surface should display" are different questions.
- In single-line lyric UIs, choose one text track first, then stabilize within that track; do not solve flicker by mixing fallback candidates from multiple tracks.
- If a settings toggle says "show translation" or "show original", the displayed compact text should come only from that selected track. Stability fallback may reuse cached text from the same track, but should not cross over to the other track.
- When browser-side lyrics and compositor-side playback disagree during pause, prefer the authoritative player timeline and freeze the last stable lyric snapshot.

## Correct Pattern
- Keep the lyrics source latched while the source still reports an active session or cached lyric content.
- Let grace timers expire only after confirming the signal is truly gone; do not tie expiry to lyric line frequency.
- Keep lyric-only text changes from triggering full artwork or metadata swap animations.
- Separate display-layer latching from source-specific bridge recovery; NetEase bridge rules belong in `netease-web-lyrics-stability`.
- In `MediaControlWidget.qml`, allow the compact pill to replace its primary title with the current lyric when lyrics mode is active.
- In `MediaControlWidget.qml`, base compact lyric swap decisions only on the single visible lyric string; do not include hidden secondary-line candidates or line-index churn in the compact swap signature.
- In `MediaControlService.qml`, model compact pill display as a state machine (`_compactDisplayedLyric`, key, and track identity), not as a mixed-candidate selector.
- In `MediaControlService.qml`, pick the compact text track first (`original` or `translated`) from settings, then resolve current/stable/next only within that track.
- Let compact display prefer current text, keep the last displayed same-track line through brief empties, and only fall forward to `next` when there is no established current display to preserve.
- In `MediaPanelContent.qml`, keep song title and artist bound to stable media metadata and render lyrics as secondary lines below them.
- In `MediaControlService.qml`, freeze `_stableCurrentLyric` and the displayed lyric lines while `MediaService.playbackState === "paused"` so weak NetEase pause payloads cannot rewind the visible lyric.
- During paused lyric playback, prefer `MediaService` for playback state and timeline, and treat NetEase lyric updates as advisory until playback resumes.

## Verification
- Play a song with multi-second gaps between lyric lines and confirm the widget does not flash back to player metadata.
- Watch the compact widget and expanded panel while playback continues; neither should pulse or swap content without a real track change.
- Watch the compact widget near lyric boundaries and confirm it only changes when the single visible lyric line changes, not when `next` or hidden secondary lyric candidates change.
- Toggle between original and translated lyric preference during playback and confirm the compact pill switches tracks immediately without cross-track fallback.
- Verify anti-flicker changes do not leave the compact pill one line behind after a lyric boundary.
- Pause during the middle of a song and confirm the compact pill keeps the current lyric instead of jumping back to the first lyric or credit line.
- Open the media panel while lyrics are active and confirm the panel keeps stable title/artist text with lyrics rendered underneath.
- Run `timeout 5 qs --path .` after modifying services or QML display code.

## References
- `services/MediaControlService.qml`
- `modules/bar/widgets/MediaControlWidget.qml`
- `modules/bar/media/MediaPanelContent.qml`
- `services/NeteaseWebLyricsService.qml`
