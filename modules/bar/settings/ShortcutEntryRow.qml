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

    width: parent ? parent.width : ThemeSettings.rowWidth
    visible: height > 0.5 || opacity > 0.01
    opacity: _matchesFilter ? 1 : 0
    height: _matchesFilter ? implicitHeight : 0

    implicitWidth: width
    implicitHeight: Math.round(62 * Theme.uiScale)
    clip: true

    Behavior on height {
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
    }

    Behavior on opacity {
        NumberAnimation { duration: Theme.anim.highlightDuration }
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: ThemeSettings.highlightInset
        anchors.rightMargin: ThemeSettings.highlightInset
        radius: Math.max(6, Math.round(8 * Theme.uiScale))
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.42)
        border.color: fieldInput.activeFocus ? Colors.highlight : Colors.border
        border.width: 1

        Behavior on border.color {
            ColorAnimation { duration: Theme.anim.highlightDuration }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: ThemeSettings.panelPadding
        anchors.rightMargin: ThemeSettings.panelPadding
        spacing: Math.max(6, Math.round(10 * Theme.uiScale))

        Rectangle {
            id: _sourceBadge
            anchors.verticalCenter: parent.verticalCenter
            width: _sourceText.implicitWidth + ThemeSettings.panelPadding
            height: Math.round(18 * Theme.uiScale)
            radius: height / 2
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
            width: Math.max(0, parent.width - _sourceBadge.width - Math.round(160 * Theme.uiScale) - parent.spacing * 2)
            height: parent.height

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: ThemeSettings.pickerDropdownGap

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
            width: Math.round(160 * Theme.uiScale)
            height: Math.round(32 * Theme.uiScale)
            radius: Math.max(4, Math.round(6 * Theme.uiScale))
            color: Colors.background
            border.color: fieldInput.activeFocus ? Colors.highlight : Colors.border
            border.width: 1

            Behavior on border.color {
                ColorAnimation { duration: Theme.anim.highlightDuration }
            }

            TextInput {
                id: fieldInput
                anchors.fill: parent
                anchors.leftMargin: ThemeSettings.pickerPreviewPaddingStart
                anchors.rightMargin: ThemeSettings.pickerPreviewPaddingStart
                anchors.topMargin: Math.max(4, Math.round(5 * Theme.uiScale))
                anchors.bottomMargin: Math.max(4, Math.round(5 * Theme.uiScale))
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
