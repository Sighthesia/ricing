# NetEase Web Lyrics Firefox Extension

This extension is the supported path for NetEase web lyrics capture in `DymicShell`.

## Install

1. Open `about:debugging#/runtime/this-firefox`
2. Click `Load Temporary Add-on...`
3. Select `scripts/firefox-extensions/netease-web-lyrics/manifest.json`
4. Open `https://music.163.com/st/webplayer`
5. Make sure the local bridge is alive: `curl http://127.0.0.1:18765/health`

## Verify

Play a song on `music.163.com/st/webplayer`, then run:

```bash
curl http://127.0.0.1:18765/health
```

Success looks like a non-empty `songId` and `rawLyric`.
If the track has translated lyrics, `translatedLyric` also appears in the bridge payload.

If you only see `songId/title/artist` first, that means runtime metadata capture works and the extension is now attempting a direct lyric fetch using the song ID.

If the extension is loaded but lyrics are not captured yet, the bridge may temporarily show one of these debug titles:

- `__extension_loaded__`: content script loaded
- `__probe_injected__`: page probe injected through `wrappedJSObject.eval`
- `__probe_injected_fallback__`: fallback inline injection path used
- `__probe_injection_failed__`: probe injection failed before runtime capture started

## How Lyric Capture Works

The web player does not expose lyrics in stable DOM nodes, so the extension does not scrape the page text.

Instead it uses three runtime sources together:

1. Lyric API responses
   The page probe still watches page-side `/lyric` responses, but the extension no longer depends on that path alone. Once it sees a stable `songId`, the background script directly requests `https://music.163.com/api/song/lyric?id=...` and forwards both `lrc.lyric` and `tlyric.lyric` to the local bridge.

2. Playback position
   The probe reads playback progress from `navigator.mediaSession.setPositionState(...)` when available, and falls back to discovered `audio` elements for `currentTime` and `duration`.

3. Track metadata
   The probe watches `Media Session` metadata plus track-like API payloads to keep `title`, `artist`, and `songId` aligned with the active lyric payload.

The page probe sends only lyric-related state to the content script, and the content script forwards that state to the local bridge at `http://127.0.0.1:18765/push`.
