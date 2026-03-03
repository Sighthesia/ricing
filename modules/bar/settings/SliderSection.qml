import QtQuick
import qs.config

// A labeled slider row bound to an external real value via signal.
//
// Usage:
//   SliderSection {
//     label: "高度"
//     value: SettingsService.data.bar.height
//     from: 24; to: 60; stepSize: 1; unit: "px"
//     onValueCommitted: SettingsService.data.bar.height = newValue
//   }
Item {
    id: root

    // - label: display text on the left
    // - value: current value to reflect (read-only binding)
    // - from/to/stepSize: range and granularity
    // - unit: optional suffix string shown after the number
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property string unit: ""

    // Fired on every drag tick (allows live preview)
    signal valueCommitted(real newValue)

    implicitWidth: 296
    implicitHeight: 32

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        // Label
        Text {
            width: 60
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
            elide: Text.ElideRight
        }

        // Slider track + handle
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 60 - 44 - 2 * parent.spacing
            height: 20   // tall hit area around the 4px visual track

            // Visual track (unfilled)
            Rectangle {
                id: track
                width: parent.width
                height: 4
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: Colors.surface
            }

            // Filled portion up to handle center
            Rectangle {
                height: 4
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: Colors.highlight
                width: {
                    let ratio = (root.value - root.from) / (root.to - root.from)
                    return Math.max(handle.width / 2, ratio * track.width)
                }
            }

            // Draggable knob
            Rectangle {
                id: handle
                width: 14; height: 14
                radius: 7
                color: Colors.highlight
                anchors.verticalCenter: parent.verticalCenter
                x: {
                    let ratio = (root.value - root.from) / (root.to - root.from)
                    return ratio * (track.width - width)
                }

                MouseArea {
                    anchors.fill: parent
                    drag.target: parent
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: track.width - handle.width
                    cursorShape: Qt.SizeHorCursor
                    onPositionChanged: {
                        if (drag.active) {
                            let ratio = handle.x / (track.width - handle.width)
                            let rawVal = root.from + ratio * (root.to - root.from)
                            let stepped = Math.round(rawVal / root.stepSize) * root.stepSize
                            let clamped = Math.max(root.from, Math.min(root.to, stepped))
                            root.valueCommitted(parseFloat(clamped.toFixed(10)))
                        }
                    }
                }
            }
        }

        // Numeric readout
        Text {
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            text: root.value.toFixed(root.stepSize < 1 ? 2 : 0) + root.unit
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.text
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideNone
        }
    }
}
