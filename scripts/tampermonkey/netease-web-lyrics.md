# NetEase Web Lyrics Tampermonkey Script

This is the persistent install path for DymicShell NetEase lyrics capture.

## File

- `scripts/tampermonkey/netease-web-lyrics.user.js`

## Install

1. Open Tampermonkey and create a new userscript.
2. Paste the contents of `scripts/tampermonkey/netease-web-lyrics.user.js`.
3. Save and make sure the script is enabled.
4. Open `https://music.163.com/st/webplayer`.

## Verify

With a song playing, check the bridge health endpoint:

```bash
curl http://127.0.0.1:18765/health
```

Expected fields:

- `songId`
- `title`
- `artist`
- `playbackState`
- `positionMs`
- `durationMs`
- `rawLyric`
- `translatedLyric` when available

## Notes

- The userscript keeps working across browser restarts.
- The localhost bridge remains `http://127.0.0.1:18765/push`.
