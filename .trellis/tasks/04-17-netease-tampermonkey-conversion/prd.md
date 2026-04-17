# Task: netease-tampermonkey-conversion

## Goal

Replace the current temporary Firefox extension path for NetEase web lyrics capture with a Tampermonkey userscript path that remains installed across browser restarts while preserving the localhost bridge integration used by DymicShell.

## Problems

- The current Firefox extension flow is practical for debugging but not for persistent installation.
- The lyrics capture path still needs page-level metadata, playback progress, lyric fetch handling, and bridge push behavior.

## Scope

- Analyze the existing Firefox extension implementation under `scripts/firefox-extensions/netease-web-lyrics/`.
- Implement an equivalent or improved Tampermonkey userscript under a repo-owned script path.
- Preserve bridge compatibility with `http://127.0.0.1:18765/push` and existing service expectations.
- Add usage documentation for installing and verifying the userscript path.
- Keep the existing Firefox extension files unless a small compatibility update is directly useful.

## Acceptance Criteria

- [ ] A Tampermonkey userscript exists in the repository and captures NetEase web playback/lyric state for DymicShell.
- [ ] The userscript can persist as a normal Tampermonkey installation instead of a temporary Firefox add-on.
- [ ] The local bridge still receives usable metadata, position, and lyrics payloads.
- [ ] Documentation explains installation and verification.
- [ ] `timeout 5 qs --path .` passes after the change.
