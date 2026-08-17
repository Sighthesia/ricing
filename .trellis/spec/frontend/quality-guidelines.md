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
- `SettingsOverlayBridge.showTooltip(text, sourceItem, priority, activitySource)` accepts an optional explicit activity source.
- Settings-only tokens: `settingsAccent`, `settingsControlSurface`, `settingsPanel`, `settingsRail`, and `settingsNavInactive`.
- Control presentation contract: `standard | inline | split` via `rowPresentation`.

### 3. Contracts

- An active tooltip owner is not replaced by an equal-priority source; a strictly higher-priority request may replace it immediately.
- Repeated requests from the active source update text and priority in place without restarting the fade or moving the source.
- Fallback selects the highest valid priority using original registration order for ties.
- Row descriptions pass the Row as `activitySource`; Slider value tooltips retain `nubItem` as their geometry source and pass the Slider root as `activitySource`.
- A request with an explicit `activitySource.tooltipActive === false` cannot take ownership or reappear through fallback. Calls without the fourth argument retain their existing programmatic-request semantics.
- Toggle exposes `inline` and renders a `44x20` capsule without a moving or hollow Nub.
- Slider exposes `split`, renders a `26px` trough whose active thumb is exactly as tall as the trough and uses a brighter shade of the fill color, and exposes that thumb as `nubItem`.
- Settings tokens are exact: `#765BFF`, `#25222E`, `#18161D`, `#131217`, and `#8A8795`; `settingsRow` is transparent and global `osuPink` is unchanged.
- Search places the icon on the right and uses the exact placeholder `输入以搜索`; a visible clear action replaces the icon while a query is present.

### 4. Validation & Error Matrix

- Equal-priority competing source while active owner is valid -> retain active owner.
- Higher-priority source -> replace active owner and reposition immediately.
- Active source hidden, destroyed, or fully offscreen -> dismiss and choose deterministic fallback.
- Explicit activity source reports `tooltipActive === false` -> skip the request during both initial ownership and fallback; do not revive its stale geometry.
- Toggle or Slider imports shared Nub visuals -> reject; controls render their specified capsule or full-height thumb directly.
- Inactive navigation item -> no selection indicator and use `#8A8795`.
- Content header close/collapse controls -> reject; close remains on Escape or Sidebar Back.

### 5. Good/Base/Bad Cases

- Good: a row description remains visible while an adjacent equal-priority row briefly becomes hovered, then becomes deterministic fallback after dismiss.
- Base: a Slider value tooltip follows the full-height thumb while its row owns the split layout.
- Bad: every equal-priority hover request immediately replaces the current owner.
- Bad: a visual token change modifies global `osuPink` or recreates a row card.

### 6. Tests Required

- Bridge/Content tests assert equal-priority stability, higher-priority takeover, in-place text updates, and registration-order fallback.
- Panel tests assert a stale Row request is skipped after a higher-priority Slider dismisses, and an inactive Slider falls back to a still-active Row.
- Control tests assert Toggle `44x20`, Slider `26px` trough, full-height brighter thumb, `rowPresentation`, and `nubItem` identity.
- Theme tests assert settings-only tokens and transparent row surface.
- Panel tests assert right-side search icon, exact placeholder, removed header actions, inactive navigation indicator absence, and preserved Escape/Back close.

### 7. Wrong vs Correct

#### Wrong

```qml
    if (request.priority >= activePriority)
        setActiveTooltip(request)
    ```

## Scenario: Visible Settings Reset And Slider Default Layers

### 1. Scope / Trigger

- Apply when a settings row exposes a restore-default action or a Slider displays both an active value and a configured default.
- Apply after a visual implementation appears correct in isolated properties but disappears in the running panel.

### 2. Signatures

- `LazerSettingsRow`: `defaultValue`, `currentValue`, `resetCallback`, `revertButtonItem`, and `contentItem`.
- `LazerSettingsSlider`: `defaultMarkerItem`, `nubItem`, `thumbColor`, and `defaultMarkerVisible`.

### 3. Contracts

- The reset affordance is a sibling above the card/content layers, remains inside the row bounds, and reserves its width from the control budget.
- Reset visibility is `hasDefault && !isDefault`; activation delegates to `resetCallback` and does not mutate settings directly.
- Slider layer order is trough, fill, default marker, active thumb; the active thumb is exactly as tall as the trough and uses a brighter shade of the fill color.
- The default marker is non-interactive, uses the normalized `sliderFraction`, and stays visible above the active thumb. It is compact when modified and becomes a shorter-than-thumb vertical line when current and default values are equal.

### 4. Validation & Error Matrix

- Reset button behind content or card -> reject; assert explicit z-order and visible bounds.
- Slider thumb is shorter than the trough or uses the fill color unchanged -> reject; assert a full-height thumb with a brighter shade of the fill token.
- Marker exists but is below fill/thumb or has no visible state transition -> reject; assert z-order and `defaultMarkerVisible` transitions.
- Page omits one of the reset properties -> reject; verify representative page rows carry the complete reset contract.

### 5. Good/Base/Bad Cases

- Good: a modified page Slider shows the right reset icon, brighter full-height thumb, and default marker simultaneously.
- Base: current value equals default, so the reset icon is hidden while the marker remains visible as a shorter vertical line above the thumb.
- Bad: properties and colors are correct in a component test, but sibling stacking covers the reset button or marker in the panel.

### 6. Tests Required

- Row tests assert reset visibility, bounds, z-order above `contentItem`, callback activation, and hide-after-equality.
- Slider tests assert full-height brighter thumb, marker dimensions/color, layer order, normalized position, and modified/default transitions.
- Page tests assert representative rows receive `defaultValue`, `currentValue`, and `resetCallback`.

### 7. Wrong vs Correct

#### Wrong

```qml
Rectangle { id: cardSurface }
Item { id: revertButton; visible: root.revertVisible }
Item { id: contentHost }
```

#### Correct

```qml
Item { id: contentHost; z: 1 }
Item { id: revertButton; z: 3; visible: root.revertVisible }
```

## Scenario: Single Settings Heading And Embedded Choice Fields

### 1. Scope / Trigger

- Apply when the settings Content surface owns category navigation and search chrome.
- Apply when a Choice control displays its setting label inside the control surface.

### 2. Signatures

- Content chrome: top search field, one category heading, then the clipped page viewport.
- Choice presentation: `rowPresentation: "choice"`, `fieldLabel: string`, and `displayLabel: string`.
- Navigation item: `selectionIndicatorItem` is the only selected-state surface.

### 3. Contracts

- Content renders the category heading exactly once below the search field; category pages do not repeat it.
- Search uses `#201E27`, radius `6`, no default border, right-side search icon, and placeholder `输入以搜索`.
- A Choice row injects the existing row label through `fieldLabel`; the outer Row label is hidden to prevent duplicate text.
- Choice controls are `52px` high with `#25222E` surface, `#8A8795` 11px field label, white 14px demi-bold value, and a right-aligned downward chevron.
- The Choice root and its visible `headerItem` share identical bounds. The Row gives this surface the card-left geometry while the embedded field column keeps the standard `12px` text inset.
- `LazerSettingsContent.showDropdownFor()` maps that same `headerItem`; no Row or bridge layer may introduce another popup anchor or a competing hover/focus surface.
- Selected navigation has no outer capsule: it uses a left `4x24` radius-2 accent indicator and white icon/text. Inactive navigation has no indicator and uses `#8A8795`.
- Sidebar collapse/Back and Content Escape close behavior remain available; Content does not add a second close or collapse owner.

### 4. Validation & Error Matrix

- Category page declares its own title -> reject; Content is the single heading owner.
- Choice row renders both outer and embedded labels -> reject; use the `rowPresentation` contract.
- Choice root, visible surface, and popup use different horizontal geometry sources -> reject; map `headerItem` as the single source of truth.
- Search surface has a default white/focus border -> reject; focus must not restore the removed white outline.
- Inactive navigation has a visible indicator -> reject; use zero height and zero opacity.
- Sidebar Back/collapse is removed while cleaning Content chrome -> reject; these are separate ownership boundaries.

### 5. Good/Base/Bad Cases

- Good: Content displays search, one `18px` category title, and a page whose first visible row is a setting.
- Base: an empty query shows the search icon; a non-empty query replaces it with the clear action.
- Good: a Choice row shows one label/value pair inside its `52px` surface and preserves dropdown focus/menu behavior.
- Bad: each category page adds a second large title above its first row.
- Bad: selected navigation keeps a filled purple pill behind the entire item.

### 6. Tests Required

- Panel tests assert search ordering, exact placeholder/surface/radius, right-side icon, and one Content-owned heading.
- Control tests assert Choice height, surface token, embedded label/value contract, card/surface/text coordinate offsets, and preserved menu APIs.
- Panel tests assert selected indicator geometry/color, inactive indicator absence, and inactive label color.
- Existing geometry, persistence, dropdown, tooltip, Escape, and Sidebar Back/collapse tests remain green.

### 7. Wrong vs Correct

#### Wrong

```qml
Column {
    Text { text: root.title }
    LazerSettingsChoice { }
}
```

#### Correct

```qml
LazerSettingsRow {
    labelText: "配色方案"
    LazerSettingsChoice {
        rowPresentation: "choice"
        fieldLabel: parent.labelText
    }
}
```

#### Correct

```qml
if (!activeSource || request.priority > activePriority)
    setActiveTooltip(request)
```

## Scenario: Inline Settings Control Width Ownership

### 1. Scope / Trigger

- Apply when a settings Row places a compact control, such as a Toggle, inline with its label.

### 2. Signatures

- Row layout: `controlHost.width` is the compact control's measured/requested width for `rowPresentation: "inline"`.
- Toggle dimensions: `implicitWidth: 44`, `implicitHeight: 20`.

### 3. Contracts

- The inline host is right-aligned and must not claim the entire row width.
- The label width is the remaining content width after the compact control and gap are reserved.
- The injected control remains mounted and owns its own fixed visual dimensions.
- The inline host spans the Row content height, while the compact control itself is vertically centered within that host. Test the mapped capsule center against the mapped content center.

### 4. Validation & Error Matrix

- Inline host width equals full parent width -> reject; it collapses the label's available width.
- Toggle is only locally centered while its mapped capsule center differs from the Row content center -> reject; local coordinates do not prove visible alignment.
- Compact control requested width is invalid -> clamp host width to a non-negative finite value.
- Choice or Slider presentation -> use their existing full or split width contracts instead.

### 5. Good/Base/Bad Cases

- Good: a Toggle row shows its label and a `44x20` capsule at the right edge.
- Bad: a full-width `controlHost` overlaps or consumes the label region while the Toggle remains only `44px` wide.

### 6. Tests Required

- Assert inline label visibility, positive label width, Toggle `44x20` size, mapped center alignment, and right-edge containment.
- Keep Choice, Slider, search, and disabled-row tests unchanged and passing.

### 7. Wrong vs Correct

#### Wrong

```qml
width: root.inlinePresentation ? parent.width : parent.width * 0.5
```

#### Correct

```qml
width: root.inlinePresentation
        ? Math.min(parent.width, Math.max(0, root.safeRequestedWidth))
        : parent.width * 0.5
```

## Scenario: Shared Settings Cards And Slider Fidelity

### 1. Scope / Trigger

- Apply when restoring the visual container for settings rows or tuning the
  thick Slider presentation without changing settings behavior.

### 2. Signatures

- Row owns one `cardItem` surface for every presentation.
- Slider exposes `trackItem`, `trackFillItem`, and `nubItem` for visual and
  tooltip assertions.
- Split controls receive a capped right-side width of
  `Math.min(240, contentWidth * 0.55)`.

### 3. Contracts

- The shared card fills the Row width, uses `radius: 6`, `#221F2B`, and
  transitions to `#2A2636` while the row is hovered.
- Row hover is owned by a `HoverHandler` targeted at that shared card surface.
  Its highlighted state also includes an injected control's `hovered` and
  `activeFocus` state plus the higher-z restore button's hover state; each
  source refreshes the shared tooltip state when it changes.
- Card content keeps approximately `12px` horizontal padding; Toggle remains
  an inline `44x20` control and is not wrapped in a second card.
- Slider is a `26px` high, radius-4 trough using `#2E2A3A`, an accent
  `#765BFF` fill. Its active thumb is exactly as tall as the trough and uses a
  brighter shade of the fill (`#9A86FF`); there is no separate inner light bar.
- The default marker always uses the normalized fraction, `3px` width, and
  `#D5CCFF`, and renders above the active thumb. Away from the default it is
  `6px` high with a `3px` radius; at the default it becomes a taller but
  still shorter-than-thumb vertical line (`trackHeight - 6`).
- A modified setting exposes a right-side `28x28`, radius-6 restore button in
  the Row's fixed reset slot; the slot remains reserved when hidden.
- Split Slider rows use a card-height track and bottom-inset value text;
  Choice controls begin at the same content edge as other full-width rows.
- Split Slider controls remain wide enough for the fixed settings content when
  possible, but never exceed `240px`.
- Track taps, continuous horizontal drags, step snapping, keyboard input,
  default reset, and `nubItem` tooltip identity remain unchanged.

### 4. Validation & Error Matrix

- Transparent Row surface -> reject; the shared card must own the visible row
  background.
- Slider width below `200px` when the available content can provide it ->
  reject; use the 55% split budget and 240px cap.
- Slider thumb is hollow, outside the trough, shorter than the trough, or uses
  the fill color unchanged -> reject; use the full-height brighter thumb.
- Reset control is placed on the left, lacks a visible rounded surface, or
  changes the setting content width when it appears -> reject; use the fixed
  right-side slot.
- Toggle receives a second visual card -> reject; Row owns the card and the
  Toggle owns only its capsule.
- Hovering a control, card edge, or visible restore button without highlighting
  the shared card -> reject; those hit regions must use one row state.

### 5. Good/Base/Bad Cases

- Good: a hovered Row changes only its shared card surface through a color
  transition while its label and control remain mounted.
- Base: a fixed 400px settings content column gives a Slider roughly 200px of
  right-side track space.
- Bad: each control creates a nested card, or the Slider shrinks to the old
  narrow generic control width.

### 6. Tests Required

- Control tests assert card width, radius, base color, hover token, content
  padding, row-edge/control/reset hover coverage, Slider width range,
  trough/fill colors, and thumb geometry.
- Existing Slider interaction tests assert track taps, drag updates, step
  normalization, keyboard behavior, default reset, and tooltip anchoring.
- Existing Toggle tests assert `44x20`, checked/off colors, accessibility, and
  keyboard/focus behavior.
- Default marker tests assert normalized placement, marker-above-thumb layer
  order, both marker heights, and right-side reset visibility/activation.

### 7. Wrong vs Correct

#### Wrong

```qml
// The Row has no visible shared surface and the Slider uses a narrow generic
// control width.
Rectangle { color: "transparent" }
width: parent.width * 0.5
```

#### Correct

```qml
Rectangle {
    anchors.fill: parent
    radius: 6
    color: rowHighlighted ? LazerTheme.settingsCardHover
                          : LazerTheme.settingsCard
}

HoverHandler { target: cardSurface }

width: Math.min(240, parent.width * 0.55)
```

## Scenario: Runtime Settings Defaults And Category Reset

### 1. Scope / Trigger

- Apply when a settings host wires restore-default state from live services instead of page-local fixtures.
- Apply when category pages forward canonical defaults to Rows and Sliders in display units.

### 2. Signatures

- `SettingsService`: `appearanceDefaults`, `barDefaults`, `notificationDefaults`, and `resetCategorySetting(category, key, value)`.
- `LazerSettingsPanel` inputs: `appearanceDefaults`, `barDefaults`, `notificationDefaults`, `settingsReset`.
- Slider input: `defaultValue` in display units (notification timeout uses seconds while the persisted value is milliseconds).

### 3. Contracts

- Default maps mirror the persisted `JsonAdapter` initial values field-for-field and are never mutated by controls.
- `resetCategorySetting` validates the category, key, and canonical value before writing the default into the persisted object and scheduling the existing `save()` debounce; it ignores unknown categories, absent keys, or non-canonical values.
- The host injects all three maps and the category-aware reset operation; panel page wrappers forward their category name.
- Every numeric Slider receives the same `defaultOf(key)` display-unit value as its enclosing Row, including the ms->seconds conversion for the notification timeout.
- Clicking a Row restore button writes the canonical default and must not activate the adjacent Slider or move its thumb.

### 4. Validation & Error Matrix

- Non-canonical value through the reset path -> reject without writing.
- Timeout reset writes milliseconds (5000) while the Slider marker uses seconds (5) -> the persisted canonical default is unchanged.
- Restore button overlapping the Slider geometrically or by input ownership -> reject; keep the split control right-aligned at the reserved reset slot.
- Page omits `defaultValue` on a numeric Slider -> reject; the marker stays hidden until a real configured default is supplied.

### 5. Good/Base/Bad Cases

- Good: resetting a modified appearance Slider writes `0.9` panelOpacity, saves once, and hides the reset icon and marker.
- Base: an empty defaults map leaves rows without `hasDefault` and Slider markers hidden.
- Bad: a restore click also scrubs the adjacent Slider to its maximum.

### 6. Tests Required

- Service/host tests assert default maps match persisted schemas and category-aware reset routing.
- Page tests assert Slider `defaultValue` propagation in display units and canonical reset values.
- Control tests assert the restore button click does not emit Slider `valueModified`.

### 7. Wrong vs Correct

#### Wrong

```qml
// The host writes an arbitrary value straight into the persisted object,
// bypassing canonical validation, so a reset can inject non-defaults.
panel.settingsReset: function(category, key, value) { SettingsService[category][key] = value }
```

#### Correct

```qml
panel.settingsReset: Services.SettingsService.resetCategorySetting
```
