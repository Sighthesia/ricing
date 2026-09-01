import QtQuick
import "../lazerbar"

// Settings-panel slider row, optionally followed by a mute toggle row.
Item {
    id: root

    property real value: 0.5
    property bool muted: false
    property string label: ""
    property bool showMute: true

    signal valueCommitted(real value)
    signal toggleRequested()

    readonly property real clampedValue: Math.max(0, Math.min(1, Number(root.value) || 0))
    readonly property bool effectiveMuted: !!root.muted
    readonly property alias sliderRow: sliderRow
    readonly property alias sliderControl: sliderControl
    readonly property alias muteRow: muteRow
    readonly property alias muteToggle: muteToggle

    implicitWidth: 244
    implicitHeight: sliderRow.height + (root.showMute ? muteRow.height : 0)
    width: implicitWidth
    height: implicitHeight

    // Volume or brightness value uses the same split settings slider card.
    LazerSettingsRow {
        id: sliderRow
        objectName: "sliderRow"
        width: parent.width
        labelText: root.label
        currentValue: Math.round(root.clampedValue * 100)

        LazerSettingsSlider {
            id: sliderControl
            objectName: "sliderControl"
            from: 0
            to: 100
            stepSize: 1
            suffix: "%"
            value: Math.round(root.clampedValue * 100)
            onValueModified: function(next) {
                root.valueCommitted(Math.max(0, Math.min(1, Number(next) / 100)))
            }
        }
    }

    // Mute stays a settings toggle card so volume matches the panel language.
    LazerSettingsRow {
        id: muteRow
        objectName: "sliderMuteRow"
        width: parent.width
        y: sliderRow.height
        visible: root.showMute
        height: root.showMute ? implicitHeight + listGap : 0
        labelText: "Mute"
        currentValue: root.effectiveMuted

        LazerSettingsToggle {
            id: muteToggle
            objectName: "sliderMuteButton"
            checked: root.effectiveMuted
            onToggled: root.toggleRequested()
        }
    }
}
