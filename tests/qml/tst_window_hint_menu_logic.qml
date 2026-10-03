import QtQuick
import QtTest
import "../../modules/bar/WindowHintMenuLogic.js" as Hint

// Pure-logic contract for the mod-key window hint menu. The service owns the
// snapshot, so what is verified here is the translation into rows and the cap
// that keeps the popup bounded - the parts that would otherwise only be visible
// by holding a key on a live desktop.
Item {
    id: root
    width: 400
    height: 400

    // The panel's own measurements, as LITERALS, because they are what the layout
    // function below is checked against and reading them back off `Hint` would let a
    // change to the function be satisfied by a change to the constants it is measured
    // against. Spelled out: a neighbour 180, a gutter 6, the active column 360.
    //
    //   |<-180-| -6- |<-  360  ->|-6-| <-180-|
    //   0      186  186        546 552     732
    //
    // `PITCH` is two NEIGHBOUR columns and the gutter between them; `BAND_X` is the
    // wide middle slot's left edge, which is the band's own x; `RIGHT_X` is the right
    // neighbour's left edge. The layout function is handed the last two rather than
    // deriving them, so these are the numbers it has to place columns between.
    readonly property int narrowCol: 180
    readonly property int gutter: 6
    readonly property int wideCol: 360
    readonly property int pitch: 186
    readonly property int bandX: 186
    readonly property int rightX: 552
    readonly property int panelW: 732

    // A snapshot shaped exactly like WindowHintService's, so a change to the
    // service's contract has to be made here too.
    function makeHint(overrides) {
        var hint = {
            workspaceId: "42",
            workspaceIndex: 2,
            currentIndex: 1,
            currentWindowTitle: "afloat",
            windows: [
                { windowId: "10", title: "kitty", appId: "kitty", icon: "/i/kitty.png", isFocused: false },
                { windowId: "11", title: "afloat", appId: "kitty", icon: "/i/kitty.png", isFocused: true },
                { windowId: "12", title: "firefox", appId: "firefox", icon: "/i/ff.png", isFocused: false }
            ],
            // The neighbours the service resolves by position. One window each,
            // so a test that forgets to override them still sees three columns.
            previousWindows: [
                { windowId: "20", title: "prev only", appId: "prev", icon: "/i/prev.png", isFocused: false }
            ],
            nextWindows: [
                { windowId: "30", title: "next only", appId: "next", icon: "/i/next.png", isFocused: false }
            ],
            workspaces: [
                { workspaceId: "41", workspaceIndex: 1, isActive: false, icons: [] },
                { workspaceId: "42", workspaceIndex: 2, isActive: true, icons: [{ windowId: "10" }, { windowId: "11" }, { windowId: "12" }] }
            ]
        }
        for (var key in (overrides || {}))
            hint[key] = overrides[key]
        return hint
    }

    TestCase {
        id: test
        name: "WindowHintMenuLogic"
        when: windowShown

        // ---- ready ------------------------------------------------------
        function test_ready_requiresAnActiveWorkspace() {
            // A cold snapshot has no workspaceId yet; every row would read as
            // missing, so the menu must report itself not ready.
            compare(Hint.ready(null), false)
            compare(Hint.ready({}), false)
            compare(Hint.ready({ workspaceId: "" }), false)
            compare(Hint.ready(makeHint()), true)
        }

        // ---- window rows -----------------------------------------------
        function test_windowRows_carryTheActivationTarget() {
            var rows = Hint.windowRows(makeHint())
            compare(rows.length, 3)
            // The click route needs the id niri knows, not the title.
            compare(rows[0].windowId, "10")
            compare(rows[1].isFocused, true)
            compare(rows[2].title, "firefox")
            compare(rows[0].icon, "/i/kitty.png")
        }

        function test_windowRows_keepServiceOrder() {
            // The service sorts by column, then row, then id, which is the
            // on-screen tiling order; the menu must not re-sort on top of it.
            var rows = Hint.windowRows(makeHint())
            compare(rows[0].windowId, "10")
            compare(rows[1].windowId, "11")
            compare(rows[2].windowId, "12")
        }

        function test_windowRows_tolerateAColdSnapshot() {
            compare(Hint.windowRows(null).length, 0)
            compare(Hint.windowRows({}).length, 0)
            compare(Hint.windowRows({ windows: [null, undefined] }).length, 0)
        }

        // ---- cap -------------------------------------------------------
        function test_windowRows_capAtTheVisibleLimit() {
            var many = []
            for (var i = 0; i < Hint.MAX_WINDOW_ROWS + 3; i++)
                many.push({ windowId: String(i), title: "w" + i, isFocused: false })
            var page = Hint.cappedWindowRows(makeHint({ windows: many }))
            // The menu owns no scroll surface, so the cap is what keeps the
            // popup's input region from growing once per extra window.
            compare(page.rows.length, Hint.MAX_WINDOW_ROWS)
            compare(page.hidden, 3)
            compare(Hint.overflowLabel(page.hidden), "+3 more windows")
        }

        function test_windowRows_underTheCapReportNoOverflow() {
            var page = Hint.cappedWindowRows(makeHint())
            compare(page.rows.length, 3)
            compare(page.hidden, 0)
            // An empty string lets the renderer bind visibility to the text.
            compare(Hint.overflowLabel(page.hidden), "")
        }

        function test_overflowLabel_singularisesOneWindow() {
            var many = []
            for (var i = 0; i < Hint.MAX_WINDOW_ROWS + 1; i++)
                many.push({ windowId: String(i), title: "w" + i, isFocused: false })
            var page = Hint.cappedWindowRows(makeHint({ windows: many }))
            compare(Hint.overflowLabel(page.hidden), "+1 more window")
        }

        function test_emptyWorkspaceIsReadyWithNoRows() {
            // Zero windows is a valid empty workspace, not a missing snapshot:
            // the list renders its own "no windows" line instead.
            var empty = makeHint({
                windows: [],
                workspaces: [{ workspaceId: "42", workspaceIndex: 2, isActive: true, icons: [] }]
            })
            compare(Hint.ready(empty), true)
            compare(Hint.cappedWindowRows(empty).rows.length, 0)
            compare(Hint.overflowLabel(Hint.cappedWindowRows(empty).hidden), "")
        }

        // ---- focus target -----------------------------------------------
        function test_focusedRowIndex_pointsAtTheFocusedWindow() {
            compare(Hint.focusedRowIndex(makeHint()), 1)
        }

        function test_focusedRowIndex_isMinusOneWithoutAFocusedWindow() {
            var none = makeHint({
                windows: [
                    { windowId: "10", title: "a", isFocused: false },
                    { windowId: "11", title: "b", isFocused: false }
                ]
            })
            compare(Hint.focusedRowIndex(none), -1)
            compare(Hint.focusedRowIndex(null), -1)
            compare(Hint.focusedRowIndex({}), -1)
        }

        function test_focusedRowIndex_resolvesPastTheCapToNothing() {
            // The window is real but not on screen, so the underline has no
            // honest target and the index must not point off the end of the
            // list.
            var many = []
            for (var i = 0; i < 8; i++)
                many.push({ windowId: String(i), title: "w" + i, isFocused: i === 7 })
            compare(Hint.cappedWindowRows(makeHint({ windows: many })).rows.length, Hint.MAX_WINDOW_ROWS)
            compare(Hint.focusedRowIndex(makeHint({ windows: many })), -1)
        }

        function test_focusedRowIndex_usesTheFirstFocusedRow() {
            // niri reports one focused window, but a stale snapshot can briefly
            // carry two; the underline must land on exactly one of them.
            var two = makeHint({
                windows: [
                    { windowId: "10", title: "a", isFocused: true },
                    { windowId: "11", title: "b", isFocused: true }
                ]
            })
            compare(Hint.focusedRowIndex(two), 0)
        }

        // ---- the three columns -------------------------------------------
        function test_cappedColumns_returnPreviousCurrentNext() {
            // The panel is three columns: the workspaces either side of the
            // active one, and the active one. Previous and next come from the
            // service's own resolution, so the order is by workspace position
            // and NOT by anything the view decides.
            var columns = Hint.cappedColumns(makeHint())
            compare(Object.keys(columns).sort().join(","), "current,next,previous")
            compare(columns.previous.rows[0].windowId, "20")
            compare(columns.current.rows[0].windowId, "10")
            compare(columns.next.rows[0].windowId, "30")
            // The neighbours are shaped exactly like the active column's rows, so
            // one row component can render all three.
            var prev = columns.previous.rows[0]
            compare(Object.keys(prev).sort().join(","), "appId,icon,isFocused,title,windowId")
        }

        function test_cappedColumns_capEveryColumnAlike() {
            // Same cap on all three, or the panel height would be driven by
            // whichever neighbour happened to be busiest and the three columns
            // would not read as peers.
            var many = []
            for (var i = 0; i < 8; i++)
                many.push({ windowId: "n" + i, title: "n" + i, isFocused: false })
            var columns = Hint.cappedColumns(makeHint({
                previousWindows: many, windows: many, nextWindows: many
            }))
            compare(columns.previous.rows.length, Hint.MAX_WINDOW_ROWS)
            compare(columns.current.rows.length, Hint.MAX_WINDOW_ROWS)
            compare(columns.next.rows.length, Hint.MAX_WINDOW_ROWS)
            compare(columns.previous.hidden, 3)
            compare(columns.next.hidden, 3)
        }

        function test_cappedColumns_leaveAMissingNeighbourEmpty() {
            // At either end of the workspace list there is no workspace there.
            // `cappedColumns` still reports all three, so the view can tell an
            // absent neighbour from one it has not resolved yet; `columnCount` is
            // what decides that neither gets a slot.
            var atStart = Hint.cappedColumns(makeHint({ previousWindows: [] }))
            compare(atStart.previous.rows.length, 0)
            compare(atStart.previous.hidden, 0)
            compare(atStart.next.rows.length, 1, "the other side is unaffected")
            // A snapshot from before the service knew about neighbours at all
            // must not throw, and must not invent columns either.
            var cold = Hint.cappedColumns(null)
            compare(cold.previous.rows.length, 0)
            compare(cold.current.rows.length, 0)
            compare(cold.next.rows.length, 0)
        }

// ---- the shape of the panel ---------------------------------------
        function test_cappedColumns_alwaysReportsAllThreeSlots() {
            // A column with no windows still gets a slot. An earlier version
            // dropped it and narrowed the panel, which moved the active workspace
            // out of the middle and resized the panel under the pointer - so the
            // same three workspaces read as a different panel each time.
            var empty = Hint.cappedColumns(makeHint({ previousWindows: [], nextWindows: [] }))
            compare(Object.keys(empty).sort().join(","), "current,next,previous")
            compare(empty.previous.rows.length, 0, "previous is present and empty")
            compare(empty.next.rows.length, 0, "next is present and empty")
            compare(empty.current.rows.length, 3, "and the active one is untouched")
        }

        function test_thePanelIsAlwaysThreeColumnsWide() {
            // One number, not a count of what happens to be on screen. It cannot be
            // derived from the columns, which is the whole point: the frame is the
            // same size whether the neighbours are busy or empty.
            compare(Hint.COLUMN_COUNT, 3)
            compare(Hint.COLUMN_COUNT, 1 + 2, "the active column and its two neighbours")
            verify(Hint.columnCount === undefined,
                "and there is no per-snapshot count left to disagree with it")
        }

        function test_aNeighbourColumnSaysItIsEmptyRatherThanGoingBlank() {
            // The word is one string, and it names no workspace: a column with no
            // number on it cannot say which one it is, and the position in the
            // panel already does that.
            compare(Hint.NEIGHBOUR_EMPTY_LABEL, "No windows")
            verify(Hint.NEIGHBOUR_EMPTY_LABEL.indexOf("workspace") < 0,
                "and must not read as a statement about the active workspace")
        }

        function test_columnWidthIsAFixedColumnSize() {
            // A NEIGHBOUR's width is the panel's unit and it does not vary, which is
            // what makes the panel a fixed frame. It is no longer the whole panel:
            // the active column is twice this, so `COLUMN_WIDTH * COLUMN_COUNT` is
            // NOT a full panel any more, and that is the change this suite has to
            // pin rather than let pass by accident.
            compare(Hint.COLUMN_WIDTH, root.narrowCol)
            compare(Hint.ACTIVE_COLUMN_SCALE, 2, "the active column is twice a neighbour's")
            compare(Hint.ACTIVE_COLUMN_WIDTH, root.wideCol,
                "which is " + Hint.COLUMN_WIDTH + " * " + Hint.ACTIVE_COLUMN_SCALE)
            compare(Hint.ACTIVE_COLUMN_WIDTH, Hint.COLUMN_WIDTH * 2,
                "and the scale is the only thing that turns one into the other")
            compare(Hint.COLUMN_WIDTH * Hint.COLUMN_COUNT, 540,
                "three neighbours would be 540, which the panel is not")
        }

        function test_panelWidth_isTheWideMiddleBetweenTwoNeighbours() {
            // A neighbour, a gutter, the active column, a gutter, a neighbour - and
            // the band sits in the middle one, so a panel width computed any other way
            // leaves the band's right edge a whole gutter out from the surface while
            // its left edge is exactly `barWidgetGutter` from the other side.
            compare(Hint.panelWidth(root.narrowCol, root.wideCol, root.gutter), root.panelW)
            // Spelled out rather than derived from `Hint`, so the layout and the panel
            // that shows it cannot be changed together and stay consistent by accident.
            compare(Hint.panelWidth(root.narrowCol, root.wideCol, root.gutter),
                root.narrowCol + root.gutter + root.wideCol + root.gutter + root.narrowCol,
                "neighbour, gutter, active, gutter, neighbour")
            compare(Hint.panelWidth(root.narrowCol, root.wideCol, root.gutter),
                root.bandX + root.wideCol + root.gutter + root.narrowCol,
                "which puts the band's right edge one gutter before the panel's")
            // Two equal columns would be a smaller panel by exactly the active
            // column's extra width, which is the mistake this is here to catch.
            verify(Hint.panelWidth(root.narrowCol, root.wideCol, root.gutter)
                    - Hint.panelWidth(root.narrowCol, root.narrowCol, root.gutter) === root.wideCol - root.narrowCol,
                "and a panel of three equal columns is short by the difference")
        }

        // ---- the layout function -----------------------------------------
        // `slotX` and `slotWidth` answer one question: given a column's distance -
        // in workspaces, and fractional - from the workspace the panel is centred on,
        // where is it and how wide is it. The crossing is that distance running from
        // one workspace to the next, and nothing else moves.

        function test_slotGeometry_putsTheActiveColumnInTheWideMiddleSlot() {
            compare(Hint.slotX(0, root.pitch, root.rightX), root.bandX,
                "the active column starts at the band's own x")
            compare(Hint.slotWidth(0, root.narrowCol, root.wideCol), root.wideCol,
                "and is the wide column")
            compare(Hint.slotX(-1, root.pitch, root.rightX), 0,
                "the left neighbour sits at the panel's left edge")
            compare(Hint.slotX(1, root.pitch, root.rightX), root.rightX,
                "the right neighbour one active column further on")
            compare(Hint.slotWidth(-1, root.narrowCol, root.wideCol), root.narrowCol,
                "and both neighbours are narrow")
            compare(Hint.slotWidth(1, root.narrowCol, root.wideCol), root.narrowCol)
        }

        function test_slotGeometry_widensOnTheWayInAndNarrowsOnTheWayOut() {
            // The width change the crossing is drawn with. Halfway between two
            // workspaces, both columns are exactly halfway between the two widths -
            // which is the arithmetic that makes the pair swap without overlapping.
            var half = Hint.slotWidth(0.5, root.narrowCol, root.wideCol)
            compare(half, (root.narrowCol + root.wideCol) / 2,
                "a column halfway out is halfway between the widths")
            compare(Hint.slotWidth(0.25, root.narrowCol, root.wideCol),
                root.narrowCol + (root.wideCol - root.narrowCol) * 0.75,
                "and a quarter of the way OUT from the active column is three quarters "
                    + "of the way back to a neighbour's")
            // Monotone all the way in and all the way out, so a column never grows
            // and shrinks inside one crossing - which would read as a mistake rather
            // than as motion. Walking `rel` DOWN towards zero is walking towards the
            // middle of the panel, so the width climbs; walking it away, it falls.
            var previous = Hint.slotWidth(1, root.narrowCol, root.wideCol)
            compare(previous, root.narrowCol, "it starts at a neighbour's width")
            for (var step = 1; step <= 20; ++step) {
                var width = Hint.slotWidth(1 - step / 20, root.narrowCol, root.wideCol)
                verify(width > previous, "still widening at rel " + (1 - step / 20) + ", was " + width)
                previous = width
            }
            compare(previous, root.wideCol, "and it arrives at the active column's width")
            previous = Hint.slotWidth(0, root.narrowCol, root.wideCol)
            for (step = 1; step <= 20; ++step) {
                width = Hint.slotWidth(-step / 20, root.narrowCol, root.wideCol)
                verify(width < previous, "still narrowing at rel " + (-step / 20) + ", was " + width)
                previous = width
            }
            compare(previous, root.narrowCol, "and it leaves at a neighbour's")
            compare(Hint.slotWidth(-1, root.narrowCol, root.wideCol), root.narrowCol,
                "and that is the neighbour's width, from either side")
        }

        function test_slotGeometry_isContinuousWhereTheSlopeChanges() {
            // `slotX` and `slotWidth` are piecewise, so a boundary whose two sides
            // disagreed would be a column that JUMPS as the crossing passes it - the
            // one thing a crossing described as continuous cannot have. Every
            // boundary, and both sides of it, because the pieces meet at -1, 0 and 1
            // and nowhere else.
            //
            // Sampled a billionth either side of the boundary and compared against
            // the boundary's own answer, which is the limit rather than a sample of
            // it. The tolerance is far tighter than the steepest slope in this layout
            // (366) can produce at that distance, and far wider than the representation
            // error of a number this size - so it cannot pass by being vague, and it
            // is not testing the last bits of a double.
            var epsilon = 1e-9
            var tolerance = 1e-6
            for (var boundary = -4; boundary <= 4; ++boundary) {
                var atX = Hint.slotX(boundary, root.pitch, root.rightX)
                verify(Math.abs(Hint.slotX(boundary + epsilon, root.pitch, root.rightX) - atX) < tolerance
                        && Math.abs(Hint.slotX(boundary - epsilon, root.pitch, root.rightX) - atX) < tolerance,
                    "x is continuous at rel " + boundary + ", was " + atX)
                var atW = Hint.slotWidth(boundary, root.narrowCol, root.wideCol)
                verify(Math.abs(Hint.slotWidth(boundary + epsilon, root.narrowCol, root.wideCol) - atW) < tolerance
                        && Math.abs(Hint.slotWidth(boundary - epsilon, root.narrowCol, root.wideCol) - atW) < tolerance,
                    "and so is the width at rel " + boundary + ", was " + atW)
            }
        }

        function test_slotGeometry_marchesOffPanelColumnsAtNeighbourWidth() {
            // A crossing's strip is `span + 3` columns and the panel is three, so up
            // to three columns are outside the panel at any instant. They are content,
            // not decoration: they have to keep their own width and keep stepping by
            // the neighbour pitch, or the run would not be a run and the column that
            // is on its way IN would arrive at the wrong place.
            for (var rel = 2; rel <= 6; ++rel) {
                compare(Hint.slotWidth(rel, root.narrowCol, root.wideCol), root.narrowCol,
                    "rel " + rel + " is neighbour-width")
                compare(Hint.slotX(rel, root.pitch, root.rightX),
                    root.rightX + (rel - 1) * root.pitch,
                    "and steps on by the neighbour pitch")
                compare(Hint.slotX(-rel, root.pitch, root.rightX), -(rel - 1) * root.pitch,
                    "the other way: rel " + (-rel) + " is off to the left")
                compare(Hint.slotWidth(-rel, root.narrowCol, root.wideCol), root.narrowCol)
            }
        }

        function test_theGapBetweenTwoColumnsIsTheGutterAtEveryInstantOfACrossing() {
            // The property that makes this layout safe rather than merely pretty.
            //
            // Both ends of a crossing are contiguous layouts of the same run of
            // workspaces - column i's right edge is column i+1's left edge less the
            // gutter - and interpolating each column's OWN x and width between those
            // two answers keeps them contiguous, because a lerp of differences is the
            // difference of lerps. So no two cards ever overlap, and the widest bare
            // strip the panel can show at any instant is one inter-card gap: which is
            // exactly the guarantee "the panel is never left uncovered" is stated in.
            //
            // Swept over every span, both directions, every column of the strip and
            // forty-one samples along the crossing. One case of it would prove
            // nothing about the family.
            var samples = 0
            for (var span = 1; span <= Hint.MAX_SWITCH_SPAN; ++span) {
                for (var direction = 0; direction < 2; ++direction) {
                    var from = direction === 0 ? 2 : 6
                    var to = direction === 0 ? 2 + span : 6 - span
                    var plan = Hint.stripPlan(from, to)
                    for (var step = 0; step <= 40; ++step) {
                        var q = step / 40
                        var centre = plan.fromPosition
                            + (plan.toPosition - plan.fromPosition) * q
                        var right = 0
                        for (var slot = 0; slot < plan.slots; ++slot) {
                            var rel = (plan.base + slot) - centre
                            var x = Hint.slotX(rel, root.pitch, root.rightX)
                            var width = Hint.slotWidth(rel, root.narrowCol, root.wideCol)
                            if (slot > 0)
                                verify(Math.abs(x - right - root.gutter) < 1e-6,
                                    "span " + span + " dir " + direction + " q " + q
                                        + ": slot " + slot + " sits exactly one gutter ("
                                        + root.gutter + ") from the one before, was "
                                        + (x - right))
                            right = x + width
                            samples++
                        }
                    }
                }
            }
            verify(samples > 1000,
                "and the sweep was wide enough to be worth something, was " + samples)
        }

        function test_aCrossingNeverOverlapsTwoCards() {
            // The other half of the same claim, stated as its consequence rather than
            // as arithmetic: the strip is what it is for, and two cards sharing pixels
            // during a crossing is the fault the whole geometry was chosen to avoid.
            // Half a step either side of every boundary of every crossing, which is
            // where a layout with a discontinuity would show it.
            for (var span = 1; span <= Hint.MAX_SWITCH_SPAN; ++span) {
                for (var direction = 0; direction < 2; ++direction) {
                    var from = direction === 0 ? 2 : 6
                    var to = direction === 0 ? 2 + span : 6 - span
                    var plan = Hint.stripPlan(from, to)
                    for (var half = 0; half <= 40; ++half) {
                        var centre = from + (to - from) * (half / 40)
                        var previousRight = -1e9
                        for (var slot = 0; slot < plan.slots; ++slot) {
                            var rel = (plan.base + slot) - centre
                            var x = Hint.slotX(rel, root.pitch, root.rightX)
                            var width = Hint.slotWidth(rel, root.narrowCol, root.wideCol)
                            verify(x >= previousRight,
                                "span " + span + " dir " + direction + " half " + half
                                    + ": slot " + slot + " does not overlap the one before")
                            previousRight = x + width
                        }
                    }
                }
            }
        }

        function test_focusedIndexIn_readsARowList() {
            // The view asks about the column it is actually painting, which is
            // why the index is resolved from a row list rather than only from a
            // whole snapshot.
            var rows = [{ windowId: "a", isFocused: false }, { windowId: "b", isFocused: true }]
            compare(Hint.focusedIndexIn(rows), 1)
            compare(Hint.focusedIndexIn([{ isFocused: false }]), -1)
            compare(Hint.focusedIndexIn(null), -1)
        }

        // ---- swap direction --------------------------------------------
        function test_switchDirection_followsTheWorkspaceMove() {
            compare(Hint.switchDirection({
                activeWorkspacePosition: 3, previousActiveWorkspacePosition: 2
            }), 1)
            compare(Hint.switchDirection({
                activeWorkspacePosition: 1, previousActiveWorkspacePosition: 3
            }), -1)
        }

        function test_switchDirection_isZeroWhenThereWasNoMove() {
            // A title edit on the same workspace republishes the snapshot without
            // moving; an un-aimed animation there would be motion for its own
            // sake, so the list commits straight away.
            compare(Hint.switchDirection({
                activeWorkspacePosition: 2, previousActiveWorkspacePosition: 2
            }), 0)
            // A first snapshot reports -1 for the previous position, which is
            // indistinguishable from "unknown" - and 0 is the right answer.
            compare(Hint.switchDirection({
                activeWorkspacePosition: 2, previousActiveWorkspacePosition: -1
            }), 0)
            compare(Hint.switchDirection({}), 0)
            compare(Hint.switchDirection(null), 0)
        }

        // ---- the strip: one column per workspace -------------------------
        // A workspace's windows, titled after its own position, so a title in the
        // panel names the workspace it came from and a repeated title is
        // unambiguous. Shaped like WindowHintService's snapshot.
        function framed(active, previous) {
            function ws(position) {
                return [{ windowId: "w" + position, title: "ws" + position,
                    appId: "kitty", icon: "", isFocused: true }]
            }
            return {
                workspaceId: "ws" + active,
                workspaceIndex: active,
                activeWorkspacePosition: active,
                previousActiveWorkspacePosition: previous,
                windows: ws(active),
                previousWindows: ws(active - 1),
                nextWindows: ws(active + 1)
            }
        }

        function test_stripPlan_centresTheActiveWorkspaceAtBothEndsOfTheCrossing() {
            // The claim the whole crossing rests on, restated for a layout whose
            // slots have two different widths. There is no strip that translates by a
            // number of columns any more: every column places itself from how far it
            // is from the workspace the panel is centred on, so "in the middle" means
            // "at the band's left edge, at the active column's width".
            //
            // Both ends, and from the geometry rather than from a field of the plan -
            // the plan's own numbers are asserted in the test below, so asserting
            // them here would only be checking that the plan is its own definition.
            for (var span = 1; span <= Hint.MAX_SWITCH_SPAN; ++span) {
                for (var direction = 0; direction < 2; ++direction) {
                    var from = direction === 0 ? 1 : 6
                    var to = direction === 0 ? 1 + span : 6 - span
                    var plan = Hint.stripPlan(from, to)
                    var tag = "span " + span + " dir " + direction
                    // At the start of the leg the workspace being left is the one the
                    // panel is centred on, so it is in the middle at its full width.
                    compare(Hint.slotX(from - plan.fromPosition, root.pitch, root.rightX),
                        root.bandX, tag + ": the workspace being left starts in the middle")
                    compare(Hint.slotWidth(from - plan.fromPosition, root.narrowCol, root.wideCol),
                        root.wideCol, tag + ": at the active column's width")
                    // At the end the arriving one is. No special case for either
                    // direction, which is the point of keying the layout on the
                    // workspace rather than on the direction of travel.
                    compare(Hint.slotX(to - plan.toPosition, root.pitch, root.rightX),
                        root.bandX, tag + ": and the arriving one ends there")
                    compare(Hint.slotWidth(to - plan.toPosition, root.narrowCol, root.wideCol),
                        root.wideCol, tag + ": at the same width")
                    // And for the whole of the travel before that it is NOT in the
                    // middle, which is what makes the crossing a crossing: the card
                    // column arrives from the side rather than changing under the
                    // reader. Halfway is the widest honest sample of that.
                    compare(Hint.slotWidth(to - plan.fromPosition, root.narrowCol, root.wideCol),
                        root.narrowCol,
                        tag + ": while it is still off to the side it is neighbour-width")
                    verify(Hint.slotX(to - plan.fromPosition, root.pitch, root.rightX)
                            !== root.bandX,
                        tag + ": and not in the middle yet")
                }
            }
        }

        function test_stripPlan_isTheUnionOfTheTwoFrames() {
            // `span + 3` columns, one per workspace, covering exactly the positions
            // the two frames between them describe. Asserted as the set of positions
            // rather than as a count, so a strip that is the right length but the
            // wrong run fails here.
            for (var span = 1; span <= Hint.MAX_SWITCH_SPAN; ++span) {
                for (var direction = 0; direction < 2; ++direction) {
                    var from = direction === 0 ? 2 : 5
                    var to = direction === 0 ? 2 + span : 5 - span
                    var plan = Hint.stripPlan(from, to)
                    var positions = []
                    for (var k = 0; k < plan.slots; ++k)
                        positions.push(plan.base + k)
                    var low = Math.min(from, to) - 1
                    var high = Math.max(from, to) + 1
                    compare(positions.length, high - low + 1,
                        "span " + span + " dir " + direction + ": one column per position")
                    compare(positions[0], low, "starting at the lowest")
                    compare(positions[positions.length - 1], high, "and ending at the highest")
                    // No repeats, which is the property the duplication depended on
                    // before: each position appears once, so there is only one place
                    // its windows could be painted from.
                    var unique = {}
                    for (var j = 0; j < positions.length; ++j)
                        unique[positions[j]] = true
                    compare(Object.keys(unique).length, positions.length,
                        "span " + span + " dir " + direction + ": and no position twice")
                }
            }
        }

        function test_stripPlan_reportsTheArrivingColumnAsTheActiveSlot() {
            // The slot the markers are placed against. The body reads it off this
            // rather than keeping its own number, so the column carrying the card
            // fill and the one the highlight sits on cannot be two different
            // columns - which is what "the focus highlight is a child of the
            // arriving column" needs in order to be true.
            for (var span = 1; span <= Hint.MAX_SWITCH_SPAN; ++span) {
                for (var direction = 0; direction < 2; ++direction) {
                    var from = direction === 0 ? 1 : 6
                    var to = direction === 0 ? 1 + span : 6 - span
                    var plan = Hint.stripPlan(from, to)
                    compare(plan.activeSlot, to - plan.base,
                        "span " + span + " dir " + direction + ": the arriving position's slot")
                    compare(plan.activePosition, to,
                        "span " + span + " dir " + direction
                            + ": and the markers belong to that workspace")
                    compare(plan.fromPosition, from,
                        "span " + span + " dir " + direction + ": the leg starts where the panel was")
                    compare(plan.toPosition, to,
                        "span " + span + " dir " + direction + ": and ends where it is going")
                    verify(plan.activeSlot >= 0 && plan.activeSlot < plan.slots,
                        "span " + span + " dir " + direction + ": and it is on the strip, was "
                            + plan.activeSlot)
                    // The active slot is never the same as the leaving frame's active
                    // slot, so the card fill is not on the column being left.
                    var leavingSlot = from - plan.base
                    verify(plan.activeSlot !== leavingSlot || span === 0,
                        "span " + span + " dir " + direction + ": a different column from the leaving one")
                }
            }
        }

        function test_stripPlan_refusesAMoveWiderThanTheTwoFramesTogether() {
            // Two three-column frames tile a contiguous run only while the move is no
            // wider than they are together; one step apart they overlap in two
            // positions, two steps in one, three in none, and at four steps the middle
            // belongs to neither snapshot. A strip cannot have a column whose
            // contents nothing knows.
            compare(Hint.stripPlan(1, 1), null, "no move at all")
            compare(Hint.stripPlan(2, 2), null, "the same position")
            compare(Hint.stripPlan(2, -1), null, "an unknown previous position")
            compare(Hint.stripPlan(-1, 2), null, "an unknown active one")
            compare(Hint.stripPlan(0, 4), null, "four steps apart")
            compare(Hint.stripPlan(4, 0), null, "four steps the other way")
            compare(Hint.stripPlan(0, 9), null, "and further still")
            // The boundary itself, from both directions, so the threshold is pinned
            // rather than assumed.
            compare(Hint.stripPlan(1, 4).span, Hint.MAX_SWITCH_SPAN, "three steps is allowed")
            compare(Hint.stripPlan(4, 1).span, Hint.MAX_SWITCH_SPAN, "backwards too")
            verify(Hint.MAX_SWITCH_SPAN === 3, "and the limit is three, was "
                + Hint.MAX_SWITCH_SPAN)
        }

        function test_stripPlan_directionIsTheWorkspaceMove() {
            compare(Hint.stripPlan(1, 2).direction, 1, "later in the list")
            compare(Hint.stripPlan(2, 1).direction, -1, "earlier")
            compare(Hint.stripPlan(1, 3).direction, 1, "and for a longer move")
            compare(Hint.stripPlan(3, 1).direction, -1, "backwards")
        }

        function test_restPlan_isThreeColumnsWithTheActiveOneInTheMiddle() {
            // A panel at rest is a plan too, deliberately the same shape, so the
            // component's bindings are written once rather than branching on whether
            // anything is moving.
            var rest = Hint.restPlan(framed(4, 4))
            compare(rest.slots, 3, "three columns")
            compare(rest.activeSlot, 1, "active in the middle")
            compare(rest.base, 3, "based at the active position's predecessor")
            compare(rest.span, 0, "and nowhere to travel")
            compare(rest.fromPosition, 4, "the panel is centred on it")
            compare(rest.toPosition, 4, "at both ends of a crossing that goes nowhere")
            compare(rest.activePosition, 4, "and the markers are its own")
            // A snapshot with no active workspace yet cannot say where its columns
            // are, and says so rather than inventing a frame.
            compare(Hint.restPlan(null), null)
            compare(Hint.restPlan({ activeWorkspacePosition: -1 }), null)
        }

        function test_stripColumns_holdEachPositionOnce() {
            // The heart of it, at the unit level. The strip is the ordered union of
            // the two frames, so every position appears exactly once with its own
            // windows - which is why a title cannot be painted twice during a
            // crossing: there is only one column that could paint it.
            //
            // The two frames here share two workspaces, which is the case the old
            // two-copy page turn got wrong.
            var leaving = framed(1, 1)
            var arriving = framed(2, 1)
            var plan = Hint.stripPlan(1, 2)
            var columns = Hint.stripColumns(arriving, leaving, plan)
            compare(columns.length, plan.slots, "one column per slot")
            var byPosition = {}
            for (var i = 0; i < columns.length; ++i) {
                byPosition[columns[i].position] = columns[i]
                compare(columns[i].rows.length, 1, "position " + columns[i].position
                    + " has its own window")
                compare(columns[i].rows[0].title, "ws" + columns[i].position,
                    "titled after its own position")
            }
            compare(columns[plan.activeSlot].position, 2, "and the active slot is the destination")
        }

        function test_stripColumns_readTheArrivingFrameWhereBothFramesKnow() {
            // A position both frames describe is read from the ARRIVING one. The two
            // agree on which workspace it is, and the arriving snapshot is the
            // fresher reading of its windows - so a refresh that changes a title
            // reaches the shared column too.
            var leaving = framed(1, 1)
            var arriving = framed(2, 1)
            arriving.previousWindows = [{ windowId: "w1", title: "refreshed",
                appId: "kitty", icon: "", isFocused: true }]
            var columns = Hint.stripColumns(arriving, leaving, Hint.stripPlan(1, 2))
            var shared = -1
            for (var i = 0; i < columns.length; ++i) {
                if (columns[i].position === 1)
                    shared = i
            }
            verify(shared >= 0, "the shared position is on the strip")
            compare(columns[shared].rows[0].title, "refreshed",
                "and it took the arriving frame's reading")
        }

        function test_stripColumns_surviveAMissingOrColdFrame() {
            // A first snapshot has no frame to leave, and a crossing is built from
            // both. Neither may throw, and a column nothing knows about reads as empty
            // rather than being invented.
            var plan = Hint.stripPlan(1, 2)
            var onlyArriving = Hint.stripColumns(framed(2, 1), null, plan)
            compare(onlyArriving.length, plan.slots, "the strip is still the right length")
            // Without the leaving frame the positions only it knew about are empty -
            // honest, because the service has not reported those workspaces yet, and
            // better than a column of invented content.
            var empty = onlyArriving.filter(function(c) { return c.rows.length === 0 })
            compare(empty.length, 1, "and the one the missing frame described is empty")
            compare(empty[0].position, 0, "which was the workspace behind the origin")
            // No frames at all: every column is empty, and none of them throws.
            var nothing = Hint.stripColumns(null, null, plan)
            compare(nothing.length, plan.slots, "still the right length")
            for (var i = 0; i < nothing.length; ++i)
                compare(nothing[i].rows.length, 0, "column " + i + " is empty")
            compare(Hint.stripColumns(framed(2, 1), null, null).length, 0,
                "and no plan means no strip at all")
            // A column beyond what the frames describe - which `stripPlan` refuses to
            // produce - reads as empty rather than throwing.
            var beyond = { base: 0, span: 0, direction: 0, activeSlot: 1, slots: 3,
                startColumn: 0, endColumn: 0 }
            compare(Hint.stripColumns(framed(9, 9), null, beyond)[0].rows.length, 0)
        }

        function test_stripColumns_capEveryColumnAlike() {
            // The cap applies wherever the rows came from - a workspace whose windows
            // are read from the leaving frame is capped exactly like one read from
            // the arriving frame, or the panel's height would depend on which side of
            // the crossing a column happened to come from.
            //
            // Position 1 is deliberately the shared one: it is the arriving frame's
            // previous workspace AND the leaving frame's active one, and the columns
            // either side of it come from opposite frames. So one column exercises the
            // cap applied to a leaving-frame read and another to an arriving-frame
            // read, with the cap the same in both.
            var many = []
            for (var i = 0; i < 8; i++)
                many.push({ windowId: "m" + i, title: "m" + i, isFocused: false })
            var leaving = framed(1, 1)
            // The leaving frame's PREVIOUS workspace, which is position 0 - a column
            // only this frame knows about.
            leaving.previousWindows = many
            var arriving = framed(2, 1)
            // The arriving frame's previous workspace, which is position 1 - the one
            // both frames know.
            arriving.previousWindows = many
            // Its own active workspace, position 2, and its next, position 3, which
            // only it knows about.
            arriving.windows = many
            arriving.nextWindows = many
            var columns = Hint.stripColumns(arriving, leaving, Hint.stripPlan(1, 2))
            var byPosition = {}
            for (var c = 0; c < columns.length; ++c)
                byPosition[columns[c].position] = columns[c]
            // 0 and 2 are read from opposite frames - 0 only from the leaving one, 2
            // only from the arriving one - 3 is the arriving frame's own next
            // workspace, and 1 is the one both know, read from the arriving frame for
            // the reason tested above. The cap is the same in every case.
            for (var position = 0; position <= 3; ++position) {
                compare(byPosition[position].rows.length, Hint.MAX_WINDOW_ROWS,
                    "position " + position + " is capped")
                compare(byPosition[position].hidden, 3,
                    "position " + position + " and reports the rest")
            }
        }

        // ---- what the menu deliberately does not build -------------------
        function test_menuBuildsNoWorkspaceRows() {
            // The bar already reports the active workspace and the window list
            // is countable on screen, so the hint shows neither a workspace
            // index, a workspace name, nor counts. Anyone adding a workspace
            // row back has to add the third copy knowingly.
            verify(Hint.workspaceRows === undefined)
            verify(Hint.identityTitle === undefined)
            verify(Hint.identitySummary === undefined)
        }
    }
}