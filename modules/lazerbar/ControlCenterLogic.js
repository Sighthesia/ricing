.pragma library

// Pure control-center contracts: card normalization, layout mode and section
// order, bounded notification summaries, weather state, and back precedence.
//
// Card snapshots arrive from services this page does not own, so every state
// decision lives here and the QML side only decides how a state looks. There is
// no service, Qt, or asset import: the headless logic tests load this module
// directly, and a missing or hostile snapshot degrades to an explicit state
// instead of throwing.
//
// Icon strings are relative paths resolved against the consuming component's
// directory. ControlCenterCard lives in modules/lazerbar/, which is why the bar
// assets are reached through "../bar/".

// Exactly four core controls. Battery is read-only header state and weather is
// an optional header, so neither is a card.
var cardKinds = ["network", "bluetooth", "volume", "media"]

var cardTitles = {
    network: "Network",
    bluetooth: "Bluetooth",
    volume: "Volume",
    media: "Media"
}

var cardIcons = {
    network: "../bar/icons/wifi.svg",
    bluetooth: "../bar/icons/bluetooth.svg",
    volume: "../bar/icons/volume.svg",
    media: "icons/music.svg"
}

// Detail pages are same-surface sub-pages of the control center, never sibling
// Wave routes, so their names are declared here and nowhere else.
var detailRoutes = {
    network: "network-detail",
    bluetooth: "bluetooth-detail"
}

// Fixed labels for the states a card can report. The card frame shows one of
// these instead of opening a modal error surface.
var loadingLabel = "Loading…"
var unavailableLabel = "Unavailable"

var emptyLabels = {
    network: "No networks",
    bluetooth: "No devices",
    volume: "No output",
    media: "No media"
}

var defaultEmptyLabel = "Nothing to show"

// Fixed, not derived from content: a longer notification history must never
// change the layout.
var notificationEntryCap = 2

// The two-column breakpoint. It matches the settings panel's own threshold, so
// both surfaces reach their wide layout at the same width.
var minimumTwoColumnWidth = 760

var narrowSections = ["overview", "controls", "notifications", "calendar"]
var wideLeftSections = ["controls"]
var wideRightSections = ["calendar", "notifications"]

function isCardKind(kind) {
    return typeof kind === "string" && cardKinds.indexOf(kind) >= 0
}

// Normalize one service snapshot into the plain card object the page renders.
function normalizeCard(kind, snapshot) {
    var value = snapshot || {}
    return {
        title: titleFor(kind),
        summary: summaryFor(kind, value),
        status: statusFor(kind, value),
        icon: iconFor(kind),
        available: value.available !== false,
        action: actionFor(kind, value),
        detailRoute: detailRouteFor(kind),
        error: errorText(value)
    }
}

// A failed service outranks everything else, then an in-flight read, then a
// missing adapter, then emptiness. "ready" means the card has something to show.
function statusFor(kind, value) {
    if (errorText(value) !== "")
        return "error"
    if (value.loading === true)
        return "loading"
    if (value.available === false)
        return "unavailable"
    if (isEmpty(kind, value))
        return "empty"
    return "ready"
}

// Emptiness is the caller's to declare; it is only derived where the service
// contract makes the answer unambiguous.
//
// Volume is the case that needs the caller to declare it. VolumeService reports
// `sinkVolume: 0` and `sinkMuted: false` when there is no output device at all -
// those are the reads it has to make against a null default sink - so a snapshot
// without an emptiness declaration renders a real-looking "0%" that is actionable
// against a sink that does not exist. `defaultSinkNode` is what the card's caller
// turns into `empty`; see ControlCenter.qml's volumeSnapshot.
function isEmpty(kind, value) {
    if (typeof value.empty === "boolean")
        return value.empty
    // An unscanned Bluetooth adapter reports a null list, so only a real array
    // means "scanned, and there is nothing".
    if (kind === "bluetooth")
        return countOf(value.devices) === 0 && countOf(value.connectedDevices) === 0
    if (kind === "media")
        return value.hasPlayer === false
    // A disconnected network is a real state, not an empty list.
    return false
}

function titleFor(kind) {
    if (typeof kind !== "string" || kind === "")
        return ""
    return cardTitles[kind] || kind.charAt(0).toUpperCase() + kind.slice(1)
}

function iconFor(kind) {
    return typeof kind === "string" && cardIcons[kind] ? cardIcons[kind] : ""
}

function detailRouteFor(kind) {
    return typeof kind === "string" && detailRoutes[kind] ? detailRoutes[kind] : ""
}

// A route is a name, so reject anything else before matching. The check is not
// belt-and-braces: volume and media have no detailRoutes entry, so their lookup
// reads undefined and would otherwise compare equal to a route that was never
// supplied, resolving an unbound route to the detail page instead of the
// launcher or the surface close.
function isDetailRoute(route) {
    if (typeof route !== "string" || route === "")
        return false
    for (var i = 0; i < cardKinds.length; i++) {
        if (detailRoutes[cardKinds[i]] === route)
            return true
    }
    return false
}

// What activating the card does. Network and Bluetooth hand off to a
// same-surface detail page; volume and media act directly from the overview; a
// card with nothing to show stays inert.
function actionFor(kind, value) {
    if (statusFor(kind, value) !== "ready")
        return "none"
    return detailRouteFor(kind) !== "" ? "detail" : "direct"
}

// The single status line inside the card bounds. A ready card shows the
// service's own summary or a derived one; every other state shows its label,
// except an error which shows the service's own words.
function summaryFor(kind, value) {
    var status = statusFor(kind, value)
    if (status === "ready")
        return readySummary(kind, value)
    if (status === "error")
        return errorText(value)
    if (status === "empty")
        return emptyLabels[kind] || defaultEmptyLabel
    return status === "loading" ? loadingLabel : unavailableLabel
}

function readySummary(kind, value) {
    var explicit = text(value.summary)
    if (explicit !== "")
        return explicit
    if (kind === "network")
        return networkSummary(value)
    if (kind === "bluetooth")
        return bluetoothSummary(value)
    if (kind === "volume")
        return volumeSummary(value)
    if (kind === "media")
        return mediaSummary(value)
    return ""
}

function networkSummary(value) {
    if (value.connected === true || value.wifiConnected === true)
        return text(value.ssid) || text(value.activeSsid) || "Connected"
    if (value.ethernetConnected === true)
        return text(value.activeEthernetConnection) || "Wired"
    if (value.wifiEnabled === false)
        return "Off"
    return "Not connected"
}

function bluetoothSummary(value) {
    var connected = countOf(value.connectedDevices)
    if (connected > 0)
        return connected + " connected"
    if (value.blocked === true)
        return "Blocked"
    if (value.enabled === false)
        return "Off"
    if (value.scanningActive === true)
        return "Scanning"
    var known = countOf(value.devices)
    if (known > 0)
        return known + " devices"
    return "Not connected"
}

function volumeSummary(value) {
    if (value.sinkMuted === true)
        return "Muted"
    var volume = toNumber(value.sinkVolume, Number.NaN)
    return isFinite(volume) ? Math.round(volume * 100) + "%" : "No output device"
}

function mediaSummary(value) {
    var title = text(value.title)
    var artist = text(value.artist)
    if (title !== "" && artist !== "")
        return artist + " — " + title
    if (title !== "")
        return title
    if (artist !== "")
        return artist
    if (value.playbackState === "playing" || value.playing === true)
        return "Playing"
    return "Paused"
}

// The header's weather state. Optional weather must never block the first
// surface open, so the ladder is ordered by what the user would lose:
//
//   1. a usable cached reading always wins, and an in-flight refresh does not
//      hide it - the whole point of a cache-first adapter is that the number
//      survives the request that is replacing it
//   2. with nothing cached, an in-flight refresh is "loading" rather than an
//      absence, because a request that has not landed is not a missing value
//   3. an absent service is "unavailable" rather than an empty reading
//   4. a service that reports a reading-shaped answer of NaN is "empty"
//
// A failed refresh keeps the previous reading and reports through `lastError`,
// so it lands on 1 as "stale" - the value stays, and the word beside it says
// why it may be wrong.
function weatherState(snapshot) {
    var value = snapshot || {}
    if (isFinite(usableTemperature(value.temperature))) {
        return value.isStale === true || weatherErrorText(value) !== ""
            ? "stale" : "ready"
    }
    if (value.loading === true)
        return "loading"
    if (value.available === false)
        return "unavailable"
    return "empty"
}

// A cached temperature, or NaN when the service has no reading yet.
//
// Strict on purpose, following the rule services/weather/WeatherLogic.js
// already applies to a parsed payload: plain Number() maps null to 0 and "" to
// 0, so a service with nothing cached yet would produce a confident, plausible
// "0°" - and the header could not then tell a real 0-degree reading from no
// reading at all, which is exactly the distinction the ladder above needs.
function usableTemperature(raw) {
    if (raw == null || typeof raw === "boolean")
        return Number.NaN
    if (typeof raw === "string" && raw.trim() === "")
        return Number.NaN
    var number = Number(raw)
    return isFinite(number) ? number : Number.NaN
}

// How old a reading is, as the compact word the header shows beside it.
//
// Both arguments are full epoch milliseconds: the reading's own stamp and the
// current clock. The label is deliberately coarse - a header has room for one
// short word, not a duration - and it is "" whenever the age is not knowable, so
// the header omits the age instead of printing a confident wrong one:
//
//   - no stamp, a non-numeric stamp, or a zero stamp: there is no reading to date
//   - a stamp dated in the future: a clock change, not a reading from the future,
//     and "−3m ago" would be a lie
//
// A missing `now` is treated the same way: the module has no clock of its own,
// so a caller that cannot say what time it is gets no age rather than a wrong one.
function weatherAgeLabel(updatedAt, now) {
    var stamp = toNumber(updatedAt, Number.NaN)
    var current = toNumber(now, Number.NaN)
    if (!isFinite(stamp) || stamp <= 0 || !isFinite(current))
        return ""
    var age = current - stamp
    if (age < 0)
        return ""
    if (age < weatherMinuteMs)
        return "now"
    if (age < weatherHourMs)
        return Math.floor(age / weatherMinuteMs) + "m ago"
    if (age < weatherDayMs)
        return Math.floor(age / weatherHourMs) + "h ago"
    return Math.floor(age / weatherDayMs) + "d ago"
}

var weatherMinuteMs = 60 * 1000
var weatherHourMs = 60 * weatherMinuteMs
var weatherDayMs = 24 * weatherHourMs

function layoutMode(width, minimumWidth) {
    var available = toNumber(width, 0)
    var minimum = toNumber(minimumWidth, minimumTwoColumnWidth)
    if (!(minimum > 0))
        minimum = minimumTwoColumnWidth
    return available >= minimum ? "wide" : "narrow"
}

// Section order for one layout mode. Every mode returns all three arrays, empty
// where they do not apply, so a page binding to any of them cannot go undefined.
// Each call returns fresh arrays: a consumer trimming its list must not corrupt
// the next read.
function sectionOrder(mode) {
    if (mode === "wide") {
        return { stacked: [], left: wideLeftSections.slice(), right: wideRightSections.slice() }
    }
    return { stacked: narrowSections.slice(), left: [], right: [] }
}

// Bound the notification history to a fixed cap and report the unread count
// separately, so a busy history cannot stretch the panel.
function notificationSummary(entries, unreadCount, limit) {
    var cap = effectiveCap(limit)
    var kept = []
    if (entries != null && typeof entries.length === "number") {
        for (var i = 0; i < entries.length && kept.length < cap; i++) {
            if (entries[i] != null)
                kept.push(entries[i])
        }
    }
    return {
        unreadCount: Math.max(0, Math.floor(toNumber(unreadCount, 0))),
        entries: kept
    }
}

function effectiveCap(limit) {
    var requested = toNumber(limit, Number.NaN)
    return isFinite(requested) && requested > 0 ? Math.floor(requested) : notificationEntryCap
}

// What a back request resolves to inside this view, in precedence order: an
// active detail page consumes back itself, and anything else is the OWNER's
// step - the launcher page that shows this view decides what leaves it and what
// closes the surface. The owner may report the detail page as a boolean or by
// name.
//
// "none" is deliberately not "close". The control center is a view inside the
// launcher's content area, not a sibling route, so it no longer owns the
// decision that ends the surface; naming that decision here would let a page
// that cannot act on it advertise an exit it never performs.
function backAction(route, detailPage) {
    if (isDetailRoute(route) || isActiveDetail(detailPage))
        return "detail"
    return "none"
}

function isActiveDetail(detailPage) {
    return detailPage != null && detailPage !== false && detailPage !== 0 && detailPage !== ""
}

function errorText(value) {
    return errorFrom(value.error)
}

function weatherErrorText(value) {
    return errorFrom(value.lastError != null ? value.lastError : value.error)
}

function errorFrom(raw) {
    if (raw == null || raw === false || raw === 0 || raw === "")
        return ""
    return text(raw)
}

function text(value) {
    if (value == null)
        return ""
    return String(value).trim()
}

function toNumber(value, fallback) {
    var number = Number(value)
    return isFinite(number) ? number : fallback
}

// Length of an array-like value, or -1 when there is no list to count. A string
// is excluded: its length is not a device count.
function countOf(value) {
    if (value == null || typeof value === "string")
        return -1
    var count = Number(value.length)
    return isFinite(count) ? count : -1
}