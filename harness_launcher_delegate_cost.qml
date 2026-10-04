import QtQuick

// The launcher page sizes its row window to the results that exist, and a
// Repeater rebuilds every delegate when its count changes. So a window that
// grows as batches land pays for the same rows two or three times over. This
// compares the two shapes on the same 96-slot window:
//
//   grow  - model follows the result count: 24 -> 88 -> 96
//   fixed - model stays at the window limit, empty slots collapse, batches
//           swap row content in place
Item {
    id: root
    width: 800
    height: 600
    property string mode: "fixed"
    property int available: 0
    property int limit: 96
    property var report: []

    function nowMs() { return new Date().getTime() }

    Column {
        id: column
        width: parent.width
        Repeater {
            id: rep
            model: root.mode === "grow" ? root.available : (root.started ? root.limit : 0)
            delegate: RowProbe {
                required property int index
                width: column.width
                payload: root.mode === "grow" || index < root.available
                        ? "row-" + index + "@" + root.available : ""
            }
        }
    }

    function availableChildren() {
        var live = 0
        for (var i = 0; i < column.children.length; i++)
            if (column.children[i].payload !== undefined && column.children[i].payload !== "")
                live++
        return live
    }

    // The growth shape a 750-row clipboard open produces: 24, 88, 96.
    property var plan: [24, 88, 96]
    property int step: -1
    property bool started: false

    Timer {
        id: driver
        interval: 60
        repeat: false
        onTriggered: root.advance()
    }

    function advance() {
        var before = nowMs()
        if (root.step < 0) {
            root.step = 0
            root.started = true
        } else {
            root.available = root.plan[root.step]
            root.step++
        }
        column.children.length
        Qt.callLater(function() {
            root.report.push((root.mode === "grow" ? "grow" : "fixed")
                    + " " + root.available + ": " + (nowMs() - before)
                    + "ms (" + availableChildren() + " live rows)")
            if (root.step >= root.plan.length) {
                console.log("[probe] " + root.report.join(" | "))
                Qt.callLater(function() { Qt.quit() })
                return
            }
            driver.restart()
        })
    }

    Component.onCompleted: driver.restart()

    // Stands in for a launcher result row: a card, an image, two texts and
    // three handlers, collapsed to nothing when it has no content.
    component RowProbe: Item {
        property string payload
        width: 480
        height: payload === "" ? 0 : 72
        implicitHeight: height
        visible: payload !== ""
        enabled: payload !== ""
        Rectangle { anchors.fill: parent; color: "#223"; visible: payload !== "" }
        Image { source: "image://icons/folder"; width: 32; height: 32; visible: payload !== "" }
        Text { text: payload; color: "white"; visible: payload !== "" }
        Text { text: payload + " description"; color: "#888"; visible: payload !== "" }
        HoverHandler { id: h1; enabled: payload !== "" }
        TapHandler { id: h2; enabled: payload !== "" }
        DragHandler { id: h3; enabled: payload !== "" }
    }
}
