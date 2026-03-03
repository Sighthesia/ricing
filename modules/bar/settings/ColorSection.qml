import QtQuick
import qs.config

// A labeled color row with a preview swatch and hex text input.
//
// Usage:
//   ColorSection {
//     label: "强调色"
//     value: SettingsService.data.appearance.accentColor
//     onValueCommitted: SettingsService.data.appearance.accentColor = newValue
//   }
Item {
    id: root

    property string label: ""
    property string value: "#ffffff"

    // Fired when user confirms a valid hex color (Enter key or focus lost)
    signal valueCommitted(string newValue)

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
        // Accepts only #RRGGBB (case-insensitive)
    function isValidHex(s) {
        return /^#[0-9a-fA-F]{6}$/.test(s)
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

        // Color preview swatch
        Rectangle {
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: root.isValidHex(root.value) ? root.value : "#ffffff"
            border.color: Colors.border
            border.width: 1
        }

        // Hex text input field
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 100; height: 26
            radius: 4
            color: Colors.surface
            border.color: hexInput.activeFocus ? Colors.highlight : Colors.border
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

            TextInput {
                id: hexInput
                anchors.fill: parent
                anchors.margins: 4
                text: root.value.toUpperCase()
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.text
                maximumLength: 7
                selectByMouse: true

                onEditingFinished: {
                    // Normalize: prepend # if missing
                    let v = text.startsWith("#") ? text : "#" + text
                    if (root.isValidHex(v)) {
                        root.valueCommitted(v.toLowerCase())
                    } else {
                        // Invalid input: revert display to current value
                        text = root.value.toUpperCase()
                    }
                }

                // Keep display in sync when external value changes
                onActiveFocusChanged: {
                    if (!activeFocus) text = root.value.toUpperCase()
                }
            }
        }
    }
}
