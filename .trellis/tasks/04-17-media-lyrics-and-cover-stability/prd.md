# Task: media-lyrics-and-cover-stability

## Goal

Stabilize the media experience so active lyrics do not briefly fall back to song metadata during playback, and currently playing media artwork can be recovered after bar reloads without requiring a track restart.

## Problems

- The compact media widget occasionally flashes from lyric text to song title and back to lyrics within a very short interval.
- After reloading the bar while media is already playing, the artwork can remain empty because the current cover cannot be fetched again from the active session.

## Scope

- Analyze the existing NetEase web lyrics bridge, lyrics session handling, media source selection, and artwork presentation pipeline.
- Fix the root cause of transient lyric fallback in the compact media flow and any directly shared panel flow it affects.
- Fix the root cause of missing artwork after bar reload for already-playing media.
- Keep the change scoped to the media widget/panel, related services, and directly connected lyrics bridge or artwork recovery code.

## Acceptance Criteria

- [ ] During active lyric playback, the widget no longer briefly flashes from lyrics to track metadata and back because of transient weak payloads or source switching.
- [ ] After reloading the bar while a track is already playing, artwork is recovered again without needing the track to restart.
- [ ] Existing media controls, title/artist display, lyrics preference behavior, and panel behavior remain functional.
- [ ] `timeout 5 qs --path .` passes after the change.
