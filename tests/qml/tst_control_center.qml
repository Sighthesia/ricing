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
        }
    }

    property Item testHost: null

    TestCase {
        name: "ControlCenter"

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            activationProbe.count = 0
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
    }
}