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

    function check(label, actual, expected) {
        root._checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        failures++
        console.log("FAIL:", label, "expected", expected, "got", actual)
    }

    Component.onCompleted: {
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
        // The menu body reads exactly two things off the snapshot: the
        // workspace id that decides whether the list is renderable at all, and
        // the windows it lists. A rename here would otherwise stay silent - the
        // popup would just open on its "waiting" line, and the only way to see
        // it is to hold a key on a live desktop.
        var menu = Services.WindowHintService.activeHint
        var required = ["workspaceId", "windows"]
        for (var i = 0; i < required.length; i++)
            root.check("snapshot carries " + required[i],
                Object.prototype.hasOwnProperty.call(menu, required[i]), true)

        // The window row the menu renders needs its own activation target and
        // its focus flag; both come straight off each entry.
        var row = menu.windows[0]
        for (var key of ["windowId", "title", "appId", "icon", "isFocused"])
            root.check("window row carries " + key,
                Object.prototype.hasOwnProperty.call(row, key), true)

        console.log("Totals:", root._checks - root.failures, "passed,", root.failures, "failed")
        // Quickshell's Qt.quit() takes no arguments, and it is dropped unless the
        // shell has finished loading — so exit one event-loop turn later.
        Qt.callLater(function() { Qt.quit() })
    }
}
