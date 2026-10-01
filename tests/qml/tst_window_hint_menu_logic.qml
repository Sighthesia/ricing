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