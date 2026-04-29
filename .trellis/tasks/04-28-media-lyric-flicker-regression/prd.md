# Task: media-lyric-flicker-regression

## Goal

Remove the once-per-second lyric flicker regression introduced by the recent session-gating change, while still preventing stale lyrics from leaking across track switches.

## What I already know

* The regression appeared immediately after tightening visible lyric gating in `services/MediaControlService.qml`.
* The NetEase bridge emits frequent timeline updates, including updates where session metadata remains valid but the current lyric text does not change.
* The compact widget uses `MediaControlService.compactPrimaryLyric` and can visibly flicker if `currentLyric` briefly becomes empty on each timeline tick.

## Requirements

* Stop the once-per-second lyric flicker.
* Keep stale lyrics from leaking across real track/session changes.
* Preserve existing compact and panel lyric behavior outside this regression.

## Acceptance Criteria

* [ ] During playback, the compact lyric no longer flashes once per second.
* [ ] Switching tracks still clears old-song lyric carryover correctly.
* [ ] `timeout 5 qs --path .` passes.

## Technical Notes

* Suspect area: `services/MediaControlService.qml` visible lyric/session gating added in the prior fix.
* Validation command: `timeout 5 qs --path .`
