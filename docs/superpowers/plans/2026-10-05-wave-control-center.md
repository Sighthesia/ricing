# Wave Control Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a retained `control-center` page to the shared Wave surface with the approved B1 layout, four core controls, calendar, notification summary, and optional cached weather.

**Architecture:** Extend the existing Wave route registry and shared `WaveSurfaceHost` so `launcher` and `control-center` remain sibling routes on one surface. Add a route-aware page shell plus focused control-center components: pure normalization/navigation logic, overview cards, local calendar, notification summary, and same-surface network/Bluetooth detail pages. The page consumes existing singleton services through injected properties; it does not duplicate service side effects or create a second window.

**Tech Stack:** Quickshell QML, QtQuick, QML singleton services, pure QML JavaScript modules, QtTest through `scripts/qmltest.sh`, existing `MotionTokens`/`LazerTheme`/settings-panel visual patterns.

## Global Constraints

- `launcher` remains the default Wave route.
- `control-center` is a sibling Wave route, not a settings-center category.
- The first layout is B1: a balanced two-column surface.
- The first version contains exactly four core controls: network, Bluetooth, volume, and media.
- Network and Bluetooth details open as Wave sub-pages on the same surface.
- Volume and media remain directly actionable from the overview.
- Battery is a read-only status in the top overview, not a control card.
- Weather is optional, cached, and must never block the first surface open.
- The settings center remains the destination for long-lived configuration.
- Major QML declarations require a brief descriptive comment immediately before the declaration.
- Use the existing sharp osu!lazer visual language, settings-panel authority, and `MotionTokens`; do not invent a second transition vocabulary.
- Run QML tests only through `scripts/qmltest.sh` or `scripts/run-tests.sh`; normal verification stays offscreen.
- After each QML change, run the relevant test file and resolve WARN/ERROR output before committing.
- Do not modify unrelated pre-existing worktree changes.

---

## File Map

### Existing files to modify

- `modules/lazerbar/WaveSurfaceLogic.js` — accept the `control-center` sibling route and preserve existing route/escape contracts.
- `modules/lazerbar/OverlayCoordinatorLogic.js` — allow `control-center` to use the existing `wave` owner.
- `modules/lazerbar/WaveSurfaceHost.qml` — expose route-aware content/page state, route-local back handling, and the existing retained Loader to the new page shell.
- `modules/lazerbar/LauncherSurface.qml` — route the shared Wave host to launcher or control-center, keep launcher focus semantics unchanged, and expose the new entry function.
- `modules/lazerbar/TopBar.qml` — wire the approved control-center trigger through the existing screen-scoped coordinator; keep launcher/music/settings ownership unchanged.
- `modules/lazerbar/qmldir` — register new reusable QML types if they are imported through the module namespace.
- `services/qmldir` — register `WeatherService` if the service is implemented as a singleton.
- `tests/qml/tst_wave_surface_logic.qml` — route acceptance and normalization coverage.
- `tests/qml/tst_overlay_coordinator_logic.qml` — control-center owner classification coverage.
- `tests/qml/tst_lazer_wave_host.qml` — shared-host route/page retention and back contract coverage.
- `tests/qml/tst_overlay_coordinator.qml` — production-shaped route handoff and default-launcher behavior.

### New files to create

- `modules/lazerbar/ControlCenterLogic.js` — pure route, layout, card normalization, weather-state, and summary-capping functions.
- `modules/lazerbar/ControlCenter.qml` — control-center overview page with injected services, B1 layout, cards, calendar, notifications, battery header, and weather header.
- `modules/lazerbar/ControlCenterNetwork.qml` — same-surface network detail page using the existing `NetworkService` contract and existing network error semantics.
- `modules/lazerbar/ControlCenterBluetooth.qml` — same-surface Bluetooth detail page using the existing `BluetoothService` contract.
- `modules/lazerbar/ControlCenterCard.qml` — sharp reusable card frame/state presentation for ready, loading, unavailable, empty, and error states.
- `modules/lazerbar/ControlCenterCalendar.qml` — local month view reusing `ClockCalendar.js` math.
- `modules/lazerbar/ControlCenterNotifications.qml` — bounded two-item notification summary and full-view action.
- `services/WeatherService.qml` — optional Open-Meteo adapter with cache-first state and no first-open blocking.
- `services/weather/WeatherLogic.js` — pure weather normalization/cache-state helpers.
- `tests/qml/tst_control_center_logic.qml` — headless pure logic coverage.
- `tests/qml/tst_weather_logic.qml` — headless weather parsing/cache-state coverage.
- `tests/qml/tst_control_center.qml` — headless QML page behavior with fake service objects.
- `tst_weather_service.qml` — root-level service harness only if singleton/XHR lifecycle behavior cannot be isolated in pure logic.

### Reuse boundaries

- Reuse `modules/bar/widgets/ClockCalendar.js` for month-grid math; do not fork date calculations.
- Reuse `BarPopupActions.qml` only for already-proven service-facing control behavior where its injected callback surface fits; do not embed the popup host or create a second popup window inside Wave.
- Reuse `NetworkService`, `BluetoothService`, `VolumeService`, `MediaService`, `BatteryService`, and `NotificationService` as owners of live state and side effects.
- Reuse `FullscreenHeader`, `LazerTheme`, `MotionTokens`, `LazerSettingsRow`, `LazerSettingsSlider`, and settings-panel interaction patterns for visuals.

## Task 1: Lock The Pure Route Contract

**Files:**
- Modify: `modules/lazerbar/WaveSurfaceLogic.js:6-29`
- Modify: `modules/lazerbar/OverlayCoordinatorLogic.js:3-19`
- Test: `tests/qml/tst_wave_surface_logic.qml`
- Test: `tests/qml/tst_overlay_coordinator_logic.qml`

**Interfaces:**
- Produces `WaveSurfaceLogic.normalizeRoute("control-center") === "control-center"`.
- Produces `OverlayCoordinatorLogic.ownerFor("control-center") === "wave"`.
- Keeps `launcher` as the default caller-selected route; no coordinator default changes.

- [ ] **Step 1: Write failing route tests**

Add assertions beside the existing launcher route checks:

```qml
function test_routesAndToggle() {
    compare(Logic.normalizeRoute("control-center"), "control-center")
    compare(Logic.toggleRoute("launcher", "control-center"), "control-center")
}
```

Add owner assertions:

```qml
function test_targetClassification() {
    compare(Logic.normalizeTarget("control-center"), "control-center")
    compare(Logic.ownerFor("control-center"), "wave")
}
```

- [ ] **Step 2: Run the focused tests and verify failure**

Run:

```bash
scripts/qmltest.sh tst_wave_surface_logic
scripts/qmltest.sh tst_overlay_coordinator_logic
```

Expected: the new route assertions fail because the route/target arrays reject `control-center`.

- [ ] **Step 3: Implement the minimal route additions**

Extend the existing arrays only:

```javascript
var routes = ["launcher", "control-center"]
```

```javascript
var targets = ["settings", "music", "launcher", "control-center"]
var waveTargets = ["launcher", "control-center"]
```

Do not change `ownerFor` behavior for settings or music.

- [ ] **Step 4: Run the focused tests and verify pass**

Run the same two commands. Expected: PASS with no WARN/ERROR output.

- [ ] **Step 5: Commit**

```bash
git add modules/lazerbar/WaveSurfaceLogic.js modules/lazerbar/OverlayCoordinatorLogic.js \
  tests/qml/tst_wave_surface_logic.qml tests/qml/tst_overlay_coordinator_logic.qml
git commit -m "feat(wave): register control center route"
```

## Task 2: Add Pure Control-Center Contracts

**Files:**
- Create: `modules/lazerbar/ControlCenterLogic.js`
- Create: `tests/qml/tst_control_center_logic.qml`

**Interfaces:**
- `normalizeCard(kind, snapshot)` returns a plain object with `title`, `summary`, `status`, `icon`, `available`, `action`, `detailRoute`, and `error`.
- `weatherState(snapshot)` returns one of `ready`, `loading`, `stale`, `unavailable`, or `empty`.
- `notificationSummary(entries, unreadCount, limit)` returns `{ unreadCount, entries }` with at most `limit` entries.
- `layoutMode(width, minimumTwoColumnWidth)` returns `wide` or `narrow`.
- `sectionOrder(layoutMode)` returns `{ stacked: ["overview", "controls", "notifications", "calendar"] }` for narrow mode and `{ left: ["controls"], right: ["calendar", "notifications"] }` for wide mode.
- `backAction(route, detailPage, enteredFromLauncher)` returns `detail`, `launcher`, or `close`.

- [ ] **Step 1: Write failing pure tests**

Create an `Item` root with a `TestCase` and import `ControlCenterLogic.js`. Cover these concrete cases:

```qml
function test_cardNormalization() {
    var ready = Logic.normalizeCard("network", {
        connected: true, summary: "Home", available: true
    })
    compare(ready.status, "ready")
    compare(ready.summary, "Home")
    compare(ready.detailRoute, "network-detail")

    var unavailable = Logic.normalizeCard("bluetooth", { available: false })
    compare(unavailable.status, "unavailable")
    verify(!unavailable.available)
}

function test_layoutAndOrdering() {
    compare(Logic.layoutMode(900, 760), "wide")
    compare(Logic.layoutMode(600, 760), "narrow")
    compare(Logic.sectionOrder("narrow").stacked.join(","),
            "overview,controls,notifications,calendar")
    compare(Logic.sectionOrder("wide").left.join(","), "controls")
    compare(Logic.sectionOrder("wide").right.join(","), "calendar,notifications")
}

function test_notificationCap() {
    var result = Logic.notificationSummary([
        { notifId: "a" }, { notifId: "b" }, { notifId: "c" }
    ], 4, 2)
    compare(result.entries.length, 2)
    compare(result.unreadCount, 4)
}

function test_weatherStates() {
    compare(Logic.weatherState({ available: true, temperature: 18, isStale: false }), "ready")
    compare(Logic.weatherState({ available: true, temperature: 18, isStale: true }), "stale")
    compare(Logic.weatherState({ loading: true }), "loading")
    compare(Logic.weatherState({ available: false }), "unavailable")
}

function test_backPrecedence() {
    compare(Logic.backAction("network-detail", true, true), "detail")
    compare(Logic.backAction("control-center", false, true), "launcher")
    compare(Logic.backAction("control-center", false, false), "close")
}
```

- [ ] **Step 2: Run to verify failure**

Run:

```bash
scripts/qmltest.sh tst_control_center_logic
```

Expected: FAIL because the new module and functions do not exist.

- [ ] **Step 3: Implement the pure module**

Keep the implementation dependency-free and defensive. Normalize every service snapshot into explicit states:

```javascript
function normalizeCard(kind, snapshot) {
    var value = snapshot || {}
    var available = value.available !== false
    var error = value.error == null ? "" : String(value.error)
    var status = error !== "" ? "error"
        : value.loading === true ? "loading"
        : !available ? "unavailable"
        : value.empty === true ? "empty" : "ready"
    return {
        title: titleFor(kind),
        summary: summaryFor(kind, value),
        status: status,
        icon: iconFor(kind),
        available: available,
        action: actionFor(kind, value),
        detailRoute: kind === "network" ? "network-detail"
            : (kind === "bluetooth" ? "bluetooth-detail" : ""),
        error: error
    }
}
```

Use a fixed notification cap and a fixed narrow ordering; do not derive layout from incoming notification count.

- [ ] **Step 4: Run the pure tests**

Run `scripts/qmltest.sh tst_control_center_logic`. Expected: PASS with no WARN/ERROR output.

- [ ] **Step 5: Commit**

```bash
git add modules/lazerbar/ControlCenterLogic.js tests/qml/tst_control_center_logic.qml
git commit -m "feat(control-center): add pure state contracts"
```

## Task 3: Add The Cached Weather Adapter

**Files:**
- Create: `services/weather/WeatherLogic.js`
- Create: `services/WeatherService.qml`
- Modify: `services/qmldir:37`
- Create: `tests/qml/tst_weather_logic.qml`
- Optional create: `tst_weather_service.qml` only if direct singleton lifecycle coverage is required after the pure tests.

**Interfaces:**
- `WeatherLogic.parseResponse(jsonText)` returns `{ ok, temperature, condition, location, updatedAt }` or `{ ok: false, error }`.
- `WeatherLogic.cacheState(cache, now)` returns `{ available, loading, isStale, temperature, condition, location, updatedAt }`.
- `Services.WeatherService` exposes `temperature`, `condition`, `location`, `updatedAt`, `isStale`, `available`, `loading`, `lastError`, `refresh()`, and `setCoordinates(latitude, longitude)`.
- `WeatherService` reads coordinates from `Services.SettingsService.appearance.autoLatitude/autoLongitude` only when they validate through `SettingsService.locationCoordsValid`.

- [ ] **Step 1: Write failing response/cache tests**

Create tests for a valid Open-Meteo current-weather payload, malformed JSON, missing coordinates, fresh cache, stale cache, and no cache:

```qml
function test_validResponse() {
    var result = Logic.parseResponse(JSON.stringify({
        current: { temperature_2m: 18.5, weather_code: 1 },
        timezone: "Asia/Shanghai"
    }))
    verify(result.ok)
    compare(result.temperature, 18.5)
    compare(result.condition, "partly-cloudy")
}

function test_invalidResponseAndCacheStates() {
    verify(!Logic.parseResponse("{").ok)
    compare(Logic.cacheState(null, 1000).available, false)
    compare(Logic.cacheState({ temperature: 18, updatedAt: 0 }, 1000).isStale, true)
}
```

- [ ] **Step 2: Run to verify failure**

Run `scripts/qmltest.sh tst_weather_logic`. Expected: FAIL because `WeatherLogic.js` is absent.

- [ ] **Step 3: Implement pure weather normalization**

Map Open-Meteo `weather_code` to stable internal labels (`clear`, `partly-cloudy`, `cloudy`, `rain`, `snow`, `storm`, `unknown`). Treat a numeric temperature as valid even when the condition code is unknown. Mark cached data stale after the chosen bounded TTL, using one explicit constant in the module so tests can pass deterministic timestamps.

- [ ] **Step 4: Implement the singleton without blocking startup**

Use the existing `LocationService`/`SettingsService` coordinate contract and `XMLHttpRequest` pattern. On construction, load the last cache if available and schedule refresh only after coordinates are valid. `refresh()` must return immediately when already loading, when coordinates are absent, or when no network request can be formed. On failure, preserve the prior cache and set `lastError`; never clear a usable cached value.

Use a small persisted JSON cache under the shell cache directory and make all writes replace the complete cache atomically through the existing file API pattern. Keep HTTP timeout bounded. Register:

```text
singleton WeatherService 1.0 WeatherService.qml
```

in `services/qmldir`.

- [ ] **Step 5: Run pure and service checks**

Run:

```bash
scripts/qmltest.sh tst_weather_logic
scripts/run-tests.sh tst_weather_service --no-python
```

If the root harness cannot safely instantiate the service under the offscreen runner, retain the pure suite and document that the service lifecycle check requires the repository’s root harness path; do not run a bare `qmltestrunner`. If no root harness is needed, omit `tst_weather_service.qml` from the task and commit.

- [ ] **Step 6: Commit**

```bash
git add services/weather/WeatherLogic.js services/WeatherService.qml services/qmldir \
  tests/qml/tst_weather_logic.qml
# Add tst_weather_service.qml here only when the optional root harness was created.
git commit -m "feat(weather): add cached nonblocking adapter"
```

## Task 4: Make The Shared Wave Host Route-Aware

**Files:**
- Modify: `modules/lazerbar/WaveSurfaceHost.qml:8-107,165-231`
- Modify: `modules/lazerbar/LauncherSurface.qml:49-103,209-231`
- Modify: `modules/lazerbar/LauncherSurfaceLogic.js:8-33`
- Test: `tests/qml/tst_lazer_wave_host.qml`
- Test: `tests/qml/tst_overlay_coordinator.qml`

**Interfaces:**
- `WaveSurfaceHost.openRoute(nextRoute, source)` accepts both sibling routes.
- `WaveSurfaceHost.routePage` (or an equivalent read-only property) exposes the active retained page.
- `WaveSurfaceHost.pageCanGoBack` is driven by the active route page’s `canGoBack`/detail state, not manually mutated by callers.
- `WaveSurfaceHost.backRequested` (or equivalent) lets the page consume a local back action before the host closes.
- `LauncherSurface.requestOpen(opener)` continues to open `launcher` by default.
- `LauncherSurface.requestControlCenter(opener)` opens the same session/coordinator on `control-center`.
- `LauncherSurface.page()` continues to return the launcher page for existing tests; add `activePage()` or an equivalent route-safe accessor for the active content.

- [ ] **Step 1: Write failing host/coordinator behavior tests**

Extend the existing host tests with these assertions:

```qml
function test_controlCenterRouteIsAcceptedAndRetained() {
    var host = testRoot.createHost()
    verify(host.openRoute("control-center"))
    tryVerify(function() { return host.contentItem !== null }, 2000)
    compare(host.route, "control-center")
    var page = host.contentItem
    host.close()
    tryCompare(host, "phase", "closed", 3000)
    verify(host.contentItem === page)
}
```

Extend the production-shaped coordinator test so `coordinator.request("control-center", opener)` emits `openRequested("wave", "control-center")` and does not create a second owner.

- [ ] **Step 2: Run the focused tests to verify failure**

Run:

```bash
scripts/qmltest.sh tst_lazer_wave_host
scripts/run-tests.sh tst_overlay_coordinator --no-python
```

Expected: the new route test fails until the host/page source is made route-aware. Existing launcher tests must remain green.

- [ ] **Step 3: Implement route-aware content selection**

Keep one `WaveSurfaceHost` and one retained Loader. Replace the single fixed `contentComponent` binding with a route selection that preserves the launcher component and selects the control-center component for `control-center`. The Loader must remain inactive before the first open and retained after the first construction.

Use a route component contract instead of page-specific `if` branches in the host:

```text
title
description
sidebarEntries
activeSidebarId
canGoBack
handleBack()
focusDefault()
```

The host delegates route-local back handling to the active page. `handleEscape()` must still obey `input -> back -> close`, while launcher query-clearing remains owned by `LauncherPage.handleEscape()`.

- [ ] **Step 4: Preserve launcher open/focus behavior**

Update `LauncherSurface` so the route opener passed to the host is selected explicitly. `requestOpen()` always requests `launcher`; `requestControlCenter()` requests `control-center` through the same coordinator and uses the same opener restoration. Do not focus the launcher search when the active route is control-center.

Update `LauncherSurfaceLogic` only if the state snapshot needs an explicit requested route; preserve all current launcher tests and the `refocus-search` behavior when the launcher is already open.

- [ ] **Step 5: Run all route tests and inspect warnings**

Run:

```bash
scripts/qmltest.sh tst_wave_surface_logic
scripts/qmltest.sh tst_overlay_coordinator_logic
scripts/qmltest.sh tst_lazer_wave_host
scripts/run-tests.sh tst_overlay_coordinator --no-python
```

Expected: PASS with no WARN/ERROR output.

- [ ] **Step 6: Commit**

```bash
git add modules/lazerbar/WaveSurfaceHost.qml modules/lazerbar/LauncherSurface.qml \
  modules/lazerbar/LauncherSurfaceLogic.js tests/qml/tst_lazer_wave_host.qml \
  tests/qml/tst_overlay_coordinator.qml
git commit -m "feat(wave): support retained sibling routes"
```

## Task 5: Build The Control-Center Card And Calendar Primitives

**Files:**
- Create: `modules/lazerbar/ControlCenterCard.qml`
- Create: `modules/lazerbar/ControlCenterCalendar.qml`
- Modify: `modules/lazerbar/qmldir`
- Create: `tests/qml/tst_control_center.qml`

**Interfaces:**
- `ControlCenterCard` accepts `title`, `summary`, `icon`, `status`, `available`, `error`, and emits `activated()`.
- `ControlCenterCalendar` exposes `viewYear`, `viewMonth`, `resetView()`, and renders a fixed six-row month grid.
- Both components are headless-testable without a `PanelWindow`.

- [ ] **Step 1: Write failing component tests**

In `tst_control_center.qml`, instantiate the new components under an `Item` root and verify:

```qml
function test_cardStatesRemainPaintable() {
    var card = cardComponent.createObject(root, {
        title: "Network", summary: "Unavailable", status: "unavailable",
        available: false
    })
    verify(card.visible)
    compare(card.status, "unavailable")
    card.destroy()
}

function test_calendarMonthNavigation() {
    var calendar = calendarComponent.createObject(root, { viewYear: 2026, viewMonth: 11 })
    calendar.stepMonth(1)
    compare(calendar.viewYear, 2027)
    compare(calendar.viewMonth, 0)
    calendar.destroy()
}
```

- [ ] **Step 2: Run to verify failure**

Run `scripts/qmltest.sh tst_control_center`. Expected: FAIL because the components do not exist.

- [ ] **Step 3: Implement the sharp card frame**

Use a square major surface, existing `LazerTheme` colors, `MotionTokens.fast` for perceptible state changes, and the settings-panel click/hover pattern. Keep all state labels inside the card bounds. The card must show a compact label for `loading`, `unavailable`, `empty`, and `error`; it must not open a modal error surface.

- [ ] **Step 4: Implement the calendar using existing math**

Import `../../modules/bar/widgets/ClockCalendar.js` and render the same Sunday-first weekday convention used by `ClockPopupContent.qml`. Use local state for previous/next month and highlight today. Use square step buttons with geometric arrow glyphs; do not duplicate `daysInMonth`, `firstWeekday`, or `stepMonth`.

- [ ] **Step 5: Register and test**

Register the two QML types in `modules/lazerbar/qmldir`, run `scripts/qmltest.sh tst_control_center`, and resolve all warnings before continuing.

- [ ] **Step 6: Commit**

```bash
git add modules/lazerbar/ControlCenterCard.qml modules/lazerbar/ControlCenterCalendar.qml \
  modules/lazerbar/qmldir tests/qml/tst_control_center.qml
git commit -m "feat(control-center): add card and calendar primitives"
```

## Task 6: Build Notification Summary And Control-Center Overview

**Files:**
- Create: `modules/lazerbar/ControlCenterNotifications.qml`
- Create: `modules/lazerbar/ControlCenter.qml`
- Modify: `modules/lazerbar/qmldir`
- Modify: `tests/qml/tst_control_center.qml`

**Interfaces:**
- `ControlCenterNotifications` accepts `notificationService`, `maxEntries` (default `2`), and emits `openRequested()`; opening does not call `markAllRead()`.
- `ControlCenter` accepts injected `networkService`, `bluetoothService`, `volumeService`, `mediaService`, `batteryService`, `notificationService`, and `weatherService` properties.
- `ControlCenter` exposes `title`, `description`, `sidebarEntries`, `canGoBack`, `focusDefault()`, and `handleBack()` for the Wave page contract.
- `ControlCenter` emits `networkDetailsRequested()` and `bluetoothDetailsRequested()`.
- `ControlCenter` uses `ControlCenterLogic.normalizeCard` to map each service snapshot.

- [ ] **Step 1: Extend failing QML tests with injected fakes**

Add fake service objects that expose only the documented properties/functions:

```qml
QtObject {
    id: fakeVolume
    property real sinkVolume: 0.42
    property bool sinkMuted: false
    function setSinkVolume(value) { sinkVolume = value }
    function toggleSinkMute() { sinkMuted = !sinkMuted }
}
```

Verify that the overview:

- has four control cards and no brightness/DND/power card;
- displays battery as header state only;
- caps notifications at two;
- renders with unavailable network/Bluetooth/media services;
- calls the fake volume setter and mute function;
- emits detail requests for network and Bluetooth;
- exposes a narrow layout without horizontal overflow.

- [ ] **Step 2: Run to verify failure**

Run `scripts/qmltest.sh tst_control_center`. Expected: FAIL because the overview components do not exist.

- [ ] **Step 3: Implement bounded notification summary**

Read `notificationService.unreadCount` and `historyList`/`latestNotification()` through a small adapter. Prefer `latestNotification()` plus a bounded `historyList.get(i)` loop when available. Never mutate read state during construction or visibility changes. Expose a “view all” action through a signal for the owning page to handle later.

- [ ] **Step 4: Implement the B1 overview**

Create a fixed wide grid with a left action column and right information column. Header content includes time/date, optional weather, and read-only battery. The left column contains exactly:

1. Network card, click emits `networkDetailsRequested()`.
2. Bluetooth card, click emits `bluetoothDetailsRequested()`.
3. Volume slider/mute action bound to `VolumeService.sinkVolume`, `sinkMuted`, `setSinkVolume()`, and `toggleSinkMute()`.
4. Media card bound to `MediaService.hasPlayer`, `title`, `artist`, `playing`, `canGoPrevious`, `canTogglePlayback`, `canGoNext`, `previous()`, `playPause()`, and `next()`.

The right column contains `ControlCenterCalendar` and `ControlCenterNotifications`. Keep notification height bounded. Use `Grid`/`Column` geometry with explicit minimum widths so labels cannot resize the panel.

- [ ] **Step 5: Add narrow layout and optional-state behavior**

Switch to the specified stack at the same breakpoint used by `ControlCenterLogic.layoutMode`. Order it as overview, controls, notifications, calendar. Do not use horizontal scrolling. Weather, battery, and all four service cards must render a non-blocking empty/unavailable state.

- [ ] **Step 6: Register and run tests**

Register `ControlCenter` and `ControlCenterNotifications` in `modules/lazerbar/qmldir`. Run:

```bash
scripts/qmltest.sh tst_control_center
```

Expected: PASS with no WARN/ERROR output.

- [ ] **Step 7: Commit**

```bash
git add modules/lazerbar/ControlCenter.qml modules/lazerbar/ControlCenterNotifications.qml \
  modules/lazerbar/qmldir tests/qml/tst_control_center.qml
git commit -m "feat(control-center): add balanced overview"
```

## Task 7: Add Same-Surface Network And Bluetooth Detail Pages

**Files:**
- Create: `modules/lazerbar/ControlCenterNetwork.qml`
- Create: `modules/lazerbar/ControlCenterBluetooth.qml`
- Modify: `modules/lazerbar/qmldir`
- Modify: `modules/lazerbar/ControlCenter.qml`
- Modify: `modules/lazerbar/WaveSurfaceHost.qml` or the route page wrapper from Task 4
- Modify: `tests/qml/tst_control_center.qml`
- Modify: `tests/qml/tst_lazer_wave_host.qml`

**Interfaces:**
- `ControlCenterNetwork` accepts `networkService`, exposes `canGoBack: true`, and emits `backRequested()`.
- `ControlCenterBluetooth` accepts `bluetoothService`, exposes `canGoBack: true`, and emits `backRequested()`.
- Detail pages use the existing service methods and properties; they do not call `nmcli`, `bluetoothctl`, or create a new service.
- Returning to the overview triggers a deferred status refresh via the injected services or a page `refreshAfterReturn()` hook.

- [ ] **Step 1: Write failing detail/back tests**

Add tests that:

```qml
function test_networkCardRequestsSameSurfaceDetail() {
    var page = controlCenterComponent.createObject(root, { networkService: fakeNetwork })
    var spy = signalSpy(page, "networkDetailsRequested")
    page.networkCard.activate()
    compare(spy.count, 1)
}
```

At host level, open `control-center`, request the network detail page, verify `pageCanGoBack`, press Escape, and verify the route returns to the overview instead of closing the Wave surface. Repeat for Bluetooth.

- [ ] **Step 2: Run to verify failure**

Run:

```bash
scripts/qmltest.sh tst_control_center
scripts/qmltest.sh tst_lazer_wave_host
```

Expected: FAIL because detail pages and route transitions are absent.

- [ ] **Step 3: Implement the network detail page**

Reuse the existing network service contract already used by `BarPopupActions`: `wifiEnabled`, `wifiConnected`, `networks`, `scanningActive`, `connecting`, `connectingTo`, `lastError`, `lastErrorSsid`, `refreshForOpen()`, `setWifiEnabled()`, `connect()`, `disconnect()`, `needsPasswordFor()`, and `isCredentialFailure()`.

Show wired status from `ethernetConnected`, `activeEthernetConnection`, `wiredGroups`, and `linkDetails`. Keep connection/password errors inline using the existing classified error strings. Limit the visible list to a bounded scrollable area, and ensure password input owns focus only while active.

- [ ] **Step 4: Implement the Bluetooth detail page**

Use `bluetoothAvailable`, `enabled`, `blocked`, `scanningActive`, `devices`, `connectedDevices`, `startScan()`, `setBluetoothEnabled()`, `pairDevice()`, `connectDeviceWithTrust()`, `disconnectDevice()`, `forgetDevice()`, `canPair()`, `canConnect()`, `canDisconnect()`, `isDeviceBusy()`, `getDeviceIcon()`, and `getSignalPercent()`.

Show unavailable/blocked/disabled states inline. Keep device rows bounded and action targets stable.

- [ ] **Step 5: Wire same-surface route transitions**

Use the Wave route/page contract from Task 4. A card click changes the active page inside the existing Wave host; it must not call the overlay coordinator or create another `PanelWindow`. Set `pageCanGoBack` while a detail page is active. On back, restore the retained overview immediately, then schedule one event-loop-turn refresh so the returned summary reflects the completed operation.

- [ ] **Step 6: Register and test**

Register the detail types, run the focused tests, and resolve all WARN/ERROR output:

```bash
scripts/qmltest.sh tst_control_center
scripts/qmltest.sh tst_lazer_wave_host
```

- [ ] **Step 7: Commit**

```bash
git add modules/lazerbar/ControlCenterNetwork.qml modules/lazerbar/ControlCenterBluetooth.qml \
  modules/lazerbar/ControlCenter.qml modules/lazerbar/WaveSurfaceHost.qml \
  modules/lazerbar/qmldir tests/qml/tst_control_center.qml tests/qml/tst_lazer_wave_host.qml
git commit -m "feat(control-center): add network and bluetooth detail pages"
```

## Task 8: Wire Production Services And The Control-Center Entry

**Files:**
- Modify: `modules/lazerbar/LauncherSurface.qml`
- Modify: `modules/lazerbar/TopBar.qml`
- Modify: `modules/lazerbar/qmldir` if imports require it
- Modify: `tests/qml/tst_overlay_coordinator.qml`
- Modify: `tests/qml/tst_qml_compiles.qml`
- Modify: `tests/qml/tst_bar_layout.qml` only if its production source assertions need an explicit control-center entry check.

**Interfaces:**
- Production `ControlCenter` receives `Services.NetworkService`, `Services.BluetoothService`, `Services.VolumeService`, `Services.MediaService`, `Services.BatteryService`, `Services.NotificationService`, and `Services.WeatherService`.
- `LauncherSurface.requestControlCenter(opener)` enters the shared coordinator with target `control-center`.
- The chosen top-bar trigger invokes `requestControlCenter()` through `screenScope.requestOverlay()`; no direct second surface is created.
- Default launcher shortcut/IPC still calls `LauncherSurface.requestOpen()` and selects `launcher`.

- [ ] **Step 1: Write failing production-shaped wiring tests**

Add tests to `tst_overlay_coordinator.qml` that verify:

```qml
function test_controlCenterUsesWaveOwnerAndDoesNotFocusLauncherSearch() {
    launcherSurface.requestControlCenter(opener)
    compare(openSpy.signalArguments[0][0], "wave")
    compare(openSpy.signalArguments[0][1], "control-center")
    tryCompare(launcherSurface.host, "phase", "open", 1600)
    compare(launcherSurface.host.route, "control-center")
    verify(!host.page().searchField.activeFocus)
}
```

Add a check that `requestOpen()` still emits target `launcher` after the new method exists.

- [ ] **Step 2: Run to verify failure**

Run `scripts/run-tests.sh tst_overlay_coordinator tst_qml_compiles --no-python`. Expected: the new method/route assertions fail before production wiring is added.

- [ ] **Step 3: Bind production services**

Pass the singleton properties through the existing `LauncherSurface` route components. Keep the bindings at the owner edge (`TopBar.qml` or `LauncherSurface.qml`) so page components remain fake-service injectable in tests. Keep battery read-only and weather optional.

- [ ] **Step 4: Add the control-center trigger**

Use the existing screen-scoped coordinator path. The trigger may be placed alongside the high-frequency status zone, but it must call:

```qml
screenScope.requestOverlay("control-center", controlCenterButtonItem)
```

and `requestOverlay()` must dispatch Wave targets through `launcherSurface.requestControlCenter(opener)`. Preserve current settings/music branches and focus restoration.

- [ ] **Step 5: Verify route mask and keyboard ownership**

The existing `waveWindow.mask` and exclusive keyboard focus should continue to use `launcherSurface.host.visible`/`interactive`. Verify the control center does not focus `LauncherPage.searchField`, while detail-page input can receive focus only when active.

- [ ] **Step 6: Run production-shaped checks**

Run:

```bash
scripts/run-tests.sh tst_overlay_coordinator tst_qml_compiles --no-python
scripts/qmltest.sh tst_bar_layout
```

Expected: PASS with no WARN/ERROR output.

- [ ] **Step 7: Commit**

```bash
git add modules/lazerbar/LauncherSurface.qml modules/lazerbar/TopBar.qml \
  modules/lazerbar/qmldir tests/qml/tst_overlay_coordinator.qml \
  tests/qml/tst_qml_compiles.qml tests/qml/tst_bar_layout.qml
git commit -m "feat(control-center): wire production wave entry"
```

## Task 9: Verify Full Behavior, Responsive Geometry, And Regression Boundaries

**Files:**
- Modify: `tests/qml/tst_control_center.qml` for final edge cases only.
- Modify: `tests/qml/tst_lazer_wave_host.qml` for final Escape/retention cases only.
- Modify: `tests/qml/tst_overlay_coordinator.qml` for final launcher/settings/music coexistence cases only.
- Modify: `docs/superpowers/specs/2026-10-04-wave-control-center-design.md` only if implementation reveals a necessary approved contract correction; otherwise leave the approved spec unchanged.

**Interfaces:**
- No new production API. This task is verification and regression repair only.

- [ ] **Step 1: Add the final acceptance tests**

Cover every acceptance requirement with concrete assertions:

```qml
function test_optionalServicesDoNotBlockOverview() {
    page.weatherService = unavailableWeather
    page.batteryService = unavailableBattery
    page.networkService = unavailableNetwork
    tryVerify(function() { return page.visible && page.controlCardCount === 4 }, 500)
}

function test_detailEscapeReturnsBeforeSurfaceClose() {
    host.openRoute("control-center")
    tryCompare(host, "phase", "open", 1600)
    page.openNetworkDetails()
    verify(host.pageCanGoBack)
    keyClick(Qt.Key_Escape)
    tryVerify(function() { return host.route === "control-center" && host.pageCanGoBack === false }, 500)
    verify(host.visible)
}
```

Also verify narrow geometry has no negative widths, no horizontal Flickable, and all four cards remain visible/reachable.

- [ ] **Step 2: Run the focused suite**

Run:

```bash
scripts/qmltest.sh tst_control_center_logic
scripts/qmltest.sh tst_weather_logic
scripts/qmltest.sh tst_control_center
scripts/qmltest.sh tst_lazer_wave_host
scripts/run-tests.sh tst_overlay_coordinator tst_qml_compiles --no-python
```

- [ ] **Step 3: Run the relevant broader suite**

Run:

```bash
scripts/run-tests.sh tst_wave_surface_logic tst_overlay_coordinator_logic \
  tst_clock_calendar tst_media_service tst_network_logic --no-python
```

Do not run window-only files unless explicitly requested. Resolve every warning and error before claiming completion.

- [ ] **Step 4: Inspect the final diff and worktree boundaries**

Run:

```bash
git diff --check HEAD~9..HEAD
git status --short
```

Confirm the diff contains only the control-center commits and that pre-existing unrelated modifications were not staged or reverted.

- [ ] **Step 5: Commit any verification-only fixes**

```bash
git add tests/qml/tst_control_center.qml tests/qml/tst_lazer_wave_host.qml \
  tests/qml/tst_overlay_coordinator.qml
git commit -m "test(control-center): cover wave integration"
```

## Plan Self-Review

- Spec coverage: route ownership is covered by Tasks 1, 4, and 8; B1 layout and four-card scope by Tasks 5 and 6; network/Bluetooth same-surface details by Task 7; volume/media direct actions by Task 6; calendar reuse by Task 5; notification bounded summary by Task 6; weather cache/failure behavior by Task 3; lifecycle and Escape behavior by Tasks 4, 7, and 9; testing and acceptance by Task 9.
- Placeholder scan: no `TBD`, `TODO`, `FIXME`, or unspecified “handle edge cases” steps are used.
- Type consistency: the page contract names `title`, `description`, `sidebarEntries`, `canGoBack`, `focusDefault()`, and `handleBack()` consistently; service property/function names match the inspected singleton files.
- Scope check: the work is one Wave control-center subsystem with its required weather adapter and tests. It does not include brightness, DND, power, or settings refactors.
