# Technical Design

## Boundaries

- Keep `LazerSettingsOverlay` responsible for panel lifecycle and fixed owner geometry.
- Keep `LazerSettingsPanel` responsible for sidebar/content composition, but remove the panel-level opacity coupling from the open/close progress.
- Keep `LazerSettingsSidebar` responsible for navigation item lifecycle. Closing the panel must not call the same visual reset used for a fresh session until the panel exit has completed.
- Keep `LazerSettingsChoice` as the source of menu state and expose only measured layout information needed by its parent row.
- Keep `LazerSettingsContent` as the single overlay owner for dropdown painting, outside-click handling, focus, and bridge requests.
- Keep category pages as `Flickable` owners of their rows. A Choice row reserves the menu height in its own layout so later rows are pushed by normal `Column` geometry.

## Data Flow And Contracts

1. `LazerSettingsChoice.menuOpen` becomes the single source of truth for whether its row reserves dropdown space.
2. `LazerSettingsChoice` exposes a readonly or derived `dropdownReservedHeight` based on the menu model and the shared dropdown max height. It is zero when closed.
3. `LazerSettingsRow` observes the injected Choice's reserved height and adds it only for `choicePresentation`; the row's card and content host grow with the row.
4. `LazerSettingsContent.showDropdownFor()` sets the active Choice, opens its state, and positions the overlay menu below the Choice header. Geometry is recalculated after the row layout settles and whenever the current page scrolls or changes size.
5. The menu overlay remains above the clipped page viewport, but its reserved row space guarantees that its visible surface does not cover later rows. If the page needs more space, its existing Flickable content height and scrolling provide it.
6. A second tap on an open Choice calls `closeMenu()` instead of returning from `openMenu()`. Closing through any existing path clears both the Content owner and Choice state.
7. Panel enter/exit keeps Sidebar and Content opacity at `1`; `progress` continues to own their translation. Existing internal sidebar item stagger and category transitions remain separate and are not used to fade the whole panel.
8. Sidebar session teardown is split from panel close: close starts no destructive nav opacity reset, and the final closed callback resets transient stagger state after the exit animation. Reopening starts a fresh stagger session.

## Geometry

- Increase Slider thumb width from `6px` to `8px` and default marker width from `3px` to `5px`.
- Preserve the track coordinate system and center each widened element at its existing fraction, clamping its `x` against the track width.
- Dropdown reserved height is `min(dropdownMaxHeight, model.length * 30 + 8)` plus the existing row spacing only where the page Column requires it; no absolute page offsets are introduced.
- Overlay menu `y` is the mapped Choice header bottom, not the expanded row bottom. The row expansion below the header is the collision-free space occupied by the menu.

## Compatibility And Rollback

- No setting keys, persisted values, service APIs, or external bridge signals change.
- Existing source ownership checks remain mandatory; foreign Choice requests must still be ignored.
- If the push-layout implementation exposes clipping or scroll regressions, rollback is limited to the row reservation and placement changes; the toggle, sidebar lifecycle, slider width, and Choice click fixes remain independently revertible.

## Verification Strategy

- Add pure/control assertions for panel opacity behavior, sidebar visibility through close, widened slider geometry, Choice toggle-close behavior, and Choice row height growth.
- Run `qmllint` on all touched QML and tests, `python3 -m pytest -q`, `git diff --check`, and `timeout 15s qs -p .`.
- Treat a silent QML test runner as an environment limitation and do not report assertions as passed without output.
