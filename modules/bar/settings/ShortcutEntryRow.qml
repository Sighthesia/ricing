import QtQuick
import qs.config

Item {
    id: root

    property string shortcutLabel: ""
    property string shortcutDetail: ""
    property string shortcutSequence: ""
    property string filterQuery: ""
    property bool shellOwned: false

    signal sequenceCommitted(string newSequence)

    readonly property bool _matchesFilter: {
        if (filterQuery === "")
            return true

        const query = filterQuery.toLowerCase()
        return shortcutLabel.toLowerCase().indexOf(query) !== -1
            || shortcutDetail.toLowerCase().indexOf(query) !== -1
            || shortcutSequence.toLowerCase().indexOf(query) !== -1
    }

    width: parent ? parent.width : 296
    visible: height > 0.5 || opacity > 0.01
    opacity: _matchesFilter ? 1 : 0
    height: _matchesFilter ? implicitHeight : 0

    implicitWidth: width
    implicitHeight: 62
    clip: true

    Behavior on height {
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
    }

    Behavior on opacity {
        NumberAnimation { duration: Theme.anim.highlightDuration }
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        radius: 8
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.42)
        border.color: fieldInput.activeFocus ? Colors.highlight : Colors.border
        border.width: 1

        Behavior on border.color {
            ColorAnimation { duration: Theme.anim.highlightDuration }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.settingsPanelPadding
        anchors.rightMargin: Theme.settingsPanelPadding
        spacing: 10

        Rectangle {
            id: _sourceBadge
            anchors.verticalCenter: parent.verticalCenter
            width: _sourceText.implicitWidth + 12
            height: 18
            radius: 9
            color: root.shellOwned
                ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.18)
                : Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.24)
            border.color: root.shellOwned ? Colors.highlight : Colors.border
            border.width: 1

            Text {
                id: _sourceText
                anchors.centerIn: parent
                text: root.shellOwned ? "Shell" : "Niri"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall - 2
                color: root.shellOwned ? Colors.highlight : Colors.textMuted
            }
        }

        Item {
            width: Math.max(0, parent.width - _sourceBadge.width - 160 - parent.spacing * 2)
            height: parent.height

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 4

                Text {
                    width: parent.width
                    text: root.shortcutLabel
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Colors.text
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.shortcutDetail
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Colors.textMuted
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 160
            height: 32
            radius: 6
            color: Colors.background
            border.color: fieldInput.activeFocus ? Colors.highlight : Colors.border
            border.width: 1

            Behavior on border.color {
                ColorAnimation { duration: Theme.anim.highlightDuration }
            }

            TextInput {
                id: fieldInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 5
                anchors.bottomMargin: 5
                text: root.shortcutSequence
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.text
                selectByMouse: true
                clip: true

                onEditingFinished: {
                    const trimmed = text.trim()
                    if (trimmed === "") {
                        text = root.shortcutSequence
                        return
                    }

                    root.sequenceCommitted(trimmed)
                }

                onActiveFocusChanged: {
                    if (!activeFocus)
                        text = root.shortcutSequence
                }
            }
        }
    }
}
