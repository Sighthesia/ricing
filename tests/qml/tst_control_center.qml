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

    TestCase {
        name: "ControlCenter"

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            activationProbe.count = 0
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function makeCard(properties) {
            var args = { x: 0, y: 0, width: 320, height: 64 }
            for (var key in properties)
                args[key] = properties[key]
            return cardComponent.createObject(root, args)
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
            var card = makeCard({
                width: 180, height: 64, title: "Network adapter with a long name",
                summary: longText, status: "error", available: true, error: longText
            })
            tryVerify(function() { return card.titleItem.width > 0 }, 800)

            verify(boxInsideCard(card, card.titleItem), "the title must stay inside the card")
            verify(boxInsideCard(card, card.summaryItem), "the summary must stay inside the card")
            verify(boxInsideCard(card, card.stateBadgeItem), "the state badge must stay inside the card")
            verify(boxInsideCard(card, card.iconItem), "the icon must stay inside the card")
            verify(card.titleItem.elide !== Text.ElideNone, "the title must elide")
            verify(card.summaryItem.elide !== Text.ElideNone, "the summary must elide")
            // The badge keeps its own width; the text column takes what is left,
            // so the two never claim the same strip of the title row.
            var titleRight = card.titleItem.mapToItem(card, card.titleItem.width, 0).x
            verify(titleRight <= card.stateBadgeItem.mapToItem(card, 0, 0).x + 0.5,
                "the title and the badge cannot both claim the same strip")
            card.destroy()
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

        function test_calendarGridIsFixedAtSixRowsForEveryMonth() {
            var february = calendarComponent.createObject(root, { viewYear: 2026, viewMonth: 1 })
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

            var january = calendarComponent.createObject(root, { viewYear: 2026, viewMonth: 0 })
            compare(delegatesWhere(january, "inMonth", true).length, Calendar.daysInMonth(2026, 0))
            compare(january.implicitHeight, february.implicitHeight,
                "a fixed six-row grid must not change the calendar's height")
            january.destroy()
            february.destroy()
        }

        function test_calendarSteppingWrapsBothWays() {
            var calendar = calendarComponent.createObject(root, { viewYear: 2026, viewMonth: 0 })
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
            var calendar = calendarComponent.createObject(root, { viewYear: 2026, viewMonth: 11 })
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
            var calendar = calendarComponent.createObject(root, {
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
            var calendar = calendarComponent.createObject(root, {
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
            var calendar = calendarComponent.createObject(root, { width: 260 })
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