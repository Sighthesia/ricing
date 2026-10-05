import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/ControlCenterLogic.js" as CcLogic
import "../../modules/bar/widgets/ClockCalendar.js" as Calendar

// Headless coverage for the control center's two reusable primitives: the sharp
// card frame and the local month calendar. Both must load, lay out, answer input
// and render every declared state under a plain Item root - no PanelWindow, no
// Quickshell singleton, no compositor.
//
// The calendar is asserted against `ClockCalendar.js` directly rather than
// against numbers copied out of the component, so the assertion proves the
// component delegates its date math to the bar module instead of forking it.
Item {
    id: root
    width: 1024
    height: 768

    // Card and calendar are built through Components so each test owns a fresh
    // instance with its own state, the same way the page will build them.
    Component {
        id: cardComponent
        Lazer.ControlCenterCard {}
    }

    Component {
        id: calendarComponent
        Lazer.ControlCenterCalendar {}
    }

    Component {
        id: notificationsComponent
        Lazer.ControlCenterNotifications {}
    }

    Component {
        id: pageComponent
        Lazer.ControlCenter {}
    }

    // --- Injected service fakes ---
    //
    // Each fake declares ONLY the properties and functions the page is
    // documented to read, so a binding that reaches for anything else resolves
    // to undefined here exactly as an absent service would in production. Call
    // counters prove the page called the service rather than shadowing it.

    Component {
        id: fakeNetworkComponent
        QtObject {
            property bool wifiConnected: true
            property bool wifiEnabled: true
            property string activeSsid: "Home"
            property bool ethernetConnected: false
            property string activeEthernetConnection: ""
            property bool scanningActive: false
            property bool connecting: false
            property string connectingTo: ""
            property string lastError: ""
        }
    }

    Component {
        id: fakeBluetoothComponent
        QtObject {
            property bool bluetoothAvailable: true
            property bool enabled: true
            property bool blocked: false
            property bool scanningActive: false
            property var devices: [{ name: "Speaker" }]
            property var connectedDevices: []
            property int scanCalls: 0

            function startScan() { scanCalls++ }
        }
    }

    // The brief's shape verbatim, plus call counters so the assertion can tell
    // "the page called the setter" from "the page wrote its own copy".
    Component {
        id: fakeVolumeComponent
        QtObject {
            property real sinkVolume: 0.42
            property bool sinkMuted: false
            property int setCalls: 0
            property int muteCalls: 0

            function setSinkVolume(value) {
                sinkVolume = value
                setCalls++
            }

            function toggleSinkMute() {
                sinkMuted = !sinkMuted
                muteCalls++
            }
        }
    }

    Component {
        id: fakeMediaComponent
        QtObject {
            property bool hasPlayer: true
            property string title: "Blue Bird"
            property string artist: "IOSYS"
            property bool playing: true
            property string playbackState: "playing"
            property bool canGoPrevious: true
            property bool canTogglePlayback: true
            property bool canGoNext: true
            property int previousCalls: 0
            property int playPauseCalls: 0
            property int nextCalls: 0

            function previous() { previousCalls++ }
            function playPause() { playPauseCalls++ }
            function next() { nextCalls++ }
        }
    }

    Component {
        id: fakeBatteryComponent
        QtObject {
            property bool available: true
            property bool ready: true
            property int percentage: 87
            property bool charging: false
            property bool pluggedIn: false
            property string iconText: "BAT"
        }
    }

    // A real ListModel, because the production read path goes through
    // historyList.count and historyList.get(i); a plain array would not exercise
    // the same binding invalidation.
    Component {
        id: fakeNotificationComponent
        QtObject {
            property int unreadCount: 0
            property int markAllCalls: 0
            property int markReadCalls: 0
            property var historyList: ListModel {}

            function latestNotification() {
                return historyList.count > 0 ? historyList.get(0) : null
            }

            function markAllRead() { markAllCalls++ }
            function markRead(notifId) { markReadCalls++ }
        }
    }

    // A notification service that exposes only the history list: no
    // latestNotification() helper at all, so the summary's fallback read path
    // is the only one that can work.
    Component {
        id: fakeHistoryOnlyNotificationComponent
        QtObject {
            property int unreadCount: 0
            property var historyList: null
        }
    }

    // A history list that COUNTS its own reads. The cap on the RENDERED summary is
    // provable from the entries, but the cap on the WALK is not: a summary that
    // read all 120 history rows and then threw 118 of them away renders exactly
    // the same two entries. This makes the walk itself observable.
    //
    // `noLatest` selects the shape: the production service has a
    // latestNotification() helper and this one deliberately does not, so the
    // bounded walk is the only read path and its cost is fully attributable.
    //
    // The counter lives in a plain JS object rather than in a QML property, and
    // that is load-bearing: the summary's adapter reads get() from inside a
    // binding, so a get() that assigned a QML property emitted a notify while the
    // binding that called it was still evaluating, and Qt answered with "Binding
    // loop detected for property rawEntries". Mutating a plain object notifies
    // nobody, the binding stays clean, and the count is still exact. The real
    // `ListModel.get()` has always been pure, which is why production never saw it.
    Component {
        id: countingHistoryComponent
        QtObject {
            // Not a QML property: nothing may notify from inside get().
            readonly property var reads: ({ count: 0 })
            property var rows: []
            property bool noLatest: false
            readonly property int count: rows.length

            function readCount() { return reads.count }

            function get(index) {
                reads.count++
                return rows[index] != null ? rows[index] : null
            }

            function latestNotification() {
                return noLatest ? null : countingHead.value
            }
        }
    }

    // The head entry a counting fake's latestNotification() hands back, so one
    // component serves both read shapes.
    QtObject {
        id: countingHead
        property var value: null
    }

    // The notification service that owns a counting history: unread count plus the
    // helper, so the summary's two read paths are both exercised.
    Component {
        id: fakeCountingNotificationComponent
        QtObject {
            property int unreadCount: 0
            property var historyList: null
            property int markAllCalls: 0

            function latestNotification() { return countingHead.value }
            function markAllRead() { markAllCalls++ }
        }
    }

    Component {
        id: fakeWeatherComponent
        QtObject {
            property real temperature: 18.5
            property string condition: "partly-cloudy"
            property string location: "Shanghai"
            property double updatedAt: 0
            property bool isStale: false
            property bool available: true
            property bool loading: false
            property string lastError: ""
        }
    }

    // Activation is observed from outside the card so the assertion reads the
    // emitted signal rather than an internal flag.
    QtObject {
        id: activationProbe
        property int count: 0
    }

    // Every component a test builds is parented to one per-test host. A failed
    // assertion abandons the test function before its own destroy() line, and an
    // abandoned card would keep answering the NEXT test's clicks - which then
    // fails for a reason that has nothing to do with it. init() creates the host
    // and cleanup() destroys it, so nothing can outlive its test and no
    // destroy() ever runs twice.
    Component {
        id: hostComponent
        Item {
            width: root.width
            height: root.height
            // Fakes are parented here too, so a failed assertion cannot leave a
            // fake behind holding state the next test would read as its own.
            property var fakes: []
        }
    }

    property Item testHost: null

    TestCase {
        name: "ControlCenter"

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            activationProbe.count = 0
            // The counting fake's head entry is a root-level object so the
            // component can be declared once for both read shapes; reset per test
            // so a stale head cannot leak into the next one's count.
            countingHead.value = null
            root.testHost = hostComponent.createObject(root)
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
            if (root.testHost) {
                root.testHost.destroy()
                root.testHost = null
            }
        }

        function makeCard(properties) {
            var args = { x: 0, y: 0, width: 320, height: 64 }
            for (var key in properties)
                args[key] = properties[key]
            return cardComponent.createObject(root.testHost, args)
        }

        // The calendar needs a settled layout before a synthetic click means
        // anything: its step buttons live inside a Column, so their positions are
        // assigned during polish, and mouseClick maps coordinates through the
        // scene graph rather than through the item's own x/y.
        function makeCalendar(properties) {
            var args = { x: 0, y: 0, width: 260 }
            for (var key in properties)
                args[key] = properties[key]
            return calendarComponent.createObject(root.testHost, args)
        }

        // --- Overview harness helpers ---

        // The page owns no timer, but its clock is injectable, so a fixed date
        // makes every header string deterministic.
        function makePage(properties) {
            var args = {
                x: 0, y: 0,
                width: 1024, height: 720,
                now: new Date(2026, 9, 12, 9, 41)
            }
            for (var key in properties)
                args[key] = properties[key]
            var page = pageComponent.createObject(root.testHost, args)
            if (page.now === undefined || page.now === null)
                page.now = new Date(2026, 9, 12, 9, 41)
            return page
        }

        function makeFake(component, properties) {
            var args = {}
            for (var key in (properties || {}))
                args[key] = properties[key]
            var fake = component.createObject(root.testHost, args)
            registerFake(fake)
            return fake
        }

        // Fakes live in the per-test host's own list, so destroying the host
        // takes them with it.
        function registerFake(fake) {
            if (fake)
                root.testHost.fakes.push(fake)
            return fake
        }

        // Newest first, which is the order NotificationService keeps: it inserts
        // every arriving notification at index 0, so historyList.get(0) is the
        // latest and the summary must read from the head.
        function seedNotifications(fake, count) {
            for (var i = 1; i <= count; i++) {
                fake.historyList.insert(0, {
                    notifId: "n" + i,
                    appName: "App " + i,
                    summary: "Message " + i,
                    body: "Body " + i,
                    icon: "",
                    timestamp: 1000 + i,
                    read: i % 2 === 0
                })
            }
            fake.unreadCount = count
            return fake
        }

        // Every visual descendant, including Repeater delegates. A Repeater
        // leaves one role-less placeholder among its children, and it measures
        // zero, so the geometry assertions simply see a zero-width box.
        function descendants(item, out) {
            out = out || []
            var kids = item.children
            for (var i = 0; i < kids.length; i++) {
                out.push(kids[i])
                descendants(kids[i], out)
            }
            return out
        }

        // Any scroll container the page put on screen. The narrow layout must
        // not scroll sideways, so the assertion is that this stays empty.
        function scrollContainers(item, out) {
            out = out || []
            var kids = item.children
            for (var i = 0; i < kids.length; i++) {
                var child = kids[i]
                if (child.contentWidth !== undefined && child.contentHeight !== undefined
                        && child.flickableDirection !== undefined)
                    out.push(child)
                scrollContainers(child, out)
            }
            return out
        }

        function calendarSettled(calendar) {
            return calendar.previousButtonItem.x > 0 && calendar.nextButtonItem.x > 0
                    && calendar.monthLabelItem.width > 0 && calendar.gridItem.height > 0
        }

        // A Repeater leaves one role-less placeholder among its children, so
        // every sweep here filters on a declared delegate property instead of
        // counting children.
        function delegates(calendar, propertyName) {
            var kept = []
            var kids = calendar.gridItem.children
            for (var i = 0; i < kids.length; i++) {
                if (kids[i][propertyName] !== undefined)
                    kept.push(kids[i])
            }
            return kept
        }

        function delegatesWhere(calendar, propertyName, value) {
            var kept = []
            var all = delegates(calendar, propertyName)
            for (var i = 0; i < all.length; i++) {
                if (all[i][propertyName] === value)
                    kept.push(all[i])
            }
            return kept
        }

        // An item's x/y are relative to its own parent, so "inside the card" has
        // to be asked in the card's coordinate space instead of mixing the two.
        function leftEdgeIn(card, item) {
            return item.mapToItem(card, 0, 0).x
        }

        function boxInsideCard(card, item) {
            var topLeft = item.mapToItem(card, 0, 0)
            var bottomRight = item.mapToItem(card, item.width, item.height)
            return topLeft.x >= -0.5 && topLeft.y >= -0.5
                    && bottomRight.x <= card.width + 0.5
                    && bottomRight.y <= card.height + 0.5
        }

        function test_cardStatesRemainPaintable() {
            var card = makeCard({
                title: "Network", summary: "Unavailable", status: "unavailable",
                available: false
            })
            verify(card.visible)
            compare(card.status, "unavailable")
            card.destroy()
        }

        function test_calendarMonthNavigation() {
            var calendar = makeCalendar({ viewYear: 2026, viewMonth: 11 })
            calendar.stepMonth(1)
            compare(calendar.viewYear, 2027)
            compare(calendar.viewMonth, 0)
            calendar.destroy()
        }

        function test_aCardPaintsASquareMajorSurface() {
            var card = makeCard({ title: "Network", summary: "Home", icon: CcLogic.iconFor("network") })
            verify(card.surfaceItem.visible)
            verify(card.surfaceItem.width > 0)
            verify(card.surfaceItem.height > 0)
            // Sharp language: a card is a major surface, so it is not rounded.
            compare(card.surfaceItem.radius, 0)
            compare(card.surfaceItem.color, Lazer.LazerTheme.settingsCard)
            card.destroy()
        }

        function test_everyNonReadyStateShowsACompactLabel() {
            var states = ["loading", "unavailable", "empty", "error"]
            for (var i = 0; i < states.length; i++) {
                var card = makeCard({
                    title: "Network", summary: "placeholder",
                    status: states[i], available: true, error: "adapter missing"
                })
                verify(card.stateLabel.length > 0, states[i] + " must carry a compact label")
                verify(card.stateBadgeItem.visible, states[i] + " label must be visible")
                compare(card.stateLabelItem.text, card.stateLabel)
                // A state label replaces the card's own status word, it does not
                // stack a second line under it.
                verify(card.stateLabel.length < 24, states[i] + " label must stay compact")
                card.destroy()
            }
        }

        function test_aReadyCardShowsNoStateLabel() {
            var card = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })
            compare(card.stateLabel, "")
            verify(!card.stateBadgeItem.visible)
            card.destroy()
        }

        // A state arriving is a fade, not a reflow: the badge's strip is reserved
        // for its widest word at all times, so the title's box cannot move with
        // state and no label can be measured into the badge.
        function test_aStateChangeFadesTheBadgeWithoutMovingTheTitle() {
            var card = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })
            tryVerify(function() { return card.titleItem.width > 0 }, 800)
            var readyWidth = card.titleItem.width
            var reserved = card.reservedBadgeWidth
            verify(reserved > 0, "the badge strip is reserved even when ready")
            verify(!card.stateBadgeItem.visible)

            card.status = "loading"
            // The animation starts from zero, so a hard cut would read 1 here.
            compare(card.stateBadgeItem.opacity, 0)
            compare(card.titleItem.width, readyWidth, "a state change must not reflow the title")
            compare(card.reservedBadgeWidth, reserved)
            tryVerify(function() { return card.stateBadgeItem.visible }, 800)
            tryVerify(function() { return card.stateBadgeItem.opacity > 0.99 }, 800)
            compare(card.titleItem.width, readyWidth)

            card.status = "ready"
            tryVerify(function() { return !card.stateBadgeItem.visible }, 800)
            compare(card.titleItem.width, readyWidth)
            card.destroy()
        }

        function test_anErrorCardShowsTheServiceWordsWithoutAModal() {
            var errorCard = makeCard({
                title: "Network", summary: "NetworkManager is not responding",
                status: "error", available: true,
                error: "NetworkManager is not responding"
            })
            var readyCard = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })

            // The service's own failure words are the status line, kept verbatim
            // for a detail page to read.
            compare(errorCard.summaryItem.text, errorCard.error)
            verify(errorCard.summaryItem.visible)

            // An error is a label, not a surface: the card's declared children
            // are identical to a ready card's, so nothing popped up on top.
            compare(errorCard.children.length, readyCard.children.length)
            compare(errorCard.stateBarItem.color, Lazer.LazerTheme.settingsWarning)

            errorCard.destroy()
            readyCard.destroy()
        }

        function test_cardLabelsStayInsideTheCardBounds() {
            var longText = "a summary long enough to need eliding on a deliberately narrow card"
            // The tightest case the card can be handed: a long title AND an icon
            // AND the widest state badge, all inside a card narrower than the sum
            // of what they would like. Every one of the three has to give.
            var card = makeCard({
                width: 180, height: 64, title: "Network adapter with a long name",
                summary: longText, icon: CcLogic.iconFor("network"),
                status: "unavailable", available: true
            })
            tryVerify(function() { return card.titleItem.width > 0 }, 800)

            verify(boxInsideCard(card, card.titleItem), "the title must stay inside the card")
            verify(boxInsideCard(card, card.summaryItem), "the summary must stay inside the card")
            verify(boxInsideCard(card, card.stateBadgeItem), "the state badge must stay inside the card")
            verify(boxInsideCard(card, card.iconItem), "the icon must stay inside the card")
            verify(card.titleItem.elide !== Text.ElideNone, "the title must elide")
            verify(card.summaryItem.elide !== Text.ElideNone, "the summary must elide")
            // The badge keeps its own width; the text column takes what is left,
            // so the two never claim the same strip of the title row. Read as two
            // real boxes, because a reservation that under-measures the painted
            // word lets the title reach into the badge while both still report
            // themselves in bounds.
            var titleRight = card.titleItem.mapToItem(card, card.titleItem.width, 0).x
            verify(titleRight <= card.stateBadgeItem.mapToItem(card, 0, 0).x + 0.5,
                "the title and the badge cannot both claim the same strip")
            // ...and the fixture is actually tight, so the assertion above is not
            // passing by accident. implicitWidth is the title's natural width:
            // a Text reports contentWidth AFTER eliding, so the elision itself
            // cannot be read back off contentWidth.
            verify(card.titleItem.implicitWidth > card.titleItem.width,
                "the long title must be elided, not silently shrunk")
            card.destroy()
        }

        // The badge paints uppercase, so the strip it reserves has to be measured
        // on the uppercase word. Reserving the mixed-case label under-reserves the
        // strip by roughly the cap height, which is exactly enough for the title
        // to reach past it on a narrow card.
        function test_theBadgeStripReservesThePaintedUppercaseLabel() {
            var states = ["loading", "unavailable", "empty", "error"]
            for (var i = 0; i < states.length; i++) {
                var card = makeCard({
                    title: "Network", status: states[i], available: true
                })
                compare(card.stateLabelItem.text, card.stateLabel.toUpperCase(),
                    states[i] + " paints an uppercase label")
                var painted = card.stateBarItem.width + card.badgeGap
                        + card.stateLabelItem.width
                verify(painted <= card.reservedBadgeWidth + 0.5,
                    states[i] + " badge must fit inside its reserved strip")
                card.destroy()
            }

            // And the reservation is the widest of all of them, not the current
            // one: the label can change without the strip moving.
            var widestCard = makeCard({ title: "Network", status: "unavailable", available: true })
            var reserved = widestCard.reservedBadgeWidth
            compare(widestCard.widestStateLabel, "UNAVAILABLE",
                "the widest painted label is UNAVAILABLE")
            compare(widestCard.stateLabel, "UNAVAILABLE")
            widestCard.status = "empty"
            compare(widestCard.reservedBadgeWidth, reserved,
                "a state change must not reflow the strip")
            verify(widestCard.stateLabelItem.width
                    <= widestCard.reservedBadgeWidth - widestCard.badgeBarWidth
                    - widestCard.badgeGap + 0.5)
            widestCard.destroy()
        }

        function test_cardActivationEmitsAndFlashes() {
            var card = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })
            card.activated.connect(function() { activationProbe.count++ })
            tryVerify(function() { return card.surfaceItem.width > 0 }, 800)

            mouseClick(card, card.width / 2, card.height / 2)
            tryCompare(activationProbe, "count", 1, 500)

            // The click flash is the shared recipe, not a second one.
            verify(card.flashActive)
            compare(card.flashOverlayItem.enabled, false)
            compare(card.flashAnimationItem.property, "opacity")
            compare(card.flashAnimationItem.from, Lazer.MotionTokens.clickFlashOpacity)
            compare(card.flashAnimationItem.to, 0)
            compare(card.flashAnimationItem.duration, Lazer.MotionTokens.clickFlashDuration)
            compare(card.flashAnimationItem.easing.type, Lazer.MotionTokens.clickFlashEasing)

            // Reduced motion lands on the final state instead of playing it.
            card.flashAnimationItem.stop()
            card.flashOverlayItem.opacity = 0
            Lazer.MotionTokens.reducedMotionOverride = true
            mouseClick(card, card.width / 2, card.height / 2)
            tryCompare(activationProbe, "count", 2, 500)
            verify(!card.flashActive)
            compare(card.flashOverlayItem.opacity, 0)
            Lazer.MotionTokens.reducedMotionOverride = false
            card.destroy()
        }

        // One non-ready state at a time, each on a card whose service EXISTS, so
        // every assertion below is about readiness and not about availability.
        function expectNonReadyAvailableCardToBeInert(status) {
            var card = makeCard({
                title: "Network", summary: "Not connected",
                icon: CcLogic.iconFor("network"),
                status: status, available: true, error: "adapter missing"
            })
            card.activated.connect(function() { activationProbe.count++ })
            tryVerify(function() { return card.surfaceItem.width > 0 }, 800)

            // Paintable, and at full contrast: dimming is for a service that is
            // not there, not for a card whose label is the thing to read.
            verify(card.visible, status + " must stay visible")
            compare(card.opacity, 1, status + " must stay readable")
            verify(card.stateLabel.length > 0, status + " must keep its compact label")

            compare(card.interactive, false, status + " must not accept input")
            compare(card.activeFocusOnTab, false, status + " must not take focus")
            // ...and a host that forces focus onto it anyway still gets no ring:
            // the ring belongs to a card that accepts input, not to one that
            // merely happens to hold focus.
            card.forceActiveFocus()
            verify(!card.ringVisible, status + " must not draw a ring when focused")

            // Hover: a synthetic move over the card changes nothing.
            mouseMove(card, card.width / 2, card.height / 2)
            verify(!card.hoverHighlighted, status + " must not highlight on hover")
            compare(card.surfaceItem.color, Lazer.LazerTheme.settingsCard,
                status + " must not swap to the hover surface")
            compare(card.highlightItem.border.width, 0, status + " must not draw a ring")
            compare(card.highlightItem.enabled, false, "the ring layer never takes input")

            // Click: no activation request, and none of the shared click feedback.
            mouseClick(card, card.width / 2, card.height / 2)
            compare(activationProbe.count, 0, status + " must not activate")
            verify(!card.flashActive, status + " must not flash")
            compare(card.flashOverlayItem.opacity, 0, status + " must not wash")

            // The programmatic path is the same gate as the pointer path.
            card.activate()
            compare(activationProbe.count, 0, status + " must ignore a direct activate()")
            card.destroy()
        }

        // Availability is not readiness. A loading, empty or failed card is a
        // report, not a target, so it stays on screen and stays legible while
        // accepting nothing - and ControlCenterLogic agrees, since actionFor()
        // answers "none" for every non-ready status.
        function test_aNonReadyButAvailableCardStaysPaintableYetInert() {
            var states = ["loading", "unavailable", "empty", "error"]
            for (var i = 0; i < states.length; i++)
                expectNonReadyAvailableCardToBeInert(states[i])
        }

        // The control half of the hover assertions above: the same synthetic move
        // over a ready card DOES light up. Without this, "no hover on an inert
        // card" would also pass if the harness could not drive hover at all.
        function test_theSameHoverStillReachesAReadyCard() {
            var card = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })
            tryVerify(function() { return card.surfaceItem.width > 0 }, 800)
            mouseMove(card, card.width / 2, card.height / 2)
            tryVerify(function() { return card.hoverHighlighted }, 500)
            tryCompare(card.surfaceItem, "color", Lazer.LazerTheme.settingsCardHover, 500)
            // Read through JS, not through tryCompare("border.width"): the Qt 6.11
            // test helpers cannot resolve a grouped property path, so that form
            // fails on a value that is already correct.
            tryVerify(function() { return card.highlightItem.border.width === 1.5 }, 500)
            card.destroy()
        }

        function test_anUnavailableCardStaysVisibleButInert() {
            var card = makeCard({
                title: "Network", summary: "Unavailable",
                status: "unavailable", available: false
            })
            card.activated.connect(function() { activationProbe.count++ })
            verify(card.visible)
            compare(card.interactive, false)
            compare(card.activeFocusOnTab, false)
            tryVerify(function() { return card.surfaceItem.width > 0 }, 800)

            mouseClick(card, card.width / 2, card.height / 2)
            compare(activationProbe.count, 0, "an unavailable card must not activate")

            // It dims through the shared disabled token rather than vanishing or
            // hard-cutting, so the transition is observable.
            tryCompare(card, "opacity", Lazer.LazerTheme.settingsDisabledAlpha, 800)
            verify(card.visible)
            card.destroy()
        }

        function test_aReadyCardKeepsFullOpacity() {
            var card = makeCard({ title: "Network", summary: "Home", status: "ready", available: true })
            compare(card.opacity, 1)
            verify(card.interactive)
            compare(card.activeFocusOnTab, true)
            card.destroy()
        }

        function test_cardIconResolvesTheLogicIconPaths() {
            for (var i = 0; i < CcLogic.cardKinds.length; i++) {
                var kind = CcLogic.cardKinds[i]
                var iconPath = CcLogic.iconFor(kind)
                verify(iconPath.length > 0, kind + " must name an icon")
                var card = makeCard({
                    title: CcLogic.cardTitles[kind], summary: "ready", icon: iconPath
                })
                verify(card.iconItem.visible, kind + " icon must be shown")
                // The path is relative to the card's own directory, so this is
                // the check that a wrong base directory cannot ship: a broken
                // path reports Image.Error rather than a silently blank icon.
                tryCompare(card.iconItem, "status", Image.Ready, 2000)
                compare(String(card.iconItem.source), iconPath)
                card.destroy()
            }
        }

        function test_theTextColumnFollowsTheIconSlot() {
            var withIcon = makeCard({ title: "Network", summary: "Home", icon: CcLogic.iconFor("network") })
            var withoutIcon = makeCard({ title: "Media", summary: "No media", icon: "" })
            verify(withIcon.iconItem.visible)
            verify(!withoutIcon.iconItem.visible)
            tryVerify(function() { return withIcon.titleItem.width > 0 }, 800)

            // Without an icon the text column starts at the surface padding
            // instead of beside a reserved hole, and the two cases are pinned
            // to the shared padding and icon metrics.
            compare(leftEdgeIn(withoutIcon, withoutIcon.titleItem), 12)
            compare(leftEdgeIn(withIcon, withIcon.titleItem), 12 + withIcon.iconSize + withIcon.iconGap)
            withIcon.destroy()
            withoutIcon.destroy()
        }

        // Pagination is asserted through the buttons a user actually presses, not
        // by calling stepMonth(): the arithmetic was already covered above, so what
        // is under test here is the wiring from a click to that arithmetic.
        function test_theStepButtonsPageTheMonthOnAClick() {
            var calendar = makeCalendar({ viewYear: 2026, viewMonth: 11 })
            tryVerify(function() { return calendarSettled(calendar) }, 1000)

            mouseClick(calendar.nextButtonItem, calendar.nextButtonItem.width / 2,
                       calendar.nextButtonItem.height / 2)
            tryCompare(calendar, "viewYear", 2027, 800)
            tryCompare(calendar, "viewMonth", 0, 800)
            // The header followed, and so did the grid's own set of dates.
            compare(calendar.monthLabelText, Calendar.monthLabel(2027, 0))
            tryVerify(function() {
                return delegatesWhere(calendar, "inMonth", true).length
                        === Calendar.daysInMonth(2027, 0)
            }, 800)

            // Back again, so a click is a page rather than a one-way latch.
            mouseClick(calendar.previousButtonItem, calendar.previousButtonItem.width / 2,
                       calendar.previousButtonItem.height / 2)
            tryCompare(calendar, "viewYear", 2026, 800)
            tryCompare(calendar, "viewMonth", 11, 800)
            compare(calendar.monthLabelText, Calendar.monthLabel(2026, 11))
            tryVerify(function() {
                return delegatesWhere(calendar, "inMonth", true).length
                        === Calendar.daysInMonth(2026, 11)
            }, 800)
            calendar.destroy()
        }

        // The keyboard half: Return and Space on a focused step button are the
        // actions the component declares, and an unhandled key must do nothing.
        function test_theStepButtonsPageTheMonthOnTheKeyboard() {
            var calendar = makeCalendar({ viewYear: 2026, viewMonth: 11 })
            tryVerify(function() { return calendarSettled(calendar) }, 1000)

            // Focused the way Tab would, since tab order is the host's business.
            calendar.nextButtonItem.forceActiveFocus()
            verify(calendar.nextButtonItem.activeFocus)
            keyPress(Qt.Key_Return)
            keyRelease(Qt.Key_Return)
            tryCompare(calendar, "viewYear", 2027, 800)
            tryCompare(calendar, "viewMonth", 0, 800)

            keyPress(Qt.Key_Space)
            keyRelease(Qt.Key_Space)
            tryCompare(calendar, "viewMonth", 1, 800)

            calendar.previousButtonItem.forceActiveFocus()
            verify(calendar.previousButtonItem.activeFocus)
            keyPress(Qt.Key_Return)
            keyRelease(Qt.Key_Return)
            tryCompare(calendar, "viewMonth", 0, 800)

            // The handler is a whitelist of activation keys, not "any key".
            keyPress(Qt.Key_Left)
            keyRelease(Qt.Key_Left)
            compare(calendar.viewMonth, 0, "an unrelated key must not page the calendar")
            compare(calendar.viewYear, 2027)
            calendar.destroy()
        }

        function test_calendarGridIsFixedAtSixRowsForEveryMonth() {
            var february = makeCalendar({ viewYear: 2026, viewMonth: 1 })
            compare(february.rowCount, 6)
            compare(february.columnCount, 7)
            compare(february.cellCount, 42)
            compare(delegates(february, "dayOffset").length, 42)
            compare(delegatesWhere(february, "inMonth", true).length, Calendar.daysInMonth(2026, 1))
            // A fixed grid means a fixed footprint: width and height follow the
            // implicit sizes, so the panel hosting it cannot resize as the user
            // pages. (Asserted here because it is the component's own default,
            // not something a test can force by assigning.)
            compare(february.height, february.implicitHeight)
            compare(february.width, february.implicitWidth)

            // A 31-day month must occupy the same six rows and the same height.
            february.stepMonth(1)
            compare(february.viewMonth, 2)
            compare(delegatesWhere(february, "inMonth", true).length, Calendar.daysInMonth(2026, 2))

            var january = makeCalendar({ viewYear: 2026, viewMonth: 0 })
            compare(delegatesWhere(january, "inMonth", true).length, Calendar.daysInMonth(2026, 0))
            compare(january.implicitHeight, february.implicitHeight,
                "a fixed six-row grid must not change the calendar's height")
            january.destroy()
            february.destroy()
        }

        function test_calendarSteppingWrapsBothWays() {
            var calendar = makeCalendar({ viewYear: 2026, viewMonth: 0 })
            calendar.stepMonth(-1)
            compare(calendar.viewYear, 2025)
            compare(calendar.viewMonth, 11)
            calendar.stepMonth(2)
            compare(calendar.viewYear, 2026)
            compare(calendar.viewMonth, 1)
            // The label is the bar module's own wording, not a second formatter.
            compare(calendar.monthLabelText, Calendar.monthLabel(2026, 1))
            calendar.destroy()
        }

        function test_calendarUsesTheSundayFirstWeekdayConvention() {
            var calendar = makeCalendar({ viewYear: 2026, viewMonth: 11 })
            compare(calendar.weekdayLabels.length, 7)
            compare(calendar.weekdayLabels[0], "\u65E5")
            compare(calendar.weekdayLabels[6], "\u516D")

            // December 2026 starts on a Tuesday, so a Sunday-first strip puts the
            // 1st in the third column.
            compare(Calendar.firstWeekday(2026, 11), 2)
            var inMonth = delegatesWhere(calendar, "inMonth", true)
            compare(inMonth.length, Calendar.daysInMonth(2026, 11))
            var firstCell = inMonth[0]
            compare(firstCell.dayOffset, 1)
            compare(firstCell.cellIndex, Calendar.firstWeekday(2026, 11))
            // The two cells before it belong to November, and stay unpainted.
            compare(delegates(calendar, "dayOffset")[0].cellIndex, 0)
            compare(delegates(calendar, "dayOffset")[1].cellIndex, 1)
            calendar.destroy()
        }

        function test_calendarHighlightsExactlyTheTodayCell() {
            var calendar = makeCalendar({
                today: new Date(2026, 10, 12), viewYear: 2026, viewMonth: 10
            })
            var todayCells = delegatesWhere(calendar, "isToday", true)
            compare(todayCells.length, 1)
            compare(todayCells[0].dayOffset, 12)
            compare(todayCells[0].color, Lazer.LazerTheme.activeFill)
            verify(todayCells[0].border.width > 0)

            // Stepping away from the current month drops the highlight, and
            // stepping back restores the same cell.
            calendar.stepMonth(1)
            compare(delegatesWhere(calendar, "isToday", true).length, 0)
            calendar.stepMonth(-1)
            var restored = delegatesWhere(calendar, "isToday", true)
            compare(restored.length, 1)
            compare(restored[0].dayOffset, 12)
            calendar.destroy()
        }

        function test_calendarResetViewReturnsToToday() {
            var calendar = makeCalendar({
                today: new Date(2026, 0, 5), viewYear: 2030, viewMonth: 7
            })
            compare(calendar.viewingCurrentMonth, false)
            compare(calendar.monthLabelItem.color, Lazer.LazerTheme.settingsAccent)

            calendar.stepMonth(1)
            calendar.resetView()
            compare(calendar.viewYear, 2026)
            compare(calendar.viewMonth, 0)
            compare(calendar.viewingCurrentMonth, true)
            // The accent handoff is a real transition, so it lands a frame later.
            tryCompare(calendar.monthLabelItem, "color", Lazer.LazerTheme.textPrimary, 800)
            calendar.destroy()
        }

        function readRepoFile(relativePath) {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", Qt.resolvedUrl("../../" + relativePath), false)
            xhr.send(null)
            return { status: xhr.status, text: xhr.responseText }
        }

        // One named QML block, by brace counting from the line that declares its
        // id to the line that closes it. A regex cannot do this: the block nests
        // Items and Rectangles, so "\n    }" lands on an inner close and the
        // slice runs on into the rest of the file - which is how a battery block
        // "with no handlers" ends up reporting the weather block's HoverHandler.
        function blockNamed(text, idName) {
            var lines = text.split("\n")
            var start = -1
            var indent = 0
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].match(new RegExp("^\\s*id:\\s*" + idName + "\\s*$"))) {
                    start = i
                    indent = lines[i].match(/^\s*/)[0].length
                    break
                }
            }
            if (start < 0)
                return ""
            var depth = 0
            var opened = false
            for (var j = start; j < lines.length; j++) {
                var stripped = lines[j].replace(/"[^"]*"/g, '""')
                for (var k = 0; k < stripped.length; k++) {
                    if (stripped[k] === "{") {
                        depth++
                        opened = true
                    } else if (stripped[k] === "}") {
                        depth--
                    }
                }
                if (opened && depth === 0)
                    return lines.slice(start, j + 1).join("\n")
            }
            return ""
        }

        // The month grid must render the bar module's math, not a second copy of
        // it. No runtime assertion can see a forked helper - a private
        // daysInMonth() would satisfy every behavioural check above while
        // drifting the moment the bar module changes - so the source is read
        // directly. Needs QML_XHR_ALLOW_FILE_READ=1, which scripts/qmltest.sh
        // sets.
        function test_theCalendarRendersTheBarDateMathInsteadOfForkingIt() {
            var file = readRepoFile("modules/lazerbar/ControlCenterCalendar.qml")
            compare(file.status, 200, "the calendar source must be readable")
            verify(file.text.indexOf("ClockCalendar.js") >= 0,
                "the calendar must import the shared date module")

            var forked = file.text.match(/function\s+(daysInMonth|firstWeekday|cellDayOffset|cellInMonth|isTodayCell|monthLabel)\s*\(/)
            compare(forked, null, "the calendar must not redeclare " + (forked ? forked[1] : ""))

            // stepMonth is the component's own stepping API, so it exists - but its
            // first statement has to hand the arithmetic to the shared module,
            // which is what rules out a local reimplementation that happens to
            // agree on the months a test happens to visit.
            var forward = file.text.match(/function\s+stepMonth\s*\([^)]*\)\s*\{\s*([^\n]*)/)
            verify(forward !== null, "stepMonth must be declared")
            verify(forward[1].indexOf("Calendar.stepMonth") >= 0,
                "stepMonth must delegate to Calendar.stepMonth")
        }

        function test_calendarStepButtonsAreSquareGeometricArrows() {
            var calendar = makeCalendar({})
            tryVerify(function() { return calendar.previousButtonItem.width > 0 }, 800)

            compare(calendar.previousButtonItem.width, calendar.previousButtonItem.height)
            compare(calendar.nextButtonItem.width, calendar.nextButtonItem.height)
            compare(calendar.previousButtonItem.radius, 0)
            compare(calendar.nextButtonItem.radius, 0)
            verify(calendar.previousButtonItem.activeFocusOnTab)
            verify(calendar.nextButtonItem.activeFocusOnTab)

            verify(String(calendar.previousButtonItem.glyphItem.source).indexOf("chevron-left.svg") >= 0)
            verify(String(calendar.nextButtonItem.glyphItem.source).indexOf("chevron-right.svg") >= 0)
            tryCompare(calendar.previousButtonItem.glyphItem, "status", Image.Ready, 2000)
            tryCompare(calendar.nextButtonItem.glyphItem, "status", Image.Ready, 2000)
            calendar.destroy()
        }

        // --- Bounded notification summary ---

        function makeNotifications(properties) {
            var args = { x: 0, y: 0, width: 320 }
            for (var key in (properties || {}))
                args[key] = properties[key]
            return notificationsComponent.createObject(root.testHost, args)
        }

        function test_theNotificationSummaryIsCappedAtTwoEntries() {
            var service = seedNotifications(makeFake(fakeNotificationComponent), 5)
            var summary = makeNotifications({ notificationService: service })
            tryCompare(summary, "entryCount", 2, 1000)
            // Two, because maxEntries is the module's fixed cap - a five-entry
            // history must not make the panel taller or the summary longer.
            compare(summary.maxEntries, 2)
            compare(summary.maxEntries, CcLogic.notificationEntryCap)
            // The unread count is reported whole and separately, so capping the
            // entries never hides how many are waiting.
            compare(summary.unreadCount, 5)
            compare(summary.entries[0].notifId, "n5")
            compare(summary.entries[1].notifId, "n4")
        }

        // The walk is bounded, not just the result. A summary that read a 120-entry
        // history and then dropped 118 entries would render identically to one
        // that read two, so the cap on the RESULT proves nothing about the cap on
        // the WORK: this fake counts its own get() calls and the bound is asserted
        // on that count.
        function test_theSummaryWalksNoMoreOfTheHistoryThanItRenders() {
            var rows = []
            for (var i = 0; i < 120; i++)
                rows.push({ notifId: "n" + i, appName: "App", summary: "Message " + i })

            var counted = makeFake(countingHistoryComponent, { rows: rows, noLatest: true })
            var countedService = makeFake(fakeCountingNotificationComponent, {
                historyList: counted, unreadCount: 120
            })
            var summary = makeNotifications({ notificationService: countedService })
            tryCompare(summary, "entryCount", 2, 1000)
            // latestNotification() is absent here, so every read came from the
            // bounded walk: exactly one read per rendered entry, and no more.
            compare(counted.readCount(), 2,
                "a 120-entry history must be read no further than the cap, read "
                    + counted.readCount() + " rows")

            // And with latestNotification() present the walk is at most the cap
            // MINUS the entry that helper already supplied.
            var bothRows = []
            for (var j = 0; j < 120; j++)
                bothRows.push({ notifId: "m" + j, appName: "App", summary: "S" + j })
            countingHead.value = bothRows[0]
            var bothCounted = makeFake(countingHistoryComponent, { rows: bothRows })
            var bothService = makeFake(fakeCountingNotificationComponent, {
                historyList: bothCounted, unreadCount: 120
            })
            var withLatest = makeNotifications({ notificationService: bothService })
            tryCompare(withLatest, "entryCount", 2, 1000)
            // Exactly two: index 0 (which is the head the helper already supplied,
            // so it has to be read to know it is a duplicate and skipped) and
            // index 1 (which is kept). A walk that does not stop at the cap would
            // read 120.
            compare(bothCounted.readCount(), 2,
                "the helper supplies one entry, so the walk reads the duplicate and "
                    + "one more (read " + bothCounted.readCount() + ")")
        }

        function test_theNotificationSummaryHeightIsBoundedByTheCapNotTheContent() {
            var empty = makeNotifications({})
            var two = makeNotifications({ notificationService: seedNotifications(
                makeFake(fakeNotificationComponent), 2) })
            var many = makeNotifications({ notificationService: seedNotifications(
                makeFake(fakeNotificationComponent), 9) })
            tryCompare(two, "entryCount", 2, 1000)
            tryCompare(many, "entryCount", 2, 1000)
            compare(two.implicitHeight, many.implicitHeight,
                "nine notifications must not make the panel taller than two")
            compare(empty.implicitHeight, many.implicitHeight,
                "an empty history must not collapse the panel either")
        }

        // The read path prefers latestNotification() and falls back to a bounded
        // historyList loop, deduplicating the overlap between the two. No
        // unbounded walk of the history is allowed.
        function test_theSummaryPrefersTheLatestEntryAndDeduplicatesTheHistory() {
            var service = seedNotifications(makeFake(fakeNotificationComponent), 3)
            var summary = makeNotifications({ notificationService: service })
            tryCompare(summary, "entryCount", 2, 1000)
            compare(summary.entries.length, 2)
            var ids = []
            for (var i = 0; i < summary.entries.length; i++)
                ids.push(String(summary.entries[i].notifId))
            compare(ids.join(","), "n3,n2",
                "latestNotification() is historyList.get(0), so it must not double up")

            // A service with no latestNotification() at all still renders its
            // bounded history slice through the same cap.
            var noLatest = seedNotifications(makeFake(fakeNotificationComponent), 4)
            var bareService = makeFake(fakeHistoryOnlyNotificationComponent, {
                historyList: noLatest.historyList, unreadCount: noLatest.unreadCount
            })
            var bare = makeNotifications({ notificationService: bareService })
            tryCompare(bare, "entryCount", 2, 1000)
            compare(bare.entries[0].notifId, "n4")
            compare(bare.unreadCount, 4)
        }

        // Opening the summary is a request for the full view; it is emphatically
        // not a decision to clear the user's unread notifications.
        function test_openingTheSummaryNeverMarksAnythingRead() {
            var service = seedNotifications(makeFake(fakeNotificationComponent), 3)
            var summary = makeNotifications({ notificationService: service })
            var requests = 0
            summary.openRequested.connect(function() { requests++ })
            tryVerify(function() { return summary.viewAllItem.width > 0 }, 1000)

            compare(service.markAllCalls, 0, "construction must not touch read state")
            mouseClick(summary.viewAllItem, summary.viewAllItem.width / 2,
                       summary.viewAllItem.height / 2)
            tryVerify(function() { return requests === 1 }, 800)
            compare(service.markAllCalls, 0, "opening must not call markAllRead()")
            compare(service.markReadCalls, 0, "opening must not call markRead()")
            compare(service.unreadCount, 3, "the unread count is unchanged by opening")
        }

        function test_anEmptyHistoryOffersNoViewAllAction() {
            var service = makeFake(fakeNotificationComponent)
            var summary = makeNotifications({ notificationService: service })
            tryVerify(function() { return summary.entryCount === 0 }, 1000)
            compare(summary.viewAllEnabled, false,
                "nothing to view means nothing to activate")
            var requests = 0
            summary.openRequested.connect(function() { requests++ })
            summary.viewAllItem.activate()
            compare(requests, 0)
            compare(summary.entries.length, 0)
        }

        // --- Overview: scope ---

        function test_theOverviewHasExactlyTheFourCoreControlCards() {
            var page = makePage({ networkService: makeFake(fakeNetworkComponent) })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)
            compare(page.controlCardCount, 4)
            compare(page.controlCardKinds.join(","), CcLogic.cardKinds.join(","))

            // Stated as an exact set: the four cards are the module's four, with
            // the module's own titles and icons. There is no fifth control and
            // no brightness / DND / power card anywhere in the column.
            var titles = []
            var icons = []
            for (var i = 0; i < page.controlCards.length; i++) {
                titles.push(page.controlCards[i].title)
                icons.push(page.controlCards[i].icon)
            }
            compare(titles.join(","), "Network,Bluetooth,Volume,Media")
            compare(icons.join(","), CcLogic.cardIcons.network + ","
                    + CcLogic.cardIcons.bluetooth + ","
                    + CcLogic.cardIcons.volume + ","
                    + CcLogic.cardIcons.media)
            for (var j = 0; j < icons.length; j++)
                verify(icons[j].indexOf("brightness") < 0,
                    "no brightness asset may reach a control card")
        }

        // Battery is a read-only header state, not a control. The page publishes
        // no battery card, and the header block declares no input handler at
        // all - asserted on the source, because "there is no click" cannot be
        // observed by clicking.
        function test_batteryIsHeaderStateAndNotAFifthControlCard() {
            var page = makePage({ batteryService: makeFake(fakeBatteryComponent) })
            tryVerify(function() { return page.batteryStateItem.width > 0 }, 1000)
            compare(page.controlCardCount, 4, "battery must not join the control column")
            compare(page.batteryCard, null, "there is no battery card")
            compare(page.controlCardKinds.indexOf("battery"), -1)
            verify(page.batteryStateItem.visible)
            compare(page.batteryTextItem.text, "87%",
                "the header reads the service's own percentage")
            compare(page.batteryStateItem.activeFocusOnTab, false,
                "read-only state does not take focus")

            var file = readRepoFile("modules/lazerbar/ControlCenter.qml")
            compare(file.status, 200, "the overview source must be readable")
            var block = blockNamed(file.text, "batteryState")
            verify(block !== "", "the battery header must be a named block")
            var handlers = block.match(/TapHandler|MouseArea|HoverHandler|DragHandler|Flickable/)
            compare(handlers, null,
                "the battery header declares no input handler (found "
                    + (handlers ? handlers[0] : "") + ")")
        }

        function test_batteryRendersEveryStateWithoutBlocking() {
            var states = [
                { available: false, ready: false, percentage: 0, iconText: "" },
                { available: true, ready: false, percentage: 0, iconText: "?" },
                { available: true, ready: true, percentage: 87, iconText: "BAT" },
                { available: true, ready: true, percentage: 12, iconText: "CHG",
                  charging: true, pluggedIn: true },
                { available: true, ready: true, percentage: 8, iconText: "AC",
                  pluggedIn: true }
            ]
            for (var i = 0; i < states.length; i++) {
                var page = makePage({ batteryService: makeFake(fakeBatteryComponent, states[i]) })
                tryVerify(function() { return page.batteryStateItem.width > 0 }, 1000)
                verify(page.batteryTextItem.text.length > 0,
                    "battery state " + i + " must render a readable value")
                verify(page.batteryStateItem.visible)
                compare(page.controlCardCount, 4)
            }
        }

        // --- Overview: card actions ---

        function test_networkAndBluetoothCardsRequestTheirDetailPages() {
            var networkRequests = 0
            var bluetoothRequests = 0
            var page = makePage({
                networkService: makeFake(fakeNetworkComponent),
                bluetoothService: makeFake(fakeBluetoothComponent)
            })
            page.networkDetailsRequested.connect(function() { networkRequests++ })
            page.bluetoothDetailsRequested.connect(function() { bluetoothRequests++ })
            tryVerify(function() { return page.networkCard.width > 0 }, 1000)

            // The programmatic path first, because that is what the host will
            // use; then a real click, because that is what the user does.
            page.networkCard.activate()
            tryVerify(function() { return networkRequests === 1 }, 800)
            page.bluetoothCard.activate()
            tryVerify(function() { return bluetoothRequests === 1 }, 800)

            // ...and the request is gated on the module's action, not merely on the
            // card having been clicked. openNetworkDetails() is a public function a
            // host could call directly, and a card with no action must answer no.
            page.openNetworkDetails()
            page.openBluetoothDetails()
            tryVerify(function() {
                return networkRequests === 2 && bluetoothRequests === 2
            }, 300)
            compare(networkRequests, 2, "a host may call the request directly on a ready card")
            compare(bluetoothRequests, 2)

            mouseClick(page.networkCard, page.networkCard.width / 2, page.networkCard.height / 2)
            tryVerify(function() { return networkRequests === 3 }, 800)
            mouseClick(page.bluetoothCard, page.bluetoothCard.width / 2,
                       page.bluetoothCard.height / 2)
            tryVerify(function() { return bluetoothRequests === 3 }, 800)

            // The control half: a card whose service failed is inert, so it
            // neither flashes nor requests a detail page.
            var failing = makeFake(fakeNetworkComponent, {
                lastError: "NetworkManager is not responding" })
            var inert = makePage({ networkService: failing })
            var inertRequests = 0
            inert.networkDetailsRequested.connect(function() { inertRequests++ })
            tryVerify(function() { return inert.networkCard.width > 0 }, 1000)
            mouseClick(inert.networkCard, inert.networkCard.width / 2,
                       inert.networkCard.height / 2)
            compare(inertRequests, 0, "a failed adapter has no detail page to open")
            verify(!inert.networkCard.flashActive,
                "a card with no action must not play the click flash either")

            // ...and the direct call is gated too, which is the half a click cannot
            // reach: an inert card's TapHandler never fires, so only calling the
            // function outright could emit here.
            inert.openNetworkDetails()
            compare(inertRequests, 0,
                "the request must follow the module's action, not just the click")
        }

        function test_volumeControlsCallTheInjectedService() {
            var volume = makeFake(fakeVolumeComponent)
            var page = makePage({ volumeService: volume })
            tryVerify(function() { return page.volumeSliderItem.width > 0 }, 1000)

            // The slider is bound to the service in both directions.
            compare(page.volumeSliderItem.value, volume.sinkVolume)
            compare(page.volumeSliderItem.from, 0)
            compare(page.volumeSliderItem.to, 1)

            page.volumeSliderItem.setValue(0.8)
            tryCompare(volume, "setCalls", 1, 800)
            compare(volume.sinkVolume, 0.8, "the service owns the value")

            // The page's own guard on the value it sends: setVolume() is public and
            // a host (or a slider whose from/to were retuned) could hand it
            // anything, so an out-of-range request is clamped rather than passed
            // straight to PipeWire. The slider itself already normalises, which is
            // exactly why this needs its own test - the slider agreeing is not the
            // page agreeing.
            page.setVolume(2.5)
            tryCompare(volume, "setCalls", 2, 800)
            compare(volume.sinkVolume, 1, "a value above the range clamps to its top")
            page.setVolume(-1)
            tryCompare(volume, "setCalls", 3, 800)
            compare(volume.sinkVolume, 0, "a value below the range clamps to its bottom")
            page.setVolume(Number.NaN)
            tryCompare(volume, "setCalls", 4, 800)
            compare(volume.sinkVolume, 0, "an unusable value clamps rather than reaching the service")

            // The mute button is the second action on the same card.
            compare(volume.sinkMuted, false)
            mouseClick(page.muteButtonItem, page.muteButtonItem.width / 2,
                       page.muteButtonItem.height / 2)
            tryCompare(volume, "muteCalls", 1, 800)
            compare(volume.sinkMuted, true)
            // ...and the card's own summary follows the service, so the two reads
            // can never disagree.
            tryCompare(page.volumeCard, "summary", "Muted", 800)

            // Mute again through the button, and once through the card body. The
            // explicit wait between them matters: a mute button tap claims itself
            // until the next event-loop turn, and tryCompare on an
            // already-satisfied value returns without spinning the loop - so the
            // card's own activation immediately after would still be inside the
            // claim window.
            page.muteButtonItem.activate()
            tryCompare(volume, "muteCalls", 2, 800)
            wait(50)
            page.volumeCard.activate()
            tryCompare(volume, "muteCalls", 3, 800)
        }

        // A track tap or scrub is the slider's, not the card's. Qt delivers the
        // deepest handler first and still delivers to the ancestor, so the card
        // has to be told which control took the tap - otherwise dragging the
        // volume would also toggle mute.
        function test_aSliderTapDoesNotAlsoToggleTheCard() {
            var volume = makeFake(fakeVolumeComponent)
            var page = makePage({ volumeService: volume })
            tryVerify(function() { return page.volumeSliderItem.width > 0 }, 1000)

            mouseClick(page.volumeSliderItem, page.volumeSliderItem.width * 0.75,
                       page.volumeSliderItem.height / 2)
            tryVerify(function() { return volume.setCalls >= 1 }, 800)
            compare(volume.muteCalls, 0,
                "a tap on the slider must not reach the card's mute action (setCalls="
                    + volume.setCalls + ", muteCalls=" + volume.muteCalls + ")")

            // The control half: the same click on the card's own dead space
            // still toggles, so the guard is not simply a disabled card. The
            // explicit wait matters: the tap claim is released on the next
            // event-loop turn, and a satisfied tryCompare returns without
            // spinning the loop.
            wait(50)
            page.volumeCard.activate()
            tryVerify(function() { return volume.muteCalls === 1 }, 800)
        }

        function test_mediaTransportCallsTheInjectedService() {
            var media = makeFake(fakeMediaComponent)
            var page = makePage({ mediaService: media })
            tryVerify(function() { return page.mediaPlayPauseButtonItem.width > 0 }, 1000)

            // The card's own line is the service's words, not a second formatter.
            compare(page.mediaCard.summary, "IOSYS — Blue Bird")
            verify(String(page.mediaPlayPauseButtonItem.glyphItem.source)
                .indexOf("pause.svg") >= 0, "a playing card shows the pause glyph")
            verify(String(page.mediaPreviousButtonItem.glyphItem.source)
                .indexOf("previous.svg") >= 0)
            verify(String(page.mediaNextButtonItem.glyphItem.source)
                .indexOf("next.svg") >= 0)

            page.mediaPreviousButtonItem.activate()
            tryCompare(media, "previousCalls", 1, 800)
            wait(50)
            page.mediaPlayPauseButtonItem.activate()
            tryCompare(media, "playPauseCalls", 1, 800)
            wait(50)
            page.mediaNextButtonItem.activate()
            tryCompare(media, "nextCalls", 1, 800)

            // Transport capability is the service's, not the page's: a player
            // that cannot go next has an inert button, and its programmatic
            // activation is ignored exactly like the pointer one.
            var bare = makeFake(fakeMediaComponent, {
                canGoPrevious: false, canTogglePlayback: false, canGoNext: false
            })
            var barePage = makePage({ mediaService: bare })
            tryVerify(function() { return barePage.mediaNextButtonItem.width > 0 }, 1000)
            compare(barePage.mediaPreviousButtonItem.enabled, false)
            compare(barePage.mediaPlayPauseButtonItem.enabled, false)
            compare(barePage.mediaNextButtonItem.enabled, false)
            compare(barePage.mediaPreviousButtonItem.activeFocusOnTab, false)
            barePage.mediaNextButtonItem.activate()
            compare(bare.nextCalls, 0, "a transport the player cannot do must stay inert")
            barePage.mediaCard.activate()
            compare(bare.playPauseCalls, 0,
                "the card body must not toggle playback the player cannot toggle")
        }

        // Same rule as the volume card: the card body is playback, the embedded
        // buttons are the specific transport, and one click does one thing.
        //
        // Driven by a real click on the button, not by calling activate(). Qt
        // delivers a tap to the deepest handler and then still delivers it to
        // every ancestor, so a real click is the only thing that exercises the
        // arbitration - the programmatic path never goes through the handlers at
        // all, and a test written that way passes whether the arbitration exists
        // or not.
        function test_aTransportClickDoesNotAlsoTogglePlaybackOnTheCard() {
            var media = makeFake(fakeMediaComponent)
            var page = makePage({ mediaService: media })
            tryVerify(function() { return page.mediaNextButtonItem.width > 0 }, 1000)
            var button = page.mediaNextButtonItem

            mouseClick(button, button.width / 2, button.height / 2)
            tryVerify(function() { return media.nextCalls >= 1 }, 800)
            compare(media.playPauseCalls, 0,
                "one click must not also toggle playback (nextCalls=" + media.nextCalls
                    + ", playPauseCalls=" + media.playPauseCalls + ")")

            // The control half: the card's own body still toggles, so the guard is
            // an arbitration and not a disabled card.
            wait(50)
            page.mediaCard.activate()
            tryCompare(media, "playPauseCalls", 1, 800)
        }

        // --- Overview: unavailable / absent optional services ---

        function test_theOverviewRendersWithUnavailableServices() {
            var page = makePage({
                networkService: makeFake(fakeNetworkComponent, { wifiEnabled: false,
                    wifiConnected: false, activeSsid: "" }),
                bluetoothService: makeFake(fakeBluetoothComponent, {
                    bluetoothAvailable: false, devices: null, connectedDevices: null }),
                volumeService: makeFake(fakeVolumeComponent, { sinkVolume: 0 }),
                mediaService: makeFake(fakeMediaComponent, { hasPlayer: false,
                    title: "", artist: "", playing: false }),
                batteryService: makeFake(fakeBatteryComponent, { available: false,
                    ready: false, percentage: 0, iconText: "" }),
                notificationService: seedNotifications(makeFake(fakeNotificationComponent), 0)
            })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)

            for (var i = 0; i < page.controlCards.length; i++) {
                var card = page.controlCards[i]
                verify(card.visible, "card " + i + " must stay painted")
                verify(card.summary.length > 0,
                    "card " + i + " must render a non-blocking status line")
            }
            compare(page.networkCard.status, "ready",
                "a disabled-but-present radio is a real state, not an empty list")
            compare(page.networkCard.summary, "Off")
            compare(page.bluetoothCard.status, "unavailable")
            compare(page.mediaCard.status, "empty")
            compare(page.mediaCard.summary, "No media")
            verify(page.batteryTextItem.text.length > 0)
        }

        // No service injected at all is the production state between this task
        // and the wiring task: the page must still mount and paint.
        function test_theOverviewRendersWithNoServiceInjectedAtAll() {
            var page = makePage({})
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)
            for (var i = 0; i < page.controlCards.length; i++) {
                var card = page.controlCards[i]
                compare(card.status, "unavailable", "card " + i + " reports an absent service")
                compare(card.available, false)
                verify(card.visible)
                verify(card.summary.length > 0)
                compare(card.interactive, false, "card " + i + " must accept nothing")
            }
            compare(page.entryCount, 0)
            verify(page.visible)
            verify(page.calendarItem.visible)
        }

        // A non-ready card stays inert, but it must stop announcing itself as a
        // button: a screen reader that is told "button" and then gets nothing is
        // worse than one told "Network, Not connected, Loading".
        function test_aNonReadyCardAnnouncesItsStateInsteadOfAPressedButton() {
            // A failed adapter is the non-ready case worth announcing: the card is
            // on screen, has no action, and its own words are the thing to read.
            var page = makePage({ networkService: makeFake(fakeNetworkComponent, {
                lastError: "NetworkManager is not responding" }) })
            // Both halves of the module's decision, pinned: the card frame's own
            // status, and the normalized action behind it.
            compare(page.networkCard.status, "error")
            compare(page.cardData("network").action, "none")
            var detailRequests = 0
            page.networkDetailsRequested.connect(function() { detailRequests++ })
            tryVerify(function() { return page.networkCard.width > 0 }, 1000)

            // Ready: a real target, announced as a button.
            var ready = makePage({ networkService: makeFake(fakeNetworkComponent) })
            tryVerify(function() { return ready.networkCard.width > 0 }, 1000)
            compare(ready.networkCard.Accessible.role, Accessible.Button)

            // Non-ready: same card, static text, and the state in the name.
            compare(page.networkCard.Accessible.role, Accessible.StaticText)
            verify(page.networkCard.Accessible.name.indexOf("Network") >= 0)
            verify(page.networkCard.Accessible.name.indexOf(page.networkCard.summary) >= 0,
                "the announcement must carry the status line the card shows")
            page.networkCard.activate()
            compare(detailRequests, 0, "inert stays inert - no activation was restored")
        }

        // --- Overview: header ---

        function test_theHeaderReadsTheInjectedClockWeatherAndBattery() {
            var page = makePage({
                now: new Date(2026, 9, 12, 9, 41),
                weatherService: makeFake(fakeWeatherComponent),
                batteryService: makeFake(fakeBatteryComponent)
            })
            tryVerify(function() { return page.clockTextItem.width > 0 }, 1000)
            verify(page.clockTextItem.text.indexOf("09:41") >= 0,
                "the header clock must follow the injected date")
            compare(page.weatherState, "ready")
            // Rounded for a header: 18.5 shows as 19, not as a fake precision the
            // reading does not have.
            compare(page.weatherTextItem.text, "19°")
            verify(page.weatherConditionItem.text.length > 0)
            compare(page.batteryTextItem.text, "87%")
        }

        function test_everyWeatherStateRendersWithoutBlocking() {
            var states = [
                { available: true, loading: true },
                { available: false },
                { available: true, temperature: 18.5, isStale: true },
                { available: true, temperature: 18.5, lastError: "HTTP 503" },
                { available: true, temperature: Number.NaN },
                { available: true, temperature: 18.5 }
            ]
            var expected = ["loading", "unavailable", "stale", "stale", "empty", "ready"]
            for (var i = 0; i < states.length; i++) {
                var page = makePage({ weatherService: makeFake(fakeWeatherComponent, states[i]) })
                tryVerify(function() { return page.clockTextItem.width > 0 }, 1000)
                compare(page.weatherState, expected[i],
                    "weather state " + i + " must come from the logic module")
                verify(page.weatherTextItem.text.length > 0,
                    "weather state " + i + " must still render a value")
                verify(page.visible)
                compare(page.controlCardCount, 4)
            }

            // A stale reading still SHOWS its temperature, dimmed by the condition
            // word beside it. This is the state a failed refresh produces - the
            // service keeps the last reading and reports lastError - so dropping
            // the value would blank the header every time a request failed, which
            // is precisely what the module's "stale" state exists to prevent.
            var stale = makePage({ weatherService: makeFake(fakeWeatherComponent, {
                available: true, temperature: 18.5, isStale: true }) })
            tryVerify(function() { return stale.clockTextItem.width > 0 }, 1000)
            compare(stale.weatherState, "stale")
            compare(stale.weatherTextItem.text, "19°",
                "a stale reading keeps its value")
            compare(stale.weatherConditionItem.text, "partly-cloudy")
            verify(stale.weatherTextItem.color !== Lazer.LazerTheme.textMuted,
                "the value stays legible; the condition word carries the dimming")

            // And the states with no reading render a placeholder instead of
            // inventing one: an empty or absent service must not show a number.
            var absent = makePage({})
            tryVerify(function() { return absent.clockTextItem.width > 0 }, 1000)
            compare(absent.weatherState, "unavailable")
            compare(absent.weatherTextItem.text, "—")
            compare(absent.weatherConditionItem.text, "Unavailable")
        }

        // --- Overview: layout ---

        function test_theLayoutModeFlipsAtTheLogicBreakpoint() {
            var narrow = makePage({ width: CcLogic.minimumTwoColumnWidth - 1 })
            var wide = makePage({ width: CcLogic.minimumTwoColumnWidth })
            tryVerify(function() { return narrow.layoutMode === "narrow"
                                    && wide.layoutMode === "wide" }, 1000)
            compare(narrow.layoutMode, "narrow")
            compare(wide.layoutMode, "wide")

            // ...and the breakpoint is the module's own, not a page-local number.
            // One pixel either side of it is enough to catch a hardcoded 760.
            compare(makePage({ width: CcLogic.minimumTwoColumnWidth - 2 }).layoutMode,
                "narrow")
            compare(makePage({ width: CcLogic.minimumTwoColumnWidth + 2 }).layoutMode,
                "wide")
        }

            function test_theWideLayoutSplitsIntoTheModulesTwoSections() {
            var page = makePage({ width: 1024, height: 720 })
            tryVerify(function() { return page.layoutMode === "wide" }, 1000)
            compare(page.sections.left.join(","), CcLogic.sectionOrder("wide").left.join(","))
            compare(page.sections.right.join(","), CcLogic.sectionOrder("wide").right.join(","))

            // The left column holds the four control cards, top to bottom.
            tryVerify(function() { return page.controlsColumnItem.width > 0 }, 1000)
            compare(page.controlsColumnItem.x, 0, "the control column is the left one")
            compare(page.controlsColumnItem.width, page.leftColumnWidth)
            verify(page.calendarItem.x >= page.controlsColumnItem.width,
                "the information column is to the right of the controls")
            verify(page.notificationsItem.x >= page.controlsColumnItem.width)

            // Balanced, and derived from the page's own width rather than from a
            // label: the split is the middle of what is left after the padding and
            // the gutter, and the two columns add up with the gutter to exactly the
            // usable width - nothing is left over for a label to claim.
            compare(page.leftColumnWidth,
                Math.floor((page.usableWidth - page.columnGap) * 0.5),
                "the two columns split the remainder evenly")
            verify(page.leftColumnWidth >= page.controlColumnMinimumWidth
                    && page.rightColumnWidth >= page.infoColumnMinimumWidth,
                "both columns honour their explicit minimum")
            compare(page.leftColumnWidth + page.columnGap + page.rightColumnWidth,
                Math.max(page.usableWidth, page.leftColumnWidth + page.columnGap
                    + page.infoColumnMinimumWidth),
                "the columns plus the gutter consume the usable width exactly")

            var cards = page.controlCards
            compare(cards.length, 4)
            for (var i = 1; i < cards.length; i++) {
                var above = cards[i - 1]
                verify(cards[i].y >= above.y + above.height,
                    "card " + i + " must start below the one above it")
                compare(cards[i].width, above.width,
                    "the cards share one column width")
            }

            // The right column is calendar then notifications, in that order, and
            // the y positions are the ones the module's order array implies.
            var rightOrder = CcLogic.sectionOrder("wide").right
            compare(rightOrder.join(","), "calendar,notifications")
            verify(page.calendarItem.y < page.notificationsItem.y,
                "the calendar is the first information block")
            verify(page.notificationsItem.y
                    >= page.calendarItem.y + page.calendarItem.height,
                "the summary starts below the calendar")
            compare(page.calendarItem.width, page.rightColumnWidth)
            compare(page.notificationsItem.width, page.rightColumnWidth)
        }

        function test_theNarrowStackFollowsTheModulesSectionOrder() {
            var page = makePage({ width: 560, height: 1400 })
            tryVerify(function() { return page.layoutMode === "narrow" }, 1000)
            var order = CcLogic.sectionOrder("narrow").stacked
            compare(page.sections.stacked.join(","), order.join(","))
            compare(order.join(","), "overview,controls,notifications,calendar")

            // Read the real geometry and check it against the module's order,
            // rather than trusting the page's own array back to itself.
            var previousBottom = -1
            for (var i = 0; i < order.length; i++) {
                var item = page.sectionItem(order[i])
                verify(item !== null, "section " + order[i] + " must exist")
                verify(item.visible, "section " + order[i] + " must be shown")
                var top = item.mapToItem(page.layoutContentItem, 0, 0).y
                verify(top >= previousBottom,
                    order[i] + " must start at or below "
                        + (i > 0 ? order[i - 1] : "the top"))
                previousBottom = top + item.height
                // Every stacked section spans the full content width, so a narrow
                // panel never needs a horizontal scroll to reach its far edge.
                compare(item.width, page.usableWidth,
                    order[i] + " must span the narrow content width")
            }
            // All four are on screen at once: a stacked layout is not a pager.
            compare(page.visibleSectionCount, 4)
        }

        function test_theNarrowLayoutHasNoHorizontalOverflow() {
            var page = makePage({ width: 560, height: 1400 })
            tryVerify(function() { return page.layoutMode === "narrow" }, 1000)
            tryVerify(function() { return page.calendarItem.width > 0 }, 1000)

            // The one scroller on this page is vertical only, so there is no
            // horizontal path off the panel at any width.
            var scrollers = scrollContainers(page)
            compare(scrollers.length, 1, "the page has exactly one scroll surface")
            compare(scrollers[0].flickableDirection, Flickable.VerticalFlick)
            verify(scrollers[0].contentWidth <= scrollers[0].width,
                "the scroller has no horizontal overflow to scroll through")

            var items = descendants(page)
            verify(items.length > 0)
            for (var i = 0; i < items.length; i++) {
                var item = items[i]
                verify(item.width >= 0, "no negative width in the narrow layout")
                verify(item.height >= 0, "no negative height in the narrow layout")
                var left = item.mapToItem(page, 0, 0).x
                var right = left + item.width
                verify(left >= -0.5 && right <= page.width + 0.5,
                    "descendant " + i + " (" + item.objectName + ") spans "
                        + left.toFixed(1) + ".." + right.toFixed(1)
                        + " outside 0.." + page.width)
            }
        }

        // The same geometry contract in the wide layout, with long service words
        // that would stretch a column if any label were allowed to.
        function test_theWideLayoutKeepsLongLabelsInsideTheirColumns() {
            var page = makePage({
                width: 900, height: 720,
                networkService: makeFake(fakeNetworkComponent, {
                    activeSsid: "a-network-ssid-long-enough-to-need-eliding" }),
                mediaService: makeFake(fakeMediaComponent, {
                    title: "a track title that is far longer than any column",
                    artist: "and an artist name to match it" })
            })
            tryVerify(function() { return page.layoutMode === "wide" }, 1000)
            tryVerify(function() { return page.mediaCard.width > 0 }, 1000)
            var scrollers = scrollContainers(page)
            compare(scrollers.length, 1)
            compare(scrollers[0].flickableDirection, Flickable.VerticalFlick)

            var items = descendants(page)
            for (var i = 0; i < items.length; i++) {
                var item = items[i]
                var left = item.mapToItem(page, 0, 0).x
                var right = left + item.width
                verify(left >= -0.5 && right <= page.width + 0.5,
                    "descendant " + i + " (" + item.objectName + ") spans "
                        + left.toFixed(1) + ".." + right.toFixed(1))
            }
            // The long words really are long, so the assertion cannot pass by
            // the labels happening to fit: implicitWidth is the natural width, and
            // a Text reports contentWidth AFTER eliding, so elision itself cannot
            // be read back off contentWidth.
            verify(page.mediaCard.summaryItem.implicitWidth
                    > page.mediaCard.summaryItem.width,
                "the fixture must actually need eliding")
            verify(page.mediaCard.summaryItem.elide !== Text.ElideNone,
                "the summary must elide rather than overflow")
            verify(page.mediaCard.titleItem.elide !== Text.ElideNone,
                "the title must elide rather than overflow")
        }

        // --- Overview: page contract and seams ---

        function test_theOverviewPublishesTheWaveRouteContract() {
            var page = makePage({})
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)
            compare(page.objectName, "controlCenterPage")
            verify(page.title.length > 0)
            verify(page.description.length > 0)
            compare(page.sidebarEntries.length, 0,
                "the overview fills the full width; the host hides an empty rail")
            compare(page.activeSidebarId, "")
            // The overview is a top-level route with nothing to pop.
            compare(page.canGoBack, false)
            compare(page.handleBack(), false,
                "declining back is what lets the host close the surface")
            compare(page.focusDefaultCount, 0)
            page.focusDefault()
            tryCompare(page, "focusDefaultCount", 1, 800)
            verify(page.activeFocus,
                "focus lands on the page, never on the launcher's search field")
        }

        function test_theOverviewMapsItsSnapshotsThroughTheLogicNormalizer() {
            var page = makePage({
                networkService: makeFake(fakeNetworkComponent),
                volumeService: makeFake(fakeVolumeComponent, { sinkMuted: true }),
                mediaService: makeFake(fakeMediaComponent)
            })
            tryVerify(function() { return page.controlCardCount === 4 }, 1000)

            for (var i = 0; i < CcLogic.cardKinds.length; i++) {
                var kind = CcLogic.cardKinds[i]
                var data = page.cardData(kind)
                verify(data !== null, kind + " must publish a normalized card")
                // Re-derived from the same snapshot through the same module: any
                // second opinion in the page shows up as a mismatch here.
                var again = CcLogic.normalizeCard(kind, page.snapshotFor(kind))
                compare(JSON.stringify(data), JSON.stringify(again),
                    kind + " must be the module's own normalization, not a local copy")
                compare(data.title, CcLogic.titleFor(kind))
                compare(data.icon, CcLogic.iconFor(kind))
                compare(data.detailRoute, CcLogic.detailRoutes[kind] || "")
            }
            compare(page.cardData("volume").summary, "Muted")
            compare(page.cardData("volume").action, "direct")
            compare(page.cardData("network").action, "detail")
            compare(page.cardData("media").detailRoute, "",
                "media has no detail route yet")
        }

        // No runtime assertion can see a card that forgot the module: the state
        // logic could be re-derived inline and every behavioural check above
        // would still pass. The source is read directly instead.
        function test_theOverviewMapsThroughControlCenterLogicInsteadOfForkingIt() {
            var file = readRepoFile("modules/lazerbar/ControlCenter.qml")
            compare(file.status, 200, "the overview source must be readable")
            verify(file.text.indexOf("ControlCenterLogic.js") >= 0,
                "the overview must import the shared contract module")
            var calls = file.text.match(/CcLogic\.normalizeCard\(/g)
            verify(calls !== null && calls.length >= 1,
                "the overview must normalize cards through CcLogic.normalizeCard")

            // The caller hands the summary the module's fixed cap, never a number
            // of its own: a limit derived from the incoming history would let a
            // busy list reshape the panel, which is the exact failure the module's
            // constant exists to prevent.
            verify(file.text.indexOf("maxEntries: CcLogic.notificationEntryCap") >= 0,
                "the overview must cap the summary with the module's own constant")

            verify(file.text.indexOf("markAllRead") < 0,
                "the overview must never clear the user's read state")

            // Layout and header vocabulary comes from the module too.
            verify(file.text.indexOf("CcLogic.sectionOrder") >= 0,
                "the section order must come from the module")
            verify(file.text.indexOf("CcLogic.layoutMode") >= 0,
                "the breakpoint must come from the module")
            verify(file.text.indexOf("CcLogic.minimumTwoColumnWidth") >= 0,
                "the breakpoint value must be the module's own constant")
            verify(file.text.indexOf("CcLogic.weatherState") >= 0)
        }
    }
}