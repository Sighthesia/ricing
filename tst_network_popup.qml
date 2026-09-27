import QtQuick
import Quickshell
import Quickshell.Wayland
import "./modules/bar" as Bar
import "./modules/lazerbar" as LazerBar
import "./services" as Services

// Popup-only smoke harness: mounts the real bar and forces the network popup
// open so the Wi-Fi panel is laid out and painted for real, with no pointer.
// Reports row metrics the way the user sees them (and any QML warning the
// panel produces) without touching link state.
//
//   qs -p tst_network_popup.qml

ShellRoot {
    id: root

    property int failures: 0
    property int phase: 0

    function check(label, condition, detail) {
        if (condition)
            console.log("PASS: " + label + (detail !== undefined ? "  [" + detail + "]" : ""))
        else {
            failures++
            console.log("FAIL: " + label + (detail !== undefined ? "  [" + detail + "]" : ""))
        }
    }

    PanelWindow {
        id: probe
        implicitWidth: 300
        implicitHeight: 520
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Ignore

        Item {
            id: host
            objectName: "networkPopupProbe"
            anchors.fill: parent

            Bar.BarPopupActions {
                id: actions
                objectName: "probeActions"
                width: 260
                actionKind: "network"
                payload: ({
                    widgetId: "network",
                    networkService: Services.NetworkService
                })
            }
        }
    }

    Component.onCompleted: {
        Services.NetworkService.refreshForOpen()
    }

    Timer {
        interval: 200
        repeat: true
        running: root.phase < 3
        onTriggered: {
            // Wait for the refresh-on-open scan to actually land, otherwise
            // the probe measures an empty list and proves nothing.
            if (root.phase === 0) {
                var svc = Services.NetworkService
                if (svc.scanningActive || Object.keys(svc.networks).length === 0)
                    return
                root.phase = 1
                root.reportLayout()
                return
            }
            root.phase = 3
            console.log("Totals: " + (root.failures === 0 ? "PASS" : root.failures + " FAILED"))
            Qt.quit()
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

    function reportLayout() {
        var content = root.findByName(actions, "networkContent")
        check("network panel is laid out", !!content, "visible=" + (content ? content.visible : "n/a"))
        if (!content) {
            root.phase = 3
            return
        }
        var list = root.findByName(actions, "wifiListView")
        var svc = Services.NetworkService
        var count = svc.networks ? Object.keys(svc.networks).length : 0
        console.log("--- panel ---")
        console.log("networks=" + count
            + " scanning=" + svc.scanningActive
            + " panelHeight=" + Math.round(actions.height)
            + " listHeight=" + (list ? Math.round(list.height) : "n/a")
            + " listContent=" + (list ? Math.round(list.contentHeight) : "n/a")
            + " interactive=" + (list ? list.interactive : "n/a"))
        check("list is present", !!list)
        if (list) {
            check("list viewport is bounded", list.height <= 5 * 36 + 4 * 6,
                "h=" + Math.round(list.height))
            check("list scrolls only when it overflows",
                list.interactive === (list.contentHeight > list.height),
                "content=" + Math.round(list.contentHeight) + " view=" + Math.round(list.height))
            check("every network is reachable", list.count === count,
                "model=" + list.count + " service=" + count)
        }
        var rescan = root.findByName(actions, "wifiRescanButton")
        check("rescan affordance present", !!rescan && rescan.visible)
        check("rescan sits below the list", !!rescan && !!list && rescan.y > list.y,
            "rescan.y=" + Math.round(rescan.y) + " list.y=" + Math.round(list.y))
        check("no centered status line", root.findByName(actions, "wifiStatusText") === null)
        check("panel opened into a live list", count > 0, "networks=" + count)
    }
}
