import QtQuick
import qs.config

// A labeled free-text input row for string settings (e.g., font family names).
//
// Usage:
//   TextFieldSection {
//     label: "字体"
//     value: SettingsService.data.appearance.fontFamily
//     onValueCommitted: SettingsService.data.appearance.fontFamily = newValue
//   }
Item {
    id: root

    property string label: ""
    property string value: ""

    // Fired when the user commits a new value (Enter key or focus lost)
    signal valueCommitted(string newValue)

    // When non-empty, this item shows only if its label matches the query.
    property string filterQuery: ""

    readonly property bool _matchesFilter: filterQuery === "" ||
        label.toLowerCase().indexOf(filterQuery.toLowerCase()) !== -1

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

        // Text input field
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.settingsLabelWidth - parent.spacing
            height: parent.height - 8
            radius: 4
            color: Colors.surface
            border.color: fieldInput.activeFocus ? Colors.highlight : Colors.border
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

            TextInput {
                id: fieldInput
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                text: root.value
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.text
                selectByMouse: true
                clip: true
                HoverHandler { cursorShape: Qt.IBeamCursor }

                onEditingFinished: {
                    let trimmed = text.trim()
                    if (trimmed !== "") {
                        root.valueCommitted(trimmed)
                    } else {
                        // Revert to current value on empty input
                        text = root.value
                    }
                }

                // Keep display in sync when external value changes
                onActiveFocusChanged: {
                    if (!activeFocus) text = root.value
                }
            }
        }
    }
}
