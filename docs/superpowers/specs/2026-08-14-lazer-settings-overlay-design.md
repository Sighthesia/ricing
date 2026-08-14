# Lazer Settings Overlay Design

## Goal

Add a large, functional settings panel to the osu!lazer-inspired top bar. The panel must preserve the top bar as the interaction anchor, provide real persisted settings, and reproduce the requested fast slide, dimming, toggle, and cross-switch behavior without animating expensive Wayland surface geometry.

## Scope

In scope:

- A centered large settings panel on every screen
- A desktop-only black scrim below the top bar
- A persistent settings button with white click flash and mutually exclusive pink active state
- A unified top-bar overlay state shared by settings and music
- Appearance, top bar, and notifications categories
- Immediate settings updates through `SettingsService` and its existing 500ms debounced persistence
- Real-time Lazer top-bar response to height, position, floating margin, and corner radius
- Pointer, keyboard, reduced-motion, multi-screen, and narrow-screen behavior
- QML component tests, service integration tests, and live Quickshell startup verification

Out of scope:

- Fonts, media-widget, control-step, per-widget, network, Bluetooth, and volume settings
- Settings search
- Import/export, reset-all, profiles, cloud synchronization, or undo history
- File-picker integration for the wallpaper path; the first release uses an editable path field
- Multiple simultaneous top-bar overlays
- Placeholder categories or controls that write values without a live consumer

## Selected Direction

Use one fixed-size modal `PanelWindow` per screen below the top bar. Its outer Wayland geometry remains constant while a black scrim and centered inner panel animate inside it.

Each screen composition owns one `activeOverlay` string:

- `""`: no overlay
- `"settings"`: settings panel open
- `"music"`: music card open

All top-bar overlay buttons derive their pink active state from this property. Activating the selected button clears it and closes the current surface. Activating another button changes it directly, so the pink highlight transfers without an intermediate empty state.

## Alternatives Considered

### Separate scrim and panel windows

This provides independent z-order control, but coordinating two Wayland surfaces introduces avoidable layer, focus, close-timing, and cross-screen risks.

### Extend the existing generic modal primitive

The generic modal uses a compact floating-card entrance. Specializing it for a top-origin large settings center would mix unrelated motion and focus contracts.

### Animate the settings window size

This most closely resembles a panel growing from the top edge, but changing a layer-shell window size every frame can cause compositor reconfigure jank. The selected architecture keeps the window fixed and animates only scene-graph items.

## Window Architecture

`TopBar.qml` continues to create one composition per screen. The composition adds a settings overlay window with these properties:

- Anchored below the current Lazer bar edge
- Covers the remaining screen workspace
- `ExclusionMode.Ignore`
- Fixed outer dimensions for the entire open and close lifecycle
- Top layer consistent with the existing top-bar surfaces
- Keyboard focus requested only while settings is active
- Full-window input region while settings is open or closing
- Empty input region after the close transition completes

The top bar remains visually undimmed and interactive. The settings overlay starts at the desktop-facing edge of the bar rather than covering the bar itself.

The overlay window contains two persistent children:

- A full-window scrim that intentionally consumes pointer input and closes settings when clicked
- A centered panel that accepts settings interaction and prevents its clicks from reaching the scrim

The full-window pointer catcher is intentional only while the settings modal is open or closing. The music card keeps its existing content-only input mask when active.

## Unified Overlay State

The existing independent `musicOverlayOpen` state is replaced by `activeOverlay`.

The left-zone settings button and utility-zone music button follow the same activation contract:

1. The button triggers its white flash immediately.
2. If its target equals `activeOverlay`, it requests `""`.
3. Otherwise it requests its target overlay.

State transitions are:

- Closed to settings: close any tooltip, activate settings, start scrim and panel entrance.
- Closed to music: activate music and open the existing music card.
- Music to settings: close music immediately, transfer the pink state to settings, and open settings without an empty active-button frame.
- Settings to music: begin settings departure and activate music. The settings scrim releases input only after its close transition; the music card may render during that departure but cannot receive accidental click-through.
- Active target to closed: clear pink state and run the relevant exit transition.

Only one overlay target is logically active at a time. Tooltip requests are suppressed while their button is active or another modal overlay blocks the desktop.

## Panel Geometry And Responsive Layout

The settings panel is centered in the desktop area below the top bar.

Desktop target geometry:

- Width: clamp between 760px and 1040px, targeting about 80% of the available width
- Height: clamp between 520px and 760px, targeting about 78% of the available height
- Outer radius: 16px
- Scrim opacity: 0.6 black
- Panel background: deep translucent `#18171C`-family surface with a subtle light border and restrained glass highlight

The panel uses a two-column layout:

- Left navigation: 216px at regular widths
- Right content area: fills remaining width and scrolls vertically

At widths below 760px, the panel uses the available width with a 16px edge margin and reduces the navigation rail to 168px. The panel never exceeds the available desktop height. Category content remains scrollable rather than shrinking controls below usable target sizes.

## Visual Structure

The panel has one persistent outer surface and three internal regions:

- Header: settings icon, `设置` title, current category subtitle, and close button
- Navigation rail: `外观`, `顶部栏`, and `通知`
- Content viewport: category title, short description, grouped setting rows, and section separators

Navigation entries use a rounded row. The selected category uses the same `#EB1C60` active accent as the top bar, while inactive rows use translucent hover feedback. Setting groups use nested translucent rounded surfaces rather than flat Material cards.

Reusable controls are limited to what this release needs:

- `LazerSettingsToggle`
- `LazerSettingsSlider`
- `LazerSettingsChoice`
- `LazerSettingsTextField`
- `LazerSettingsRow`

Controls expose value-change signals and do not import `SettingsService` themselves. Category pages own service bindings, which keeps visual controls independently testable.

## Entrance And Exit Motion

The outer window never resizes during animation.

Normal-motion entrance:

- Panel Y: `-panel.height` to `0` relative to its centered resting position
- Panel opacity: `0` to `1`
- Scrim opacity: `0` to `0.6`
- Duration: 320ms
- Easing: `Easing.OutQuint`

The panel begins behind the top-bar boundary and moves downward quickly before settling smoothly. It remains one persistent visual object throughout the transition.

Normal-motion exit:

- Panel Y: `0` to `-panel.height`
- Panel opacity: `1` to `0`
- Scrim opacity: `0.6` to `0`
- Duration: 240ms
- Panel easing: `Easing.InCubic`

The exit accelerates toward the top edge. Pointer activation inside settings stops when close begins, while the scrim continues blocking the desktop until the transition finishes.

Reduced-motion behavior:

- Remove panel translation
- Retain short opacity transitions for panel and scrim
- Preserve all state, focus, and input-blocking behavior

All visible color, opacity, border, indicator, and geometry changes receive coordinated transitions.

## Category Cross-Switching

Changing category does not close or move the outer panel.

Two persistent content layers implement an interruptible cross-fade:

- Outgoing content moves 8px opposite the navigation direction and fades out.
- Incoming content starts 8px along the navigation direction and fades in.
- Duration: 160ms
- Easing: the existing `outSoft` curve

The selected navigation highlight moves directly to the new row. Rapid category changes retarget from current values rather than replaying a fixed sequence from the initial category.

Each category remembers its scroll position while the settings panel remains mounted. Reopening settings starts on the most recently selected category for that screen.

## Functional Settings

All controls update `SettingsService` immediately. The service's existing 500ms debounce writes the new values to `settings.json`.

### Appearance

- Wallpaper path: editable text field, applied through `WallpaperService.setWallpaper()` when committed
- Color scheme: `auto`, `dark`, or `light`
- Panel opacity: slider
- Background blur: toggle
- Blur surface opacity: slider, enabled only when blur is on
- Glass highlight intensity: slider
- Theme glow intensity: slider
- Theme adaptation: toggle
- Ripple pulse: toggle

### Top Bar

- Height: slider with a safe Lazer range of 40px to 64px
- Position: top or bottom choice
- Floating: toggle
- Floating margin: slider, enabled only while floating
- Corner radius: slider

These values must have real Lazer consumers. `BarBackground`, zone windows, overlay attachment edge, bar exclusive zone, and bar corner geometry all derive from `SettingsService.bar`. The panel remains attached to the desktop-facing bar edge for both top and bottom placement.

Because the bar height and overlay dimensions are top-level window properties, settings changes update them directly when the user commits a control value. They are not driven by per-frame visual animation.

### Notifications

- Do not disturb: toggle
- Maximum visible notifications: discrete slider from 1 to 8
- Notification timeout: discrete slider from 2 to 15 seconds, stored in milliseconds
- Notification position: top-left, top-right, bottom-left, or bottom-right

The implementation must confirm that each exposed notification value has a live consumer. Missing consumers are added as part of this feature rather than leaving inert settings.

## Input And Keyboard Behavior

- Clicking the settings button toggles the panel.
- Clicking the scrim closes the panel.
- Clicking inside the panel never closes it.
- `Escape` closes settings and returns focus to the settings button.
- `Tab` and `Shift+Tab` remain within the settings panel while it is active.
- Arrow keys move through the navigation rail and choice controls.
- `Enter` and `Space` activate focused buttons, toggles, and choices.
- Sliders support arrow-key adjustment.
- Disabled dependent controls remain legible, cannot activate, and are skipped where Qt focus navigation permits.
- Focus-visible treatment is independent from hover and meets the existing dark-theme contrast contract.

The panel uses an inner focused `Item`; keyboard handlers are not attached directly to `PanelWindow`.

## Data Integrity And Error Handling

- Numeric inputs clamp to their documented ranges before assignment.
- Choice controls write only known enum values.
- The wallpaper field preserves its text if the path is invalid; `WallpaperService` remains the single write path and existing service warnings report failure.
- External `settings.json` changes continue to flow into controls through `SettingsService` bindings.
- Controls do not maintain duplicate long-lived copies of persisted values.
- Closing the panel never discards edits because settings are immediate.

## Component Boundaries

Expected additions and changes:

- `TopBar.qml`: unified overlay state, settings window ownership, music/settings mutual exclusion
- `LeftZone.qml`: expose the settings button and overlay request signal
- `OsuTopBarButton.qml`: become a reusable target-overlay button rather than a music-specific component
- `LazerSettingsOverlay.qml`: lifecycle, scrim, panel motion, focus containment, and category ownership
- `LazerSettingsPanel.qml`: persistent header, navigation, and content viewport
- `LazerSettingsAppearance.qml`: appearance bindings
- `LazerSettingsBar.qml`: bar bindings
- `LazerSettingsNotifications.qml`: notification bindings
- Reusable setting-control QML files for toggle, slider, choice, text field, and row presentation
- `LazerTheme.qml` and `MotionTokens.qml`: panel colors, dimensions, and explicit settings motion values
- `BarBackground.qml` and top-bar zone windows: real bar setting consumers
- Notification presentation/service files: live timeout and position consumers if currently absent

Major QML declarations receive short English intent comments according to project convention.

## Testing Strategy

Pure logic tests cover:

- Overlay target toggling and mutual exclusion
- Panel width and height clamping
- Numeric settings clamping and notification timeout conversion
- Category navigation direction

QML component tests cover:

- Settings-button active, hover, press, flash, keyboard, and reduced-motion states
- Open and close lifecycle, exact target values, and fixed outer geometry
- Scrim input blocking during open and close
- Scrim click and Escape close
- Focus restoration and focus containment
- Category highlight and cross-fade continuity
- Immediate service writes from each control type
- Dependent-control disabling
- Top/bottom bar attachment and floating margins
- Music/settings mutual exclusion
- Multi-screen state isolation

Existing Lazer and backend QML tests remain green without WARN or ERROR output.

## Verification

Implementation is complete only when:

- All new component and integration tests pass without WARN or ERROR lines.
- Existing Lazer bar and backend tests pass.
- `qs -p <repository-root>` loads without QML warnings or errors.
- Opening settings never changes the settings overlay window dimensions per frame.
- The top bar stays undimmed and interactive while the desktop is blocked by the scrim.
- Pointer input cannot reach desktop applications while settings is open or closing.
- Settings and music never remain active simultaneously.
- The panel opens and closes correctly on every connected screen.
- Top-bar height, position, floating margin, and radius visibly update from settings.
- Appearance and notification values update their live consumers and survive shell restart.
- Narrow screens preserve usable navigation and scrollable content without clipping controls.
- Reduced motion removes positional transitions while preserving opacity and state feedback.

## Risks

### Wayland layer ordering

The settings window and top-bar zone windows are separate surfaces. Their layer and creation order must ensure the settings scrim remains below the visible top bar while still covering desktop applications.

### Focus ownership across screens

Every screen has a settings instance, but only the instance opened from its local button may request keyboard focus. Closing or switching overlays must not leave focus on another screen's hidden instance.

### Input release timing

Releasing the fullscreen mask before the scrim finishes fading can click through to desktop applications. The input region remains full until close animation completion.

### Live bar relocation

Changing top/bottom position moves several layer-shell surfaces. All bar, tooltip, music, and settings attachment anchors must derive from the same setting to avoid split ownership or stale geometry.

### Inert settings

Some values already persist but are not consumed by the Lazer frontend or notification presentation. Every control included in this scope must gain a verified live consumer.

## Success Criteria

- The settings button feels physically connected to one persistent large panel.
- Pink active highlighting transfers directly between mutually exclusive top-bar surfaces.
- The panel enters quickly and settles with the characteristic osu!lazer high-order deceleration.
- The desktop is visibly dimmed and safely blocked while the top bar remains available.
- Category changes feel like internal page movement, never like closing and reopening the panel.
- Every visible setting is functional, immediately applied, and persisted.
- Motion remains smooth because Wayland window geometry is fixed during transitions.
