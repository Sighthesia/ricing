# Lazer Top Bar Design

## Goal

Build a Qt 6 and Quickshell top status bar inspired by osu!lazer. The result should provide a polished, keyboard-accessible visual shell that can later be connected to real settings, navigation, community, media, and notification features.

## Scope

In scope:

- A 46px full-width top bar on every screen
- A persistent full-width background plus three independently owned interactive zones
- System controls, four-mode selector, utility shortcuts, user profile, clock, system uptime, and notification toggle
- Bundled SVG icon assets with no icon-font dependency
- Shared color and motion tokens
- Reusable QML `DropdownMenu`, `ContextMenu`, and `ModalOverlay` interaction primitives
- Responsive utility-button reduction on narrow screens
- Pointer, keyboard, and reduced-motion behavior
- QML tests and Quickshell startup verification

Out of scope:

- Opening real settings, home, news, changelog, wiki, ranking, library, chat, community, or player surfaces
- Real authentication or remote osu! profile data
- Notification history or desktop notification integration
- Media playback integration
- Persisting the selected game mode or bell state across shell restarts
- Recreating osu! trademarks or copying proprietary assets

## Selected Direction

Use a full-width background window and three interactive layer-shell windows per screen.

The background preserves the continuous osu!lazer-style dark menu-bar silhouette. The interactive windows provide clear ownership boundaries for future menus and expanding surfaces without making the entire bar consume pointer input.

## Alternatives Considered

### One full-width interactive window

This is simpler and would be adequate for the current static bar. It was rejected because future menus and independently expanding regions would share one large input surface and become harder to isolate.

### Three floating islands without a full-width background

This aligns more closely with Afloat's attached-island visual language. It was rejected because the requested visual target is a continuous dark osu!lazer menu bar.

### One monolithic QML file

This minimizes initial file count but mixes window ownership, button states, responsive behavior, clock data, and reusable overlays. It was rejected for maintainability and testability.

## Window Architecture

`shell.qml` creates one per-screen top-bar composition through `Variants { model: Quickshell.screens }`.

Each screen composition owns four persistent windows:

- Background window: full screen width, 46px implicit height, top anchored, dark background, bottom corners at 12px, and the only window reserving workspace through `exclusiveZone: 46`.
- Left zone: content-width interactive window containing system controls and the mode selector.
- Utility zone: content-width interactive window containing the utility shortcuts.
- Status zone: content-width interactive window containing profile, clock, uptime, and notifications.

The three interactive windows do not reserve additional space. Their backgrounds match the base bar so all four surfaces read as one continuous object. Transparent space outside each zone does not intercept pointer input.

The persistent-window model avoids replacing surfaces when state changes. Future dropdowns and overlays can attach to the zone that triggered them.

## Layout

### Left Zone

The left zone contains:

- Settings button
- Home button
- A visual separator
- osu! standard mode
- Taiko mode
- Catch mode
- Mania mode

The default mode is osu! standard. Inactive icons use `#A0A0A0`. The selected icon uses `#00FFA2` and a short white indicator below it.

One persistent indicator moves between mode slots over 160ms. It must not be destroyed and recreated or hard-cut between modes.

### Utility Zone

The utility zone contains, in order:

- News/RSS
- Changelog/code
- Wiki/book
- Ranking/podium with star
- Beatmap library/music card
- Chat
- Community/globe
- Separator
- Music player

Buttons use a 32px interaction target with an approximately 20px visual icon and 12px nominal spacing between entries.

### Status Zone

The status zone contains:

- Username, defaulting to `Sighthesia`
- A 32px square avatar with 4px corners
- Clock-face icon with a pink hand
- Current local time as `hh:mm:ss`
- System uptime as `已运行 hh:mm:ss`
- Notification bell

The username and avatar source are public component properties. If the avatar cannot load, the block displays the first username character as a local fallback.

## Responsive Behavior

The left and status zones stay visible at all supported widths.

When horizontal space is insufficient, the utility zone reduces entries in this order:

1. Community
2. Chat
3. Ranking
4. Wiki
5. Changelog
6. News
7. Library

The music-player entry is retained as the highest-priority utility. Removal transitions through opacity before the item stops consuming layout width. At very small widths, the utility zone may contain only the music-player entry.

No required left-zone or status-zone content may overlap or be clipped by a neighboring zone.

## Visual System

A `LazerTheme` singleton owns shared visual values:

- `bgDark: #18171C`
- `osuPink: #FF66AA`
- `osuGreen: #00FFA2`
- `iconInactive: #A0A0A0`
- Primary text: near-white with dark-theme contrast suitable for body text
- Muted text: sufficiently bright for the dark background
- Disabled state: visually distinct without becoming illegible
- Bar height: 46px
- Bottom radius: 12px
- Icon visual size: approximately 20px
- Standard target size: 32px

Icons are bundled SVG files. They are original generic geometric representations, not copied osu! assets. A QML tinting layer applies state colors at runtime so selected, hover, pressed, and disabled variants do not duplicate files.

## Motion Tokens

A `MotionTokens` singleton exposes only these durations:

- Instant feedback: 70ms
- Fast feedback: 100ms
- State transition: 160ms
- Panel entrance: 240ms
- Extended transition: 320ms

The primary easing curve is cubic-bezier `(0.22, 1, 0.36, 1)`, represented in QML with `Easing.BezierSpline`.

Interactive transitions follow these rules:

- Hover: background and foreground brighten and scale reaches `1.015` in 100ms.
- Press: scale reaches `0.985` and vertical translation reaches 1px in 70ms.
- Release: transform returns in 100ms.
- Active state: accent background or foreground changes in 160ms.
- Mode indicator: position slides in 160ms rather than flashing.
- Disabled: pointer and keyboard activation are blocked; opacity and color transition instead of hard-cutting.

## Reduced Motion

`MotionTokens.reducedMotion` is a runtime property. It should use Qt's platform animation preference when the available Qt version exposes one and otherwise default to `false`.

When reduced motion is enabled:

- Remove scale animation.
- Remove translation and sliding animation.
- Preserve short opacity and color transitions.
- Move focus and active state immediately where movement would otherwise be required.
- Preserve all state and keyboard behavior.

## Interaction State Machine

All reusable interactive controls support:

- `rest`
- `hover`
- `pressed`
- `active`
- `disabled`

State priority is `disabled`, `pressed`, `active`, `hover`, then `rest`. Focus-visible presentation is independent and remains visible when keyboard focus is present.

The mode selector and notification bell are the only controls that change local state in this release. Other top-bar controls provide visual pointer and keyboard feedback but intentionally perform no business action.

Each screen composition maintains its own selected mode and notification state. The state resets when that screen composition is recreated.

## Keyboard Behavior

Top-bar controls participate in Tab focus order from left to right.

- `Tab` and `Shift+Tab` move between controls.
- `Enter` and `Space` activate focused mode and notification controls.
- Arrow keys move within the mode group and reusable menus.
- `Escape` closes the active menu, context menu, or modal and restores focus to its opener.
- Disabled controls are skipped by keyboard navigation and cannot activate.

Visible focus treatment must meet dark-theme contrast requirements and must not depend only on color.

## Reusable Interaction Primitives

### DropdownMenu

`DropdownMenu` is a reusable anchored QML menu surface. It is delivered without top-bar business content in this release.

Open transition:

- Opacity `0 -> 1`
- Y offset `-4 -> 0`
- Scale `0.98 -> 1`
- Duration 160ms

Close transition uses the reverse values over 100ms. Pointer interaction is disabled as soon as closing begins to prevent click-through or stale activation. Arrow keys change the current item, Enter activates it, and Escape closes the menu.

### ContextMenu

`ContextMenu` shares the menu model, keyboard behavior, states, and motion tokens with `DropdownMenu`, but positions itself from a pointer-provided anchor point. It clamps to the available screen area.

### ModalOverlay

`ModalOverlay` provides a focus-contained modal surface.

- Backdrop fades in over 120ms.
- Panel fades and rises over 240ms.
- Closing uses faster reverse transitions.
- Pointer interaction outside the panel is blocked while open and closing.
- Tab navigation remains inside the modal.
- Escape closes the modal and restores opener focus.

These primitives are not wired to visual-only top-bar controls until their real content and actions are specified.

## Clock And Uptime

`ClockWidget` updates once per second with a QML `Timer`.

Current time uses the local system clock and an explicit `hh:mm:ss` format.

System uptime is read from Linux `/proc/uptime`. The integer seconds before the decimal point are formatted as hours, minutes, and seconds. Hours are not capped at 23 or 99; the field expands for long-running systems.

If `/proc/uptime` cannot be read or parsed, the widget displays `已运行 --:--:--`. It must not silently substitute the shell session duration.

## Component Boundaries

Expected frontend structure:

- `shell.qml`: Quickshell entry point and per-screen composition
- `modules/lazerbar/TopBar.qml`: coordinates the four windows for one screen
- `modules/lazerbar/BarBackground.qml`: reserves workspace and paints the full-width bar
- `modules/lazerbar/LeftZone.qml`: system controls and mode selector
- `modules/lazerbar/UtilityZone.qml`: responsive utility group
- `modules/lazerbar/StatusZone.qml`: profile, clock, uptime, and bell
- `modules/lazerbar/IconButton.qml`: shared pointer, keyboard, state, focus, and motion behavior
- `modules/lazerbar/ModeSelector.qml`: mode state and moving active indicator
- `modules/lazerbar/ClockWidget.qml`: current time and uptime presentation
- `modules/lazerbar/UserProfile.qml`: username, avatar, and fallback
- `modules/lazerbar/DropdownMenu.qml`: anchored menu primitive
- `modules/lazerbar/ContextMenu.qml`: pointer-positioned menu primitive
- `modules/lazerbar/ModalOverlay.qml`: modal primitive
- `modules/lazerbar/LazerTheme.qml`: visual tokens
- `modules/lazerbar/MotionTokens.qml`: motion and reduced-motion tokens
- `modules/lazerbar/LazerBarLogic.js`: pure formatting and responsive helpers
- `modules/lazerbar/icons/`: bundled generic SVG assets

Major QML declarations receive short English intent comments in accordance with project conventions.

## Testing Strategy

Pure helper tests cover:

- Uptime formatting at zero, under one hour, over one day, and over 99 hours
- Invalid uptime input
- Utility visibility counts at wide, medium, and narrow widths
- Utility priority ordering
- Username fallback character derivation

QML component tests cover:

- Default osu! standard selection
- Mode switching through pointer-equivalent activation and keyboard navigation
- Persistent indicator target changes instead of replacement
- Bell state toggling
- Button state priority for rest, hover, pressed, active, and disabled
- Reduced-motion transform suppression
- Dropdown and context-menu focus navigation
- Escape close and focus restoration
- Modal focus containment and immediate interaction blocking during close

Existing backend tests must continue to pass.

## Verification

Implementation is complete only when:

- `qs -p tests/qml/tst_lazer_bar_logic.qml` passes without WARN or ERROR lines.
- `qs -p tests/qml/tst_lazer_bar_components.qml` passes without WARN or ERROR lines.
- Relevant existing backend QML tests pass without WARN or ERROR lines.
- `qs -p <repository-root>` loads `shell.qml` without QML warnings or errors.
- Every connected screen receives one background and three interactive zones.
- Normal application windows start below the 46px exclusive zone.
- Pointer input outside the three content zones is not consumed by a transparent interactive layer.
- Narrow layouts never overlap the left and status zones.
- Keyboard focus order and Escape behavior work without a pointer.
- Reduced-motion mode removes scale and positional movement.

## Risks

### Layer ordering across four windows

Independent layer-shell windows can expose compositor-specific ordering behavior. The implementation must use consistent layer and namespace choices and verify the background remains below interactive zones.

### Duplicate exclusive zones

Only the background may reserve workspace. If an interactive zone also reserves space, the compositor can create an incorrect top inset.

### Transparent pointer interception

Interactive windows must be content-width. A full-width transparent zone would consume input intended for applications below it.

### SVG tint compatibility

QML `Image` does not consistently inherit SVG `currentColor`. Runtime tinting must use a tested QtQuick-compatible mask or effect path.

### Uptime data source availability

`/proc/uptime` is Linux-specific. Failure is represented explicitly rather than hidden by incorrect fallback data.

## Success Criteria

- The top bar reads immediately as an osu!lazer-inspired dark menu bar without copying proprietary assets.
- Mode selection has a continuous green icon and sliding white indicator response.
- Every button has coherent hover, press, active, disabled, keyboard-focus, and reduced-motion behavior.
- Profile, live clock, and real system uptime remain readable at a glance.
- The bar remains usable on narrow screens by reducing low-priority utility entries.
- Reusable menu and modal primitives are ready for future business content without expanding this release into placeholder application pages.
