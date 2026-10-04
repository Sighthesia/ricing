import QtQuick
import QtTest
import "../../modules/lazerbar/ControlCenterLogic.js" as Logic

// Verify the pure control-center contracts: card normalization into explicit
// states, layout mode and section order, bounded notification summaries, weather
// states, and back precedence. No service is involved, so this stays headless.
Item {
    id: testRoot
    width: 800
    height: 600

    TestCase {
        name: "ControlCenterLogic"
        when: windowShown
        width: 800
        height: 600

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

        function test_cardTitlesIconsAndActions() {
            // Exactly four core controls: battery is header state, and there is
            // no brightness, DND, or power card in this version.
            verify(Logic.isCardKind("network"))
            verify(Logic.isCardKind("bluetooth"))
            verify(Logic.isCardKind("volume"))
            verify(Logic.isCardKind("media"))
            verify(!Logic.isCardKind("brightness"))
            verify(!Logic.isCardKind("power"))
            verify(!Logic.isCardKind("dnd"))
            verify(!Logic.isCardKind("battery"))
            // Each control has its own title and icon.
            compare(Logic.normalizeCard("network", { connected: true, summary: "Home" }).icon,
                    "../bar/icons/wifi.svg")
            compare(Logic.normalizeCard("bluetooth", { enabled: true, devices: [{ name: "KBD" }] }).icon,
                    "../bar/icons/bluetooth.svg")
            compare(Logic.normalizeCard("volume", { sinkVolume: 0.4 }).icon,
                    "../bar/icons/volume.svg")
            compare(Logic.normalizeCard("media", { hasPlayer: true, title: "T" }).icon,
                    "icons/music.svg")
            // Network and Bluetooth open same-surface detail pages; volume and
            // media act directly from the overview.
            compare(Logic.normalizeCard("bluetooth", { enabled: true, devices: [{ name: "KBD" }] }).action,
                    "detail")
            compare(Logic.normalizeCard("volume", { sinkVolume: 0.4 }).action, "direct")
            compare(Logic.normalizeCard("media", { hasPlayer: true, title: "T" }).action, "direct")
            // Only the two detail cards name a route.
            compare(Logic.normalizeCard("network", {}).detailRoute, "network-detail")
            compare(Logic.normalizeCard("volume", {}).detailRoute, "")
            compare(Logic.normalizeCard("media", {}).detailRoute, "")
        }

        function test_cardStatePrecedence() {
            // A failed service outranks every other state, and an error card
            // stays inert instead of opening a detail page with nothing in it.
            var failed = Logic.normalizeCard("network", { available: true, loading: true, error: "boom" })
            compare(failed.status, "error")
            compare(failed.error, "boom")
            compare(failed.summary, "boom")
            compare(failed.action, "none")
            // Loading outranks an absent adapter; unavailable outranks empty.
            compare(Logic.normalizeCard("bluetooth", { loading: true }).status, "loading")
            compare(Logic.normalizeCard("bluetooth", { available: false, devices: [] }).status, "unavailable")
            // Empty is only reported when the snapshot says so, or when a scanned
            // device list is genuinely empty.
            compare(Logic.normalizeCard("media", { hasPlayer: false }).status, "empty")
            compare(Logic.normalizeCard("media", { hasPlayer: false }).summary, "No media")
            compare(Logic.normalizeCard("bluetooth", { enabled: true, devices: [], connectedDevices: [] }).status,
                    "empty")
            compare(Logic.normalizeCard("network", {}).status, "ready")
            compare(Logic.normalizeCard("network", { empty: true }).status, "empty")
            // A non-ready card has no label to summarize beyond its state.
            compare(Logic.normalizeCard("bluetooth", { loading: true }).action, "none")
            compare(Logic.normalizeCard("volume", { available: false }).action, "none")
            compare(Logic.normalizeCard("volume", { available: false }).available, false)
        }

        function test_cardSummaries() {
            // An explicit summary always wins, so a caller can phrase its own
            // service state instead of the module guessing.
            compare(Logic.normalizeCard("network", { summary: "Home" }).summary, "Home")
            compare(Logic.normalizeCard("network", { connected: true, ssid: "Home" }).summary, "Home")
            compare(Logic.normalizeCard("network", { connected: true }).summary, "Connected")
            compare(Logic.normalizeCard("network", { connected: false, wifiEnabled: false }).summary, "Off")
            compare(Logic.normalizeCard("network", { connected: false }).summary, "Not connected")
            compare(Logic.normalizeCard("bluetooth", { enabled: true, devices: [], connectedDevices: [{ name: "KBD" }] }).summary,
                    "1 connected")
            compare(Logic.normalizeCard("bluetooth", { enabled: true, devices: [], connectedDevices: [] }).summary,
                    "No devices")
            compare(Logic.normalizeCard("volume", { sinkVolume: 0.42 }).summary, "42%")
            compare(Logic.normalizeCard("volume", { sinkVolume: 0.42, sinkMuted: true }).summary, "Muted")
            compare(Logic.normalizeCard("media", { hasPlayer: true, title: "Night", artist: "xi" }).summary,
                    "xi — Night")
            compare(Logic.normalizeCard("media", { hasPlayer: true, title: "Night" }).summary, "Night")
            compare(Logic.normalizeCard("media", { hasPlayer: true }).summary, "Paused")
            // A missing snapshot must not throw and must not invent a state.
            var missing = Logic.normalizeCard("network", null)
            compare(missing.status, "ready")
            compare(missing.title, "Network")
            compare(missing.error, "")
            verify(missing.available)
        }

        function test_weatherUnavailableWhileLoading() {
            // A refresh in flight still reads as loading, so the header never
            // shows an empty block for a request that is about to land.
            compare(Logic.weatherState({ loading: true, available: false }), "loading")
            compare(Logic.weatherState({}), "empty")
            compare(Logic.weatherState(null), "empty")
            compare(Logic.weatherState({ available: true, lastError: "timeout" }), "empty")
            // A failed refresh keeps the cached reading, which reads as stale
            // rather than dropping back to unavailable.
            compare(Logic.weatherState({ available: true, temperature: 18, lastError: "timeout" }), "stale")
            compare(Logic.weatherState({ available: true, temperature: 18, isStale: true }), "stale")
        }

        function test_notificationSummaryIsBounded() {
            // The cap is a module constant: a caller that forgets the limit
            // still cannot make the summary a layout dependency.
            compare(Logic.notificationSummary([{ notifId: "a" }, { notifId: "b" }, { notifId: "c" }], 4).entries.length,
                    2)
            // A missing or hostile limit resolves to the same fixed cap.
            compare(Logic.notificationSummary([{ notifId: "a" }, { notifId: "b" }], 4, 0).entries.length, 2)
            compare(Logic.notificationSummary([{ notifId: "a" }, { notifId: "b" }], 4, -3).entries.length, 2)
            compare(Logic.notificationSummary([{ notifId: "a" }, { notifId: "b" }], 4, Number.NaN).entries.length, 2)
            // A source shorter than the cap is returned whole, in order.
            var single = Logic.notificationSummary([{ notifId: "a" }], 1, 2)
            compare(single.entries.length, 1)
            compare(single.entries[0].notifId, "a")
            // Unread count is clamped, and a missing source is not an error.
            compare(Logic.notificationSummary(null, null).unreadCount, 0)
            compare(Logic.notificationSummary(null, -3).unreadCount, 0)
            compare(Logic.notificationSummary(null, 4.7).unreadCount, 4)
            compare(Logic.notificationSummary(null, 4).entries.length, 0)
        }

        function test_notificationSummaryDoesNotMutateSource() {
            var source = [{ notifId: "a" }, { notifId: "b" }, { notifId: "c" }]
            var summary = Logic.notificationSummary(source, 3, 2)
            compare(source.length, 3)
            compare(summary.entries.length, 2)
            // The returned array is a copy, so trimming one summary cannot trim
            // the next caller.
            summary.entries.length = 0
            compare(Logic.notificationSummary(source, 3, 2).entries.length, 2)
        }

        function test_layoutModeAndSectionOrderAreDefensive() {
            // A garbage width must never buy the wider layout.
            compare(Logic.layoutMode(Number.NaN, 760), "narrow")
            compare(Logic.layoutMode(-10, 760), "narrow")
            compare(Logic.layoutMode(undefined, 760), "narrow")
            // The breakpoint defaults to the same value the settings panel uses,
            // so a caller that omits it still agrees with the page.
            compare(Logic.layoutMode(760, 0), "wide")
            compare(Logic.layoutMode(900), "wide")
            compare(Logic.layoutMode(759), "narrow")
            // The narrow order is fixed and never derived from content: the
            // stacked sections are the same with an empty service list.
            compare(Logic.sectionOrder("narrow").stacked.join(","),
                    "overview,controls,notifications,calendar")
            compare(Logic.sectionOrder("narrow").left.join(","), "")
            compare(Logic.sectionOrder("narrow").right.join(","), "")
            compare(Logic.sectionOrder("wide").stacked.join(","), "")
            compare(Logic.sectionOrder("wide").left.join(","), "controls")
            compare(Logic.sectionOrder("wide").right.join(","), "calendar,notifications")
            // An unknown mode must not leave a page without an order.
            compare(Logic.sectionOrder(undefined).stacked.join(","),
                    "overview,controls,notifications,calendar")
            compare(Logic.sectionOrder("wide-ish").left.join(","), "")
        }

        function test_sectionOrderIsCopiedPerCall() {
            // A page that trims its own list must not corrupt the next read.
            var order = Logic.sectionOrder("narrow")
            order.stacked.push("extra")
            order.stacked.shift()
            compare(Logic.sectionOrder("narrow").stacked.join(","),
                    "overview,controls,notifications,calendar")
            var wide = Logic.sectionOrder("wide")
            wide.right.push("controls")
            compare(Logic.sectionOrder("wide").right.join(","), "calendar,notifications")
        }

        function test_backActionPrecedence() {
            // A detail page always consumes back first.
            compare(Logic.backAction("control-center", true, true), "detail")
            compare(Logic.backAction("control-center", true, false), "detail")
            compare(Logic.backAction("network-detail", false, false), "detail")
            // Then the sibling route, then closing the surface.
            compare(Logic.backAction("control-center", false, true), "launcher")
            compare(Logic.backAction("control-center", false, false), "close")
            compare(Logic.backAction("launcher", false, true), "launcher")
            compare(Logic.backAction("", false, false), "close")
            compare(Logic.backAction(null, null, undefined), "close")
            // A missing detail flag is not a detail page.
            compare(Logic.backAction("control-center", undefined, true), "launcher")
            compare(Logic.backAction("control-center", null, true), "launcher")
        }
    }
}