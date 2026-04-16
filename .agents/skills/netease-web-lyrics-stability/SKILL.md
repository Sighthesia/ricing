---
name: netease-web-lyrics-stability
description: Use when debugging or changing the NetEase web lyrics bridge, especially if lyrics flash back to song title, player name, or stop advancing because weak payloads briefly override the active lyrics session.
---

# NetEase Web Lyrics Stability

Treat NetEase lyrics as a latched session, not a stream of individually trustworthy payloads.

## When to Use
- Working on `scripts/firefox-extensions/netease-web-lyrics/*`.
- Working on `services/NeteaseWebLyricsService.qml` or `services/MediaControlService.qml`.
- The media widget briefly flashes `START`, `Mozilla firefox`, or `No Media` while lyrics are active.
- Lyrics stop advancing, jump back to the first line, or switch between lyric text and song metadata.

## Symptoms
- `MediaControlWidget` toggles `_useLyricsAsPrimaryText` between `true` and `false` during playback.
- `MediaControlService._preferLyricsMediaSource` flips even though the same song is still playing.
- Logs show `neteaseActive=false` while `neteaseHasLyrics=true` or cached lyric lines still exist.
- Firefox MPRIS metadata (`START`, `Mozilla firefox`) appears for one frame between lyric updates.

## Root Cause
- The NetEase web path has multiple weak state sources: frame-local probe data, async lyric fetches, and transient empty/stopped payloads.
- A single weak payload can temporarily clear `title`, `artist`, `playbackState`, `positionMs`, or lyric fields even though the current lyrics session is still valid.
- If the UI reacts to those transient empties immediately, it falls back to Firefox MPRIS metadata and visibly flashes.

## Transferable Lesson
- For browser-driven media bridges, do not assume each payload is complete or authoritative.
- When multiple sources describe one session, publish a stable session snapshot and add latch/timeout behavior before letting the UI switch sources.

## Correct Pattern
- In `background.js`, score competing frame payloads and forward only the strongest recent candidate.
- In `NeteaseWebLyricsService.qml`, preserve session metadata and timeline when a payload is clearly weaker than the current session.
- In `MediaControlService.qml`, latch the lyrics source for a short grace window and cache the last valid lyric lines so the UI never reacts to a one-frame empty state.
- Keep media controls on `MediaService`, but keep lyrics title/timeline selection on the latched NetEase session while lyrics mode is active.

## Verification
- Reload the Firefox temporary add-on, refresh `https://music.163.com/st/webplayer`, and play a track with synced lyrics.
- Run `curl -s "http://127.0.0.1:18765/health"` and confirm `positionMs` advances with non-empty lyric payloads.
- Watch the media widget and confirm it does not flash back to `START`, `Mozilla firefox`, or `No Media` between lyric updates.
- Run `timeout 5 qs --path .` after service or widget changes.

## References
- `scripts/firefox-extensions/netease-web-lyrics/background.js`
- `scripts/firefox-extensions/netease-web-lyrics/content-script.js`
- `services/NeteaseWebLyricsService.qml`
- `services/MediaControlService.qml`
- `modules/bar/widgets/MediaControlWidget.qml`
