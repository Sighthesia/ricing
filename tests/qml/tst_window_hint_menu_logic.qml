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

        // ---- how many columns get a slot ----------------------------------
        function test_columnCount_isThreeWhenBothNeighboursHaveWindows() {
            compare(Hint.columnCount(Hint.cappedColumns(makeHint())), 3)
        }

        function test_columnCount_dropsAColumnWithNothingInIt() {
            // A column with no windows is not information, it is a hole in the
            // panel - and a hole reads as a layout fault rather than as "there is
            // nothing over there". So it takes no slot and no space.
            compare(Hint.columnCount(Hint.cappedColumns(
                makeHint({ previousWindows: [] }))), 2)
            compare(Hint.columnCount(Hint.cappedColumns(
                makeHint({ nextWindows: [] }))), 2)
            compare(Hint.columnCount(Hint.cappedColumns(
                makeHint({ previousWindows: [], nextWindows: [] }))), 1)
        }

        function test_columnCount_keepsTheActiveColumnEvenWithNoWindows() {
            // The active workspace always has a slot: the panel is about where you
            // are, and an empty one says so in words. Dropping it would leave a
            // panel about other workspaces with nothing marking the current one.
            var empty = makeHint({
                windows: [], previousWindows: [], nextWindows: []
            })
            compare(Hint.cappedColumns(empty).current.rows.length, 0)
            compare(Hint.columnCount(Hint.cappedColumns(empty)), 1)
            // And it keeps its slot while its neighbours still have windows, so
            // the empty line renders inside a column rather than beside nothing.
            compare(Hint.columnCount(Hint.cappedColumns(makeHint({ windows: [] }))), 3)
        }

        function test_columnCount_isOneForAColdSnapshot() {
            // Nothing is resolved yet, so there is nothing to lay out - but the
            // answer still has to be a number the panel can size itself from.
            compare(Hint.columnCount(Hint.cappedColumns(null)), 1)
            compare(Hint.columnCount(null), 1)
            compare(Hint.columnCount({}), 1)
        }

        function test_columnCount_readsTheCappedRowsNotTheRawList() {
            // The count follows what the cap left on screen, so a neighbour whose
            // only windows were... well, the cap never empties a non-empty list,
            // but the count must not be answerable from a shape the renderer
            // never sees. A half-built object must not count as a column.
            compare(Hint.columnCount({ previous: {}, current: { rows: [] }, next: {} }), 1)
            compare(Hint.columnCount({
                previous: { rows: [1] }, current: { rows: [1] }, next: { rows: [1, 2] }
            }), 3)
        }

        function test_columnWidthIsAFixedColumnSize() {
            // The panel's width is this times the column count, so the two cannot
            // be derived from each other - and a dropped column has to narrow the
            // panel rather than stretch the survivors to fill it.
            compare(Hint.COLUMN_WIDTH, 180)
            // Three is the ceiling the panel can reach, and nothing above it may
            // take a slot. It is also the count the slide distance used to be
            // derived from, which was wrong: the distance has to be the panel's own
            // current width for the two layers to meet exactly.
            compare(Hint.MAX_COLUMNS, 3)
            compare(Hint.MAX_COLUMNS, 1 + 2, "the active column and its two neighbours")
            compare(Hint.columnCount(Hint.cappedColumns(makeHint())), Hint.MAX_COLUMNS,
                "and a full panel reaches it")
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