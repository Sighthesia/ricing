# Task: media-source-swap-between-players

## Goal

Prevent media title, progress, and related state from swapping back and forth every second when more than one media source is active.

## What I already know

* The bug appears only when two media sources are active.
* The visible symptom is that progress and media information alternate every second.
* The most likely owner is `services/MediaService.qml`, which selects the current active MPRIS player.

## Requirements

* Pick one stable active media source when multiple players are present.
* Do not swap visible media state every second just because multiple sources report playback updates.
* Preserve normal single-player behavior.

## Acceptance Criteria

* [ ] With two active media sources, the widget keeps one stable source instead of alternating each second.
* [ ] Single-source media behavior remains unchanged.
* [ ] `timeout 5 qs --path .` passes.

## Technical Notes

* Suspect file: `services/MediaService.qml`
* Validation command: `timeout 5 qs --path .`
