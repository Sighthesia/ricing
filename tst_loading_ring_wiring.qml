import QtQuick
import Quickshell
import Quickshell.Wayland
import "./modules/bar" as Bar
import "./modules/lazerbar" as LazerBar

// Visual harness for the three places afloat shows the lazer loading ring:
// the launcher's searching state, a Wi-Fi radio rescan, and a Bluetooth scan.
// The two services are faked so the scanning state is reproducible without
// touching real link state — a genuine radio rescan cannot be timed.
//
//   qs -p tst_loading_ring_wiring.qml   → writes /tmp/opencode/wire-*.png

ShellRoot {
    id: root

    property int shots: 0
    property int drained: 0

    // Stands in for NetworkService mid-rescan: radio up, nothing resolved yet.
    QtObject {
        id: fakeNetwork
        property bool wifiAvailable: true
        property bool wifiEnabled: true
        property bool wifiConnected: false
        property bool scanningActive: true
        property bool connecting: false
        property string connectingTo: ""
        property string lastError: ""
        property string lastErrorSsid: ""
        property var networks: ({})
        property bool ethernetAvailable: false
        property bool ethernetConnected: false
        property string activeEthernetConnection: ""
    }

    // Stands in for BluetoothService mid-discovery: adapter on, no devices yet.
    QtObject {
        id: fakeBluetooth
        property bool bluetoothAvailable: true
        property bool enabled: true
        property bool scanningActive: true
        property var devices: ({ values: [] })
    }

    PanelWindow {
        id: probe
        implicitWidth: 300
        implicitHeight: 620
        color: "#18171C"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Ignore

        Item {
            id: host
            objectName: "wireProbe"
            anchors.fill: parent

            // Wi-Fi panel, mid-rescan: the ring rides the foot button's label.
            Bar.BarPopupActions {
                objectName: "networkActions"
                x: 10
                y: 10
                width: 280
                actionKind: "network"
                payload: ({ widgetId: "network", networkService: fakeNetwork })
            }

            // Bluetooth panel, mid-discovery: the ring rides the empty-state line.
            Bar.BarPopupActions {
                objectName: "bluetoothActions"
                x: 10
                y: 300
                width: 280
                actionKind: "bluetooth"
                payload: ({ widgetId: "bluetooth", bluetoothService: fakeBluetooth })
            }

            // Launcher content, searching: 28px ring over the "Searching…" line.
            Rectangle {
                objectName: "launcherFrame"
                x: 10
                y: 470
                width: 280
                height: 140
                color: "#1D1C21"

                LazerBar.LauncherPage {
                    objectName: "launcherProbe"
                    anchors.fill: parent
                    session: ({
                        visible: true,
                        loading: true,
                        error: "",
                        query: "git",
                        mode: "app",
                        results: [],
                        selectedIndex: 0,
                        refresh: function() {},
                        selectNext: function() {},
                        selectPrevious: function() {},
                        executeSelected: function() {},
                        execute: function() {}
                    })
                }
            }
        }
    }

    function indexOfChild(name) {
        for (var i = 0; i < host.children.length; ++i) {
            if (host.children[i].objectName === name)
                return i
        }
        return -1
    }

    Timer {
        interval: 800
        running: true
        repeat: true
        onTriggered: {
            if (root.shots >= 3) {
                if (++root.drained >= 4) {
                    running = false
                    Qt.callLater(Qt.quit)
                }
                return
            }

            // Crop into each surface's own area rather than capturing the whole
            // window, so the ring is legible in the result.
            var targets = [
                { name: "networkActions", x: 0, y: 0, w: 280, h: 290 },
                { name: "bluetoothActions", x: 0, y: 0, w: 280, h: 170 },
                { name: "launcherFrame", x: 0, y: 0, w: 280, h: 140 }
            ]
            var spec = targets[root.shots]
            var item = host.children[root.indexOfChild(spec.name)]
            if (!item) {
                console.warn("[wire] missing " + spec.name)
                root.shots++
                return
            }

            item.grabToImage(function(result) {
                if (!result || !result.image) {
                    console.warn("[wire] grab failed for " + spec.name)
                    return
                }
                var path = "/tmp/opencode/wire-" + spec.name + ".png"
                console.warn("[wire] " + spec.name + " saved=" + result.saveToFile(path) + " -> " + path)
            })
            root.shots++
        }
    }
}
