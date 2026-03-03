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

    // When non-empty, this item shows only if its label matches the query,
    // otherwise it hides itself (height=0) so the parent Column skips it.
    property string filterQuery: ""

    readonly property bool _matchesFilter: filterQuery === "" ||
        label.toLowerCase().indexOf(filterQuery.toLowerCase()) !== -1

    // Show a subtle accent tint when this item matches an active search.
    readonly property bool searchHighlight: filterQuery !== "" && _matchesFilter

    visible: _matchesFilter
    height: _matchesFilter ? implicitHeight : 0

    implicitWidth: 296
    implicitHeight: Theme.settingsRowHeight

    // Search match highlight background
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 4; anchors.rightMargin: 4
        radius: 4
        color: Colors.highlight
        opacity: root.searchHighlight ? 0.1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
    }

    // Accent left-edge strip
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 4 }
        width: 3
        radius: 1
        color: Colors.highlight
        opacity: root.searchHighlight ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.settingsPanelPadding
        anchors.rightMargin: Theme.settingsPanelPadding
        spacing: 8

        // Label
        Text {
            width: Theme.settingsLabelWidth
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
            width: parent.width - Theme.settingsLabelWidth - 44 - 2 * parent.spacing
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
