# Task: media-lyrics-cover-stability

## Goal

Fix media track switches so returning to the original song restores its cover art reliably, and stale title/lyric text from the switched-to song does not remain visible before the first real lyric of the restored track arrives.

## What I already know

* The compact media widget renders the primary title from `MediaControlService.compactPrimaryLyric` when lyrics mode is active.
* The expanded media panel renders title/artist from `MediaService`, while lyrics come from `MediaControlService`.
* `MediaControlService` already latches lyrics by session and track keys, but its current reset logic can keep old displayed text alive until a new lyric arrives.
* The NetEase bridge invalidates stale lyrics on track/session changes, but the visible UI can still keep a prior song's text during the gap before the new track's first lyric.

## Assumptions (temporary)

* The cover-art loss is caused by media state not being re-latched cleanly when the track switches back, not by the artwork component itself.
* The fix should stay local to the media/lyrics pipeline unless a shared media source reset is clearly required.

## Requirements

* Clear stale lyric display state immediately when the active track session changes.
* Preserve stable lyrics only within the same track/session, not across a return to a previously played song.
* Restore artwork display for the active track without requiring playback restart.
* Keep existing compact/panel layout and lyric preference behavior intact.

## Acceptance Criteria

* [ ] Switching away from a song and back to it no longer leaves the previous song's title or lyric visible before the restored song produces a lyric line.
* [ ] The restored song's cover art is shown again once the media source exposes it.
* [ ] Existing compact and expanded media behavior remains otherwise unchanged.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* Media lyric and artwork state is stable across track switches.
* The change is minimal and scoped to the media pipeline.
* Validation passes.

## Technical Approach

Inspect the media service and lyrics latch/reset flow, then clear or reinitialize stale displayed state on track/session transitions so the UI cannot keep old text or artwork across a song swap.

## Out of Scope

* Reworking the overall media widget design.
* Adding new settings.

## Technical Notes

* Relevant files inspected:
  * `services/MediaControlService.qml`
  * `modules/bar/media/MediaPanelContent.qml`
  * `modules/bar/widgets/MediaControlWidget.qml`
  * `scripts/firefox-extensions/netease-web-lyrics/background.js`
  * `scripts/firefox-extensions/netease-web-lyrics/page-probe.js`
* Existing related task: `.trellis/tasks/04-17-media-lyrics-and-cover-stability/`
