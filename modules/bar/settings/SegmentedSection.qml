import QtQuick
import qs.config
import qs.services

// A labeled segmented control row for compact enum-like settings.
Item {
    id: root

    property string label: ""
    property var currentValue: ""
    property var options: []
    property string filterQuery: ""
    property bool shown: true
    signal optionSelected(var value)

    readonly property bool _matchesFilter: {
        if (filterQuery === "")
            return true

        const query = filterQuery.toLowerCase()
        if (label.toLowerCase().indexOf(query) !== -1)
            return true

        for (let index = 0; index < options.length; index++) {
            const option = options[index]
            if (option && String(option.label || "").toLowerCase().indexOf(query) !== -1)
                return true
        }

        return false
    }
    readonly property int _filterOrder: {
        if (!parent || !parent.children)
            return 0

        for (let index = 0; index < parent.children.length; index++) {
            if (parent.children[index] === root)
                return index
        }

        return 0
    }
    readonly property int _filterDelay: _filterOrder * SettingsService.effectiveAnimation.staggerExitStep
    readonly property bool searchHighlight: filterQuery !== "" && _matchesFilter

    visible: height > 0.5 || opacity > 0.01
    opacity: (_matchesFilter && shown) ? (enabled ? 1 : 0.55) : 0
    height: (_matchesFilter && shown) ? implicitHeight : 0

    implicitWidth: 296
    implicitHeight: Theme.settingsRowHeight
    clip: true

    Behavior on height {
        SequentialAnimation {
            PauseAnimation { duration: root._filterDelay }
            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
        }
    }

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root._filterDelay }
            NumberAnimation { duration: Theme.anim.highlightDuration }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        radius: 4
        color: Colors.highlight
        opacity: root.searchHighlight ? 0.1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.highlightDuration }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 4
        width: 3
        radius: 1
        color: Colors.highlight
        opacity: root.searchHighlight ? 0.9 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.highlightDuration }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.settingsPanelPadding
        anchors.rightMargin: Theme.settingsPanelPadding
        spacing: 8

        Text {
            width: Theme.settingsLabelWidth
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
            elide: Text.ElideRight
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(120, _segmentsRow.implicitWidth + 4)
            height: 28
            radius: 14
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.72)
            border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.72)
            border.width: 1

            Row {
                id: _segmentsRow
                anchors.fill: parent
                anchors.margins: 2
                spacing: 2

                Repeater {
                    model: root.options

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool _selected: root.currentValue === modelData.value

                        width: Math.max(48, _segmentLabel.implicitWidth + 18)
                        height: parent.height
                        radius: height / 2
                        color: _selected
                            ? Colors.highlight
                            : Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, _segmentArea.containsMouse ? 0.16 : 0.08)

                        Behavior on color {
                            ColorAnimation { duration: Theme.anim.highlightDuration }
                        }

                        Text {
                            id: _segmentLabel
                            anchors.centerIn: parent
                            text: modelData.label || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: _selected ? Font.Medium : Font.Normal
                            color: _selected ? Colors.background : Colors.textMuted
                        }

                        MouseArea {
                            id: _segmentArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.enabled
                            onClicked: root.optionSelected(modelData.value)
                        }
                    }
                }
            }
        }
    }
}
