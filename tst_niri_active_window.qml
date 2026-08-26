import QtQuick
import "./services" as Services

// Regression harness for active-window title propagation. It exercises the
// same ListModel updates used by NiriService's event stream.
Item {
    id: root

    property int failures: 0
    property string observedTitle: Services.NiriService.activeTitle

    function check(label, actual, expected) {
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        failures++
        console.log("FAIL:", label, "expected", expected, "got", actual)
    }

    Component.onCompleted: {
        Services.NiriService.updateWindows({
            WindowsChanged: { windows: [
            { id: 101, title: "workspace-one", app_id: "app.one", is_focused: true, workspace_id: 1 },
            { id: 202, title: "workspace-two", app_id: "app.two", is_focused: false, workspace_id: 2 }
            ] }
        })
        root.check("initial active title", Services.NiriService.activeTitle, "workspace-one")

        Services.NiriService.setFocusedWindow(202)
        root.check("window focus updates title", Services.NiriService.activeTitle, "workspace-two")
        root.check("window focus invalidates title binding", root.observedTitle, "workspace-two")

        Services.NiriService.activateWorkspace({ id: 1 })
        root.check("workspace activation keeps current title", Services.NiriService.activeTitle, "workspace-two")

        Qt.quit(root.failures === 0 ? 0 : 1)
    }
}
