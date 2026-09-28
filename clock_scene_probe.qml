import QtQuick
import Quickshell
import "modules/lazerbar" as LazerBar
import "modules/bar" as Bar
import "modules/lock" as LockModule
import "services" as Services

// Probe: clock widget via Loader (production path) plus the clock popup
// actions body, catching scene warnings for the restored hover card.
Item {
    width: 600
    height: 900

    Loader {
        id: clockLoader
        anchors.top: parent.top
        source: Qt.resolvedUrl("modules/bar/widgets/Clock.qml")
        onStatusChanged: console.log("clockLoader status=" + status)
    }

    Bar.BarPopupActions {
        anchors.top: clockLoader.bottom
        actionKind: "clock"
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: Qt.quit()
    }
}
