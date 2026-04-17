# NetEase Web Lyrics Tampermonkey Script

This is the persistent install path for DymicShell NetEase lyrics capture.

## File

- `scripts/tampermonkey/netease-web-lyrics.user.js`

## Install

1. Open Tampermonkey and create a new userscript.
2. Paste the contents of `scripts/tampermonkey/netease-web-lyrics.user.js`.
3. Save and make sure the script is enabled.
4. Open `https://music.163.com/st/webplayer`.
5. Fully reload the page after saving so Tampermonkey reinjects the updated grants and listeners.

If you already installed an older copy, replace the full script and save again so Tampermonkey refreshes the granted APIs.

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

If all fields stay empty, open the browser console on the NetEase page and check for `DymicShell:NeteaseLyricsUserscript` warnings. The most useful signals are bridge POST failures and whether payloads arrive through `postMessage` or the custom event fallback.

## Diagnostics

To enable verbose userscript diagnostics in the page console:

```js
localStorage.setItem('dymicshellNeteaseLyricsDebug', '1')
location.reload()
```

To disable them again:

```js
localStorage.removeItem('dymicshellNeteaseLyricsDebug')
location.reload()
```

## Notes

- The userscript keeps working across browser restarts.
- The localhost bridge remains `http://127.0.0.1:18765/push`.
- Firefox Tampermonkey can isolate userscript and page-window listeners differently from the old extension path, so this script now listens in the sandbox window and also accepts a DOM custom-event fallback from the injected page probe.
