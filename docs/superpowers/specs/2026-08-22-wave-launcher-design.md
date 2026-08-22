# Wave Launcher Design

## Status

Approved conversational design. This document defines the first frontend
rewrite slice: a full-screen wave launcher. It does not implement the feature.

## Scope

The new frontend treats the current Island implementation and its related
pages as deprecated. `IslandService`, old Island pages, and old Island entry
points are not dependencies of this design.

The first user-facing feature is a full-screen launcher that reuses the wave
surface. The existing Wiki, News, and Beatmap routes may be removed from the
new frontend. A future control-center route may use the same wave surface, but
control-center contents are explicitly out of scope for this slice.

The launcher is opened directly from the top-bar launcher entry or a keyboard
shortcut. It does not open an Island page first.

## Goals

- Reuse the existing 85% wave surface, sidebar, title area, route lifecycle,
  focus handling, and close behavior.
- Open with the search field focused and ready for input.
- Show all applications for an empty query.
- Keep application, clipboard, and shortcut search in one result area.
- Make keyboard navigation the primary interaction while retaining pointer
  support.
- Keep the top bar visible and outside the wave window geometry.
- Keep data access and execution behind explicit service interfaces.

## Non-goals

- Rebuilding the old Island overview or control-center pages.
- Implementing the control center in this slice.
- Keeping Wiki, News, or Beatmap as launcher sidebar modes.
- Adding a settings UI for managing favorites or sort weights.
- Making the page responsible for application enumeration, clipboard storage,
  or shortcut side effects.

## Architecture

The current route-specific fullscreen owner is split conceptually into a
generic shell and launcher content:

```text
top-bar entry / keyboard shortcut
          |
          v
LauncherService.open()
          |
          v
WaveSurfaceHost.openRoute("launcher")
          |
          v
LauncherPage
  +-- apps
  +-- clipboard
  +-- shortcuts
```

### WaveSurfaceHost

`WaveSurfaceHost` owns only generic fullscreen surface behavior:

- 85% centered surface geometry.
- Window placement below the top bar, including floating-bar margins.
- Four-layer wave backdrop and open/close progress.
- Sharp rectangular body, title area, sidebar, and content viewport.
- External click-to-close zones.
- `Escape` handling and focus restoration to the opener.
- Surface open/close lifecycle and route transition lifecycle.
- Input mask limited to the actual wave surface and outside close zones.

The host knows that `launcher` is the active route, but it does not know how
applications, clipboard entries, or shortcuts are queried or executed.
Future full-screen routes can provide another content page without duplicating
window, mask, wave, or focus ownership.

### LauncherPage

`LauncherPage` owns launcher-specific behavior:

- Search field and query state.
- `apps`, `clipboard`, and `shortcuts` modes.
- Result selection, sorting, and list scrolling.
- Loading, empty, error, and execution feedback.
- Mode changes from sidebar actions or query prefixes.
- Executing the selected result and reporting success or failure.

The sidebar has exactly three first-release entries: Apps, Clipboard, and
Shortcuts. Wiki, News, and Beatmap are not launcher entries.

## Launcher Interaction

On open, the launcher enters `apps` mode, focuses the search field, and accepts
keyboard input immediately.

An empty query displays all applications. The default stable ordering is:

1. Favorite weight descending.
2. Recent-use timestamp descending.
3. Locale-aware display name ascending.
4. Stable unique identifier ascending.

Typed application queries use the same ordering after filtering. The existing
query prefixes select the other data sources:

- `>clip ` selects clipboard results.
- `>key ` selects shortcut results.

Selecting a sidebar mode changes the query prefix as needed while preserving
search focus. Switching modes does not reopen the wave surface or restart the
fullscreen wave animation.

Keyboard and pointer behavior:

- `Enter` executes the selected result.
- `Up` and `Down` move the selected result.
- `Escape` first handles active input/page state, then closes the surface.
- A pointer click executes the clicked result.
- Successful execution closes the wave surface.
- Failed execution keeps the surface open and shows an error.

The selected index is clamped whenever a refresh reduces the result count.
Refreshing results must not unexpectedly replace the query, mode, or focus.

## Service Contracts

The page consumes a minimal launcher-facing contract rather than reaching into
data services directly:

```text
results / model
loading
error
refresh(query, mode)
execute(item)
```

Application entries expose at least a display name, description, icon, and
launch identifier or command. Clipboard entries expose preview text, time,
type, and a write-back action. Shortcut entries expose a name, key
combination, description, and execution action.

`LauncherService` owns launcher session state, prefix parsing, sorting
coordination, and execution outcomes. Separate backend services remain
responsible for application enumeration, clipboard storage, and shortcut
execution. The page does not fabricate fallback results or silently fall back
to deprecated Island or content routes.

## States and Errors

- Initial fetch: show a loading state while retaining the search field.
- Empty result: show an explicit empty state and keep the surface interactive.
- Data-source failure: show an error state and a retry action; do not close.
- Execution failure: show an error in the surface; do not close.
- Execution success: record recent-use state when applicable, then close.
- Unavailable service: expose the unavailable state rather than fake results.

## Visual and Motion Direction

The surface reuses the project sharp osu!lazer visual language:

- Major surfaces remain right-angled geometric rectangles.
- Wave layers remain geometric and clipped to the 85% surface viewport.
- Component-level details may use restrained rounding, but the page is not a
  collection of nested rounded cards.
- The launcher palette is independent of Wiki, News, and Beatmap palettes.
- The title area uses launcher/search semantics rather than old content labels.
- Result rows use fixed dimensions, sharp geometry, and the established
  settings-panel highlight, click-flash, and keyboard-focus feedback.
- Search, result rows, and sidebar controls do not introduce a second motion
  system.
- Wave backdrop progress remains independent from body progress. The backdrop
  leads the body without reading as an oversized sheet flying into place.
- Reduced-motion mode skips position animation while preserving final geometry
  and required opacity state.

## Testing Strategy

Pure logic tests cover:

- Query-prefix parsing and mode selection.
- Stable favorite/recent/name/identifier sorting.
- Result selection clamping after refresh.
- Empty and error state transitions.
- Keyboard action precedence.
- Successful and failed execution outcomes.

Component tests cover:

- Initial focus on open.
- Sidebar mode switching without restarting the wave surface.
- `Enter`, `Up`, `Down`, and `Escape` behavior.
- Pointer execution.
- Empty, loading, and error rendering.
- Focus restoration and close behavior.

Wave shell tests retain existing geometry, top-bar exclusion, wave progress,
route lifecycle, and reduced-motion coverage after route-specific Wiki/News/
Beatmap assertions are removed or replaced with launcher assertions.

## Acceptance Criteria

- Opening from the top bar or keyboard shortcut shows the full-screen wave
  launcher directly.
- The search field is focused before the first user keystroke.
- Empty query shows all applications in the specified default order.
- Apps, Clipboard, and Shortcuts are the only sidebar modes.
- `>clip` and `>key` switch the result source without leaving the surface.
- Keyboard and pointer execution work and successful execution closes the
  surface.
- Empty and failed states remain visible and actionable.
- The top bar is never visually or interactively covered by the wave window.
- No implementation path depends on deprecated Island or old Wiki/News/Beatmap
  frontend routes.
