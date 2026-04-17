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
- A single weak payload can temporarily clear `title`, `artist`, `songId`, `playbackState`, `positionMs`, or lyric fields even though the current lyrics session is still valid.
- If the UI reacts to those transient empties immediately, it falls back to Firefox MPRIS metadata and visibly flashes.

## Stability Rules
- Expect metadata to update before `songId` during a track change; a missing `songId` is not proof that the new song is invalid.
- Invalidate the old lyrics session first, so new `title` metadata never renders with stale lyrics.
- If `songId` is missing, the background should fall back to a conservative lookup from `title + artist + duration`, then re-request lyrics and recover the session.
- Keep detailed page logging disabled by default; enable it only for targeted debugging.

## Transferable Lesson
- For browser-driven media bridges, do not assume each payload is complete or authoritative.
- When multiple sources describe one session, publish a stable session snapshot and add latch/timeout behavior before letting the UI switch sources.

## Correct Pattern
- In `background.js`, score competing frame payloads and forward only the strongest recent candidate.
- If the frame payload has metadata but no `songId`, fall back to `title + artist + duration` matching before requesting lyrics again.
- In `NeteaseWebLyricsService.qml`, preserve session metadata and timeline when a payload is clearly weaker than the current session.
- In `MediaControlService.qml`, latch the lyrics source for a short grace window and cache the last valid lyric lines so the UI never reacts to a one-frame empty state.
- Keep media controls on `MediaService`, but keep lyrics title/timeline selection on the latched NetEase session while lyrics mode is active.

## Debug Order
- First check page-probe invalidation: did the old session get cleared when metadata changed?
- Then check lyric request flow: was a lyric fetch triggered after the new track metadata appeared?
- Then check background selection flow in order: `incoming` -> `select` -> `push`.
- Only turn on verbose page logs when narrowing a specific failure window; leave them off for normal use.

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
