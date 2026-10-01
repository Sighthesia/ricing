import QtQuick
import "./services" as Services

// Headless harness for the mod-key window hint's data path: the service has to
// turn niri's workspace/window models into a snapshot the menu can render, and
// it has to survive a release without dropping the data the exit reveal reads.
//
// The rendered body is covered by tests/qml/tst_window_hint_content.qml, and
// the layer-shell wiring by the window-only tst_bar_popup_host, so nothing here
// opens a surface.
Item {
    id: root

    property int failures: 0
    property int _checks: 0

    // An exception thrown mid-run used to leave the harness hanging until the
    // runner's timeout, which reads as "the suite is slow" rather than "this
    // assertion is wrong" - and a timeout is a much weaker signal than a named
    // failure. Every check goes through here instead, so a throw is reported as
    // a failure and the shell still quits.
    function fail(label, detail) {
        failures++
        console.log("FAIL:", label, detail)
    }

    function check(label, actual, expected) {
        root._checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        root.fail(label, "expected", expected, "got", actual)
    }

    // All of it in a function rather than straight in Component.onCompleted, so
    // the try/catch below can actually cover the run.
    function run() {
        // --- niri-shaped model updates -----------------------------------
        Services.NiriService.updateWorkspaces({
            workspaces: [
                { id: 1, idx: 1, is_active: false, name: "" },
                { id: 2, idx: 2, is_active: true, name: "" },
                { id: 3, idx: 3, is_active: false, name: "" }
            ]
        })
        Services.NiriService.updateWindows({
            WindowsChanged: { windows: [
                { id: 11, title: "kitty", app_id: "kitty", is_focused: true, workspace_id: 2 },
                { id: 12, title: "firefox", app_id: "firefox", is_focused: false, workspace_id: 2 }
            ] }
        })
        // A window on each neighbour, so the snapshot's side columns have
        // something to resolve. The panel shows the workspaces either side of
        // the active one, which only works if the service resolves them.
        Services.NiriService.updateWindows({
            WindowsChanged: { windows: [
                { id: 11, title: "kitty", app_id: "kitty", is_focused: true, workspace_id: 2 },
                { id: 12, title: "firefox", app_id: "firefox", is_focused: false, workspace_id: 2 },
                { id: 21, title: "prev only", app_id: "foot", is_focused: false, workspace_id: 1 },
                { id: 31, title: "next only", app_id: "mpv", is_focused: false, workspace_id: 3 }
            ] }
        })

        // --- the hold ----------------------------------------------------
        // setHintHeld is exactly what the key bridge drives. Calling it here
        // keeps the harness from spawning the evdev reader.
        Services.WindowHintService.setHintHeld(true)
        var hint = Services.WindowHintService.activeHint
        root.check("hold resolves the active workspace", String(hint.workspaceId), "2")
        root.check("hold resolves the workspace index", hint.workspaceIndex, 2)
        root.check("hold lists the active workspace's windows", hint.windows.length, 2)
        root.check("hold lists every workspace", hint.workspaces.length, 3)
        root.check("hold marks the focused window", hint.windows[0].isFocused, true)

        // --- the side columns ----------------------------------------------
        // The panel renders three columns, and only the middle one is the active
        // workspace. The two neighbours are resolved here, by position in the
        // workspace list - so the view never has to reach into NiriService, and
        // a change to either contract has to be made twice otherwise.
        root.check("hold lists the previous workspace's windows",
            hint.previousWindows.length, 1)
        root.check("hold picks the right previous window",
            String(hint.previousWindows[0].windowId), "21")
        root.check("hold lists the next workspace's windows",
            hint.nextWindows.length, 1)
        root.check("hold picks the right next window",
            String(hint.nextWindows[0].windowId), "31")
        // Nothing in a neighbour is ever focused - focus is on the active
        // workspace - so a neighbour must not claim a focused window.
        root.check("the previous column carries no focus",
            hint.previousWindows[0].isFocused, false)
        root.check("the next column carries no focus",
            hint.nextWindows[0].isFocused, false)

        // --- the first and last workspace have no neighbour ----------------
        // On the first workspace there is nothing before it, and the honest
        // answer is an empty column. Wrapping around would label the column with
        // a workspace the user cannot see.
        Services.NiriService.updateWorkspaces({
            workspaces: [
                { id: 1, idx: 1, is_active: true, name: "" },
                { id: 2, idx: 2, is_active: false, name: "" },
                { id: 3, idx: 3, is_active: false, name: "" }
            ]
        })
        Services.WindowHintService.setHintHeld(false)
        Services.WindowHintService.setHintHeld(true)
        var atStart = Services.WindowHintService.activeHint
        root.check("the first workspace has no previous column",
            atStart.previousWindows.length, 0)
        // Two windows, because the next workspace is the one that carried the
        // pair - a count of one here would mean the service had resolved the
        // wrong workspace rather than reporting a short list.
        root.check("the first workspace still has a next column",
            atStart.nextWindows.length, 2)
        Services.NiriService.updateWorkspaces({
            workspaces: [
                { id: 1, idx: 1, is_active: false, name: "" },
                { id: 2, idx: 2, is_active: false, name: "" },
                { id: 3, idx: 3, is_active: true, name: "" }
            ]
        })
        Services.WindowHintService.setHintHeld(false)
        Services.WindowHintService.setHintHeld(true)
        var atEnd = Services.WindowHintService.activeHint
        root.check("the last workspace has no next column",
            atEnd.nextWindows.length, 0)
        root.check("the last workspace still has a previous column",
            atEnd.previousWindows.length, 2)
        // Back to the middle workspace for the release assertions below.
        Services.NiriService.updateWorkspaces({
            workspaces: [
                { id: 1, idx: 1, is_active: false, name: "" },
                { id: 2, idx: 2, is_active: true, name: "" },
                { id: 3, idx: 3, is_active: false, name: "" }
            ]
        })
        Services.WindowHintService.setHintHeld(false)
        Services.WindowHintService.setHintHeld(true)

        // --- release ------------------------------------------------------
        // The popup's exit reveal still reads activeHint, so a release must
        // not clear it; only the service's own hintHeld gate moves.
        Services.WindowHintService.setHintHeld(false)
        root.check("release keeps the snapshot for the exit reveal",
            String(Services.WindowHintService.activeHint.workspaceId), "2")
        root.check("release drops the hold", Services.WindowHintService.hintHeld, false)
        root.check("release drops the visible gate",
            Services.WindowHintService.hintVisible, false)

        // --- re-hold ------------------------------------------------------
        // A second press has to refresh, not go stale on the first snapshot.
        Services.NiriService.updateWindows({
            WindowsChanged: { windows: [
                { id: 11, title: "kitty", app_id: "kitty", is_focused: true, workspace_id: 2 }
            ] }
        })
        Services.WindowHintService.setHintHeld(true)
        root.check("re-hold refreshes the window list",
            Services.WindowHintService.activeHint.windows.length, 1)
        Services.WindowHintService.setHintHeld(false)

        // --- snapshot contract --------------------------------------------
        // The menu body reads the workspace id that decides whether the list is
        // renderable at all, plus the three window lists. A rename here would
        // otherwise stay silent - the popup would just open on its "waiting"
        // line, and the only way to see it is to hold a key on a live desktop.
        var menu = Services.WindowHintService.activeHint
        var required = ["workspaceId", "windows", "previousWindows", "nextWindows"]
        for (var i = 0; i < required.length; i++)
            root.check("snapshot carries " + required[i],
                Object.prototype.hasOwnProperty.call(menu, required[i]), true)

        // The window row the menu renders needs its own activation target and
        // its focus flag; both come straight off each entry.
        var row = menu.windows[0]
        for (var key of ["windowId", "title", "appId", "icon", "isFocused"])
            root.check("window row carries " + key,
                Object.prototype.hasOwnProperty.call(row, key), true)
    }

    Component.onCompleted: {
        try {
            root.run()
        } catch (error) {
            // A throw used to skip the totals AND the quit, so the harness ran
            // to the runner's timeout and reported a timeout instead of the
            // assertion that actually broke.
            root.fail("harness threw", String(error), error && error.stack ? error.stack : "")
        }
        console.log("Totals:", root._checks - root.failures, "passed,", root.failures, "failed")
        // Quickshell's Qt.quit() takes no arguments, and it is dropped unless the
        // shell has finished loading — so exit one event-loop turn later.
        Qt.callLater(function() { Qt.quit() })
    }
}
