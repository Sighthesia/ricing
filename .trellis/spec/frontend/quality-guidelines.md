# Frontend Quality Guidelines

## Scenario: Testable QML Tokens And Per-Screen Notification Hosts

### 1. Scope / Trigger

- Apply when a QML singleton exposes visual tokens used by QtTest components.
- Apply when a transient surface is positioned per screen from a service setting.
- The goal is to preserve isolated component tests and prevent fullscreen pointer interception.

### 2. Signatures

- Visual token singleton: static/read-only QML values with no service imports.
- Notification placement service:
  - `notificationPosition: string`
  - `notificationTop: bool`
  - `notificationBottom: bool`
  - `notificationLeft: bool`
  - `notificationRight: bool`
  - `dismissPopup(notifId)`
- Notification host: `Variants { model: Quickshell.screens }` containing one `PanelWindow` per screen.

### 3. Contracts

- `notificationPosition` accepts `top-left`, `top-right`, `bottom-left`, or `bottom-right`; invalid values normalize to `top-right`.
- A notification popup model entry contains `notifId`, `appName`, `summary`, `body`, `icon`, and `timestamp`.
- `dismissPopup(notifId)` removes only the matching transient popup and does not remove notification history.
- A per-screen host uses `implicitWidth`/`implicitHeight`, `ExclusionMode.Ignore`, and a `Region` mask limited to the visible stack.
- Dynamic settings are consumed by the visible component or service owner. Shared token singletons stay independent of full service graphs.

### 4. Validation & Error Matrix

- Invalid notification position -> normalize to `top-right`.
- Missing optional popup strings -> render empty text or the stable fallback app label.
- Missing/invalid visual numeric setting -> clamp or use the existing default before assigning to geometry/color properties.
- Fullscreen notification mask -> reject; it can starve pointer events outside cards.
- Visual token singleton imports `SettingsService` -> reject; it makes otherwise pure QtTest components load Quickshell plugins.

### 5. Good/Base/Bad Cases

- Good: a bottom-left setting anchors a narrow per-screen window at bottom-left and stacks cards upward.
- Base: an empty popup model leaves a one-pixel transparent host with no interactive mask.
- Bad: a fullscreen transparent `PanelWindow` owns the notification stack mask and intercepts unrelated desktop input.
- Bad: `LazerTheme.qml` imports services so `tst_lazer_settings_controls.qml` cannot run with `qmltestrunner`.

### 6. Tests Required

- Pure QtTest verifies notification top/bottom direction, popup geometry, and dismiss signal.
- Pure QtTest verifies settings controls and theme tokens load without Quickshell plugins.
- Overlay lifecycle tests run sequentially; repeat them to expose focus/event timing races.
- `qs -p .` must reach `Configuration Loaded` with no QML WARN/ERROR. A D-Bus ownership warning is environmental only when another running shell instance is confirmed as the owner.
- Run `git diff --check` after QML changes.

### 7. Wrong vs Correct

#### Wrong

```qml
// Pulls the complete service graph into every component importing this token singleton.
readonly property color panel: SettingsService.appearance.colorScheme === "light"
        ? "white" : "black"
```


```qml
PanelWindow {
    implicitWidth: screen.width
    implicitHeight: screen.height
    mask: Region { item: fullscreenOverlay }
}
```

#### Correct

```qml
// Keep shared visual tokens pure; consume live settings at the visible surface.
readonly property color panel: "#F21D1C22"
```

```qml
PanelWindow {
    implicitWidth: notificationStack.implicitWidth
    implicitHeight: Math.max(1, notificationStack.implicitHeight)
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: notificationStack.implicitHeight > 0 ? notificationStack : null }
}
```

## Scenario: Coordinated Overlay Owners

### 1. Scope / Trigger

- Apply when top-bar routes use different visual surface types.
- Coordinate them through one non-visual state owner; do not force local overlays into a fullscreen loader.

### 2. Signatures

- Target: `"" | "settings" | "music" | "wiki" | "news" | "beatmap"`.
- Owners: `wave | settings | music`.
- Coordinator entry points: `request(target, opener)` and `ownerClosed(owner)`.
- Owner signals: `openRequested(owner, target)`, `closeRequested(owner)`, `routeRequested(target)`.

### 3. Contracts

- Wiki, News, and Beatmap share one fixed screen-sized wave owner.
- Settings and Music use independent fixed local owners and masks.
- Cross-owner requests close the current owner before opening the latest pending target.
- All `PanelWindow` geometry stays fixed; only inner items animate.
- The inner focused `Item` owns `Keys.*`; the compositor-facing `PanelWindow` does not.
- Escape precedence is input state, page return state, then host close.
- Focus restores only after final close, never between a serial owner switch.

### 4. Validation & Error Matrix

- Unknown target -> reject without changing state.
- Wave-to-wave request -> replace content in place.
- Cross-owner request while closing -> replace the pending target.
- Stale owner completion -> ignore.
- Final close -> clear target and restore opener focus.

### 5. Good/Base/Bad Cases

- Good: three pages replace one wave loader while Settings and Music retain local geometry.
- Base: one local owner closes itself and reports completion to the coordinator.
- Bad: Settings or Music is mounted inside the wave fullscreen host.
- Bad: any layer-shell window resizes per animation frame.

### 6. Tests Required

- Pure logic tests cover target classification, pending transitions, stale completions, and focus restore.
- Owner tests cover open/close, interruption, mask geometry, Escape, and reduced motion.
- Existing settings persistence and MPRIS suites remain green.
- Run all plugin-independent QML tests sequentially, Python backend tests, `qs -p .`, and `git diff --check`.

### 7. Wrong vs Correct

#### Wrong

`FullscreenOverlayHost` loads Settings and Music alongside Wiki pages.

#### Correct

One coordinator dispatches to a wave owner, a left Settings owner, or a local Now Playing owner.

## Scenario: Split Layers Inside A Fixed Settings Surface

### 1. Scope / Trigger

- Apply when a local overlay needs independently moving Sidebar and Content layers while retaining one fixed compositor surface.
- Apply when persistent settings pages animate `x`, opacity, or filtered height without being destroyed.

### 2. Signatures

- Owner geometry: fixed `570px` maximum width.
- Sidebar: `70px | 170px`, explicit `z` above Content.
- Content: `400px` preferred width, final `x` equals Sidebar width.
- Search row: `searchQuery`, `matchesSearch`, `searchVisible`.

### 3. Contracts

- Animate scene-graph Items only; never resize the `PanelWindow` per frame.
- Sidebar and Content are sibling owner layers with independent X positions.
- A persistent page that animates `x` uses explicit `width` and `height`; `anchors.fill` must not also own its position.
- Content may over-extend left during transitions, so Sidebar must have a higher `z` value.
- Search changes row visibility and layout participation without destroying controls or triggering settings persistence.

### 4. Validation & Error Matrix

- `anchors.fill` plus animated page `x` -> reject; anchors reset the translation.
- Content `z >= Sidebar.z` -> reject; the over-extended content can cover Sidebar input and visuals.
- Search hides a disabled-but-matching row -> reject; disabled state and search match are independent.
- Closing then reopening -> retarget current progress and cancel stale readiness/stagger callbacks.

### 5. Good/Base/Bad Cases

- Good: Sidebar slides from `-170`, Content from `-570`, both inside one fixed owner.
- Base: collapsed Sidebar uses `70px`; Content remains mounted and usable at `400px` where space permits.
- Bad: one `panelHost` translates Sidebar and Content as a single rectangle.
- Bad: filtering rebuilds the page model and loses control or scroll state.

### 6. Tests Required

- Assert `70/170/400/570` geometry and `Sidebar.z > Content.z`.
- Assert search matches label or description, preserves disabled matches, and never calls save.
- Assert open/close interruption, `200ms` readiness cancellation, item stagger, reduced motion, Escape, and final focus restore.
- Run settings owner tests sequentially at least twice to expose focus and delayed-callback races.

### 7. Wrong vs Correct

#### Wrong

```qml
Item {
    anchors.fill: parent
    Behavior on x { NumberAnimation {} }
}
```

#### Correct

```qml
Item {
    width: parent.width
    height: parent.height
    x: targetX
    Behavior on x { NumberAnimation { easing.type: Easing.OutQuint } }
}
```

## Scenario: Local Control Overlays Through A Singleton Bridge

### 1. Scope / Trigger

- Apply when controls inside clipped Flickables request dropdowns or tooltips from an unclipped Content overlay.
- Apply when one QML singleton carries those requests while multiple per-screen Content owners are alive.

### 2. Signatures

- Tooltip request: `(text, sourceItem, priority)`.
- Dropdown request: `(choiceItem)`.
- Dropdown dismiss: `(choiceItem)`; dismiss must retain source identity.
- Content ownership predicate: walk `sourceItem.parent` until the receiving Content owner or `null`.

### 3. Contracts

- The singleton transports requests; it does not choose the visual owner.
- Each Content instance handles only requests whose source is in its own visual ancestor chain.
- Tooltip/dropdown Items live above the clipped page viewport but inside the existing fixed Settings surface.
- Parent overlay visibility is owned by explicit state; it must not bind to a child's mutable `visible` property.

### 4. Validation & Error Matrix

- Request source is outside receiver tree -> ignore without closing local overlays.
- Dismiss source differs from active dropdown source -> ignore.
- `parent.visible: child.visible` while child `open()` writes `visible` -> reject as a circular ownership binding.
- Category/search/owner close -> close only overlays owned by that Content instance.

### 5. Good/Base/Bad Cases

- Good: a dropdown from screen A opens only in screen A's Settings Content.
- Base: a row tooltip is repositioned into its owning Content overlay and does not take focus.
- Bad: every per-screen Content reacts to one singleton dropdown signal.
- Bad: opening a child menu is immediately undone by its parent's binding to child visibility.

### 6. Tests Required

- Instantiate an external Choice outside the tested Content and assert its request does not open the local dropdown.
- Assert local dropdown open/select/Escape/outside-close and focus restoration.
- Assert dropdown Escape is handled before Overlay Escape.
- Repeat owner lifecycle tests to expose stale singleton requests.

### 7. Wrong vs Correct

#### Wrong

```qml
Item {
    visible: menu.visible
    SettingsDropdownMenu { id: menu }
}
```

#### Correct

```qml
Item {
    property bool dropdownOpen: false
    visible: dropdownOpen
    SettingsDropdownMenu { id: menu }
}
```

## Scenario: Measured Tooltips Following Local Sources

### 1. Scope / Trigger

- Apply when a tooltip is rendered by an unclipped Settings Content overlay for a source inside a clipped or scrolling viewport.
- Apply when tooltip text can wrap or its source can move after the request is emitted.

### 2. Signatures

- Request: `SettingsOverlayBridge.showTooltip(text, sourceItem, priority)`.
- Dismiss: `SettingsOverlayBridge.hideTooltip(sourceItem)`.
- Geometry helpers: `tooltipTextWidth(...)`, `rectsIntersect(...)`, and `tooltipPlacement(sourceRect, tooltipSize, boundsRect, gap)`.
- Slider source identity: `LazerSettingsSlider.nubItem`.

### 3. Contracts

- Text owns its natural `implicitWidth`; its constrained width then determines wrapped `implicitHeight`.
- The tooltip surface adds padding after text measurement and never asks an unmeasured `Rectangle` for content size.
- Available text width, placement bounds, source intersection, and final clamping all use the same local viewport coordinate domain.
- The active source is mapped with `sourceItem.mapToItem(contentOwner, 0, 0)` and repositioned when source geometry, viewport geometry, page scroll, or measured tooltip size changes.
- A partially visible source continues to own the tooltip; a fully non-intersecting, hidden, destroyed, or foreign-owner source closes it.
- Slider value tooltips use `nubItem` for both show and hide identity. Position updates are immediate; reduced motion affects opacity only.

### 4. Validation & Error Matrix

- Natural text width exceeds available viewport width -> wrap at the constrained text width and grow height.
- Source lacks the receiving Content in its ancestor chain -> ignore the request.
- Source intersects the viewport only partially -> keep visible and reposition.
- Source no longer intersects the viewport -> clear active tooltip state.
- Above space is insufficient -> place below; neither side fits -> choose the larger side and clamp within viewport bounds.
- Lower-priority request arrives while a higher-priority request is active -> retain the higher-priority tooltip.

### 5. Good/Base/Bad Cases

- Good: a Slider tooltip tracks the moving Nub while the page scrolls and closes only after the Nub fully leaves the viewport.
- Base: a short row description remains one line at its natural width plus padding.
- Bad: text fills a parent `Rectangle` whose own implicit size is derived from that text.
- Bad: width is measured against Content while placement is clamped against a narrower viewport.

### 6. Tests Required

- Logic tests assert natural-width clamping, wrapped width constraints, horizontal clamping, vertical flipping, and rectangle intersection.
- Composed Content tests assert short and long text geometry, source movement, visible scroll following, offscreen close, and foreign-owner isolation.
- Control tests assert Slider requests and dismisses with `nubItem` and that moving the Nub changes tooltip X.
- Overlay lifecycle tests assert priority behavior, no keyboard focus capture, and no stale tooltip after close; repeat sequentially to expose singleton state leaks.

### 7. Wrong vs Correct

#### Wrong

```qml
Rectangle {
    implicitWidth: label.implicitWidth + 20
    Text { id: label; anchors.fill: parent; wrapMode: Text.WordWrap }
}
```

#### Correct

```qml
Text {
    id: label
    width: constrainedTextWidth
    wrapMode: Text.WordWrap
}

Rectangle {
    width: label.width + horizontalPadding
    height: label.implicitHeight + verticalPadding
}
```

## Scenario: Stable Settings Tooltip Ownership And Control Tokens

### 1. Scope / Trigger

- Apply when multiple row or control hover/focus sources can request a tooltip during the same frame or while the previous source is still visible.
- Apply when restyling settings controls without changing the shell-wide theme.

### 2. Signatures

- Tooltip arbitration keeps one request entry per source and preserves first-registration order.
- Settings-only tokens: `settingsAccent`, `settingsControlSurface`, `settingsPanel`, `settingsRail`, and `settingsNavInactive`.
- Control presentation contract: `standard | inline | split` via `rowPresentation`.

### 3. Contracts

- An active tooltip owner is not replaced by an equal-priority source; a strictly higher-priority request may replace it immediately.
- Repeated requests from the active source update text and priority in place without restarting the fade or moving the source.
- Fallback selects the highest valid priority using original registration order for ties.
- Toggle exposes `inline` and renders a `44x20` capsule without a moving or hollow Nub.
- Slider exposes `split`, renders a `24px` trough with `4x20` embedded thumb, and exposes that thumb as `nubItem`.
- Settings tokens are exact: `#765BFF`, `#25222E`, `#18161D`, `#131217`, and `#8A8795`; `settingsRow` is transparent and global `osuPink` is unchanged.
- Search places the icon on the right and uses the exact placeholder `输入以搜索`; a visible clear action replaces the icon while a query is present.

### 4. Validation & Error Matrix

- Equal-priority competing source while active owner is valid -> retain active owner.
- Higher-priority source -> replace active owner and reposition immediately.
- Active source hidden, destroyed, or fully offscreen -> dismiss and choose deterministic fallback.
- Toggle or Slider imports shared Nub visuals -> reject; controls render their specified capsule or embedded thumb directly.
- Inactive navigation item -> no selection indicator and use `#8A8795`.
- Content header close/collapse controls -> reject; close remains on Escape or Sidebar Back.

### 5. Good/Base/Bad Cases

- Good: a row description remains visible while an adjacent equal-priority row briefly becomes hovered, then becomes deterministic fallback after dismiss.
- Base: a Slider value tooltip follows the embedded thumb while its row owns the split layout.
- Bad: every equal-priority hover request immediately replaces the current owner.
- Bad: a visual token change modifies global `osuPink` or recreates a row card.

### 6. Tests Required

- Bridge/Content tests assert equal-priority stability, higher-priority takeover, in-place text updates, and registration-order fallback.
- Control tests assert Toggle `44x20`, Slider `24px` trough, `4x20` thumb, `rowPresentation`, and `nubItem` identity.
- Theme tests assert settings-only tokens and transparent row surface.
- Panel tests assert right-side search icon, exact placeholder, removed header actions, inactive navigation indicator absence, and preserved Escape/Back close.

### 7. Wrong vs Correct

#### Wrong

```qml
if (request.priority >= activePriority)
    setActiveTooltip(request)
```

#### Correct

```qml
if (!activeSource || request.priority > activePriority)
    setActiveTooltip(request)
```
