---
name: browser-media-metadata-fallback
description: Stabilize media UI when browser MPRIS metadata is incomplete, delayed, or inconsistent. Use when lyrics or artwork disappear, flicker, or fail to update for web players like Firefox/Chrome, especially when MPRIS omits trackArtUrl, artist fields churn, temporary file artwork expires, or webpage metadata is richer than the exported media session.
---

# Browser Media Metadata Fallback

Treat browser MPRIS as a lossy transport, not the source of truth.

## Use This Pattern

- Confirm the symptom is browser-specific or much worse in browser players.
- Check whether `trackArtUrl` is empty, stale, or points to short-lived temp files.
- Check whether title/artist briefly become empty or change formatting during playback.
- Check whether webpage-side metadata already exists and is richer than MPRIS.

## Diagnose In This Order

1. Distinguish source failure from render failure.
2. Log raw player metadata and the service-selected metadata separately.
3. Verify whether the browser webpage already has the missing field.
4. Only after that, change fallback or cache behavior.

## Common Failure Shapes

### `trackArtUrl` is empty

The browser never exported artwork. Do not keep tuning MPRIS recovery windows forever. Bridge webpage metadata instead.

### `trackArtUrl` is non-empty but `Image` cannot open it

The browser exported a short-lived temp file. Show a fallback icon immediately, blacklist the failed URL, and avoid re-adopting that same URL every poll.

### Lyrics or artwork flicker every second

The 1s poll is rewriting equivalent metadata, or a fallback branch resets latch state repeatedly.

- Compare normalized track keys, not raw strings.
- Treat empty artist churn as the same track if title is stable.
- Do not restart recovery timers for URLs already known bad.

### Timestamp-based recovery behaves strangely

Do not store `Date.now()` in QML `int`. Use `real` for wall-clock timestamps to avoid overflow.

## Recommended Fix Shape

### 1. Bridge richer webpage metadata

- Extend the webpage userscript/probe payload with missing fields such as `artUrl`.
- Prefer direct track payload fields first, then media-session artwork arrays.
- Pass those fields through the local bridge unchanged except for light normalization.

### 2. Keep shell-side state separate

- Store webpage metadata in its own service state.
- Preserve it across weak payload churn for the same session.
- Let the UI-facing media control layer choose between MPRIS and webpage fallbacks.

### 3. Prefer MPRIS when it is valid, fallback otherwise

- Use MPRIS artwork first when it exists and still loads.
- Fallback to webpage artwork when MPRIS artwork is empty.
- Do not let a failed temp-file artwork path repeatedly re-enter the UI.

### 4. Normalize track identity

- Normalize title by trimming, lowercasing, and collapsing whitespace.
- Normalize artists by tokenizing common separators such as `,`, `/`, `&`, `feat`.
- When one side temporarily drops artist data, allow title-only equivalence to preserve the latch.

## Validation Checklist

- Switching between two songs updates lyrics without 1s blinking.
- A browser song with empty `trackArtUrl` still shows webpage-derived artwork.
- A failed temp-file artwork URL falls back to the default icon and stays stable.
- Recovery timestamps remain non-negative and monotonic.
- Startup succeeds with `timeout 5 qs -p .`.

## Useful Temporary Debug Logs

Log one structured line per sync containing:

- player identity
- track title
- track artist
- raw `trackArtUrl`
- webpage `artUrl`
- chosen UI `artUrl`
- cache hit
- failed-url blacklist hit
- track/session key

Remove or gate these logs behind an env var once the issue is understood.
