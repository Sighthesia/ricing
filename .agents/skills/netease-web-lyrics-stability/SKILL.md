---
name: netease-web-lyrics-stability
description: Use when debugging or changing the NetEase web lyrics bridge, especially if track changes lose `songId`, bridge payloads leak placeholder metadata, or NetEase lyric recovery stops after weak browser payloads.
---

# NetEase Web Lyrics Stability

Treat NetEase bridge payloads as incomplete browser hints that must be normalized before they become a lyrics session.

## When to Use
- Working on `scripts/firefox-extensions/netease-web-lyrics/*`.
- Working on `services/NeteaseWebLyricsService.qml`.
- Refreshing the NetEase page mixes bridge state with `location.href`, placeholder titles, or probe-injection markers.
- Track changes update metadata but lose `songId`, so lyrics stop recovering.

## Symptoms
- `curl -s "http://127.0.0.1:18765/health"` shows a valid title but an empty or stale `songId`.
- Bridge payloads briefly contain `__probe_*__` markers, `location.href`, or other injection-only metadata.
- Track changes clear old lyrics correctly, but the new song never restores synced lyrics.

## Root Cause
- The NetEase web path combines probe data, async lyric fetches, and extension bootstrap state, and none of those payloads are trustworthy in isolation.
- Track changes can publish fresh `title` and `artist` before the new `songId` arrives.
- If placeholder bootstrap payloads or metadata-only payloads are forwarded directly, the bridge can leak URLs, probe markers, or lose the ability to recover lyrics.

## Stability Rules
- Expect metadata to update before `songId` during a track change; a missing `songId` is not proof that the new song is invalid.
- Invalidate the old lyrics session first, so new `title` metadata never reuses stale lyrics.
- Do not forward extension bootstrap placeholders like `__probe_*__` or `location.href` into the bridge state.
- If `songId` is missing, the background should fall back to a conservative lookup from `title + artist + duration`, then re-request lyrics and recover the session.
- Keep detailed page logging disabled by default; enable it only for targeted debugging.

## Transferable Lesson
- For browser-driven media bridges, do not assume each payload is complete or authoritative.
- Keep source-normalization rules close to the bridge boundary, and keep display-layer latching separate.

## Correct Pattern
- In `content-script.js`, keep probe bootstrap diagnostics local; do not push placeholder payloads to the bridge.
- In `page-probe.js`, invalidate the old session when track metadata changes and only accept lyrics responses that still match the latest request.
- In `background.js`, score competing frame payloads, recover missing `songId` conservatively, and only then request lyrics.
- In `NeteaseWebLyricsService.qml`, preserve session metadata and timeline when a payload is clearly weaker than the current NetEase session.
- Keep display-layer flash prevention in `lyrics-display-stability`; this skill is for bridge-side normalization and recovery.

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
- `scripts/firefox-extensions/netease-web-lyrics/page-probe.js`
- `services/NeteaseWebLyricsService.qml`
