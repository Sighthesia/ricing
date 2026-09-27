import QtQuick
import Quickshell
import Quickshell.Wayland
import "./modules/bar" as Bar
import "./services" as Services

// Screenshot harness: paints the real network popup over a mid-tone backdrop
// so the panel's geometry and the bounded scrollable list can be eyeballed
// after the refresh/connect rework. Read-only; changes no link state.
//
//   qs -p tst_network_visual.qml   → writes /tmp/opencode/netpop-*.png

ShellRoot {
    id: root

    property int shots: 0

    PanelWindow {
        id: probe
        implicitWidth: 300
        implicitHeight: 460
        color: "#2b3038"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Ignore

        // grabToImage lives on Item, not on a layer-shell surface, so the
        // panel is duplicated into a plain item for the capture.
        Item {
            id: shot
            objectName: "shotTarget"
            width: 300
            height: 460

            Rectangle {
                anchors.fill: parent
                color: "#2b3038"
            }

            Bar.BarPopupActions {
                id: actions
                objectName: "probeActions"
                x: 20
                y: 12
                width: 260
                actionKind: "network"
                payload: ({
                    widgetId: "network",
                    networkService: Services.NetworkService
                })
            }
        }
    }

    Component.onCompleted: Services.NetworkService.refreshForOpen()

    function grab(name) {
        shot.grabToImage(function (result) {
            result.saveToFile("/tmp/opencode/" + name + ".png")
            console.log("saved /tmp/opencode/" + name + ".png")
        })
    }

    Timer {
        interval: 300
        repeat: true
        running: root.shots < 2
        onTriggered: {
            var svc = Services.NetworkService
            if (root.shots === 0) {
                if (svc.scanningActive || Object.keys(svc.networks).length === 0)
                    return
                root.shots = 1
                root.grab("netpop-live")
                return
            }
            if (root.shots === 1) {
                root.shots = 2
                root.grab("netpop-scrolled")
                // Park the list mid-scroll so the capture proves the rows
                // beyond the first five are genuinely reachable.
                var list = root.findByName(actions, "wifiListView")
                if (list)
                    list.contentY = Math.min(120, Math.max(0, list.contentHeight - list.height))
                return
            }
        }
    }

    function findByName(item, name) {
        if (!item)
            return null
        if (item.objectName === name)
            return item
        var kids = item.children
        for (var i = 0; i < kids.length; i++) {
            var hit = root.findByName(kids[i], name)
            if (hit)
                return hit
        }
        return null
    }

    Timer {
        interval: 20000
        repeat: false
        running: true
        onTriggered: Qt.quit()
    }
}
