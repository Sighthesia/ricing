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
    property bool shown: true
    // Fired when the user commits a new value (Enter key or focus lost)
    signal valueCommitted(string newValue)
    signal textEdited(string newValue)

    // When non-empty, this item shows only if its label matches the query.
    property string filterQuery: ""

    readonly property bool _matchesFilter: filterQuery === "" ||
        label.toLowerCase().indexOf(filterQuery.toLowerCase()) !== -1

    readonly property bool searchHighlight: filterQuery !== "" && _matchesFilter

    visible: _matchesFilter && shown
    height: (_matchesFilter && shown) ? implicitHeight : 0
    opacity: 1

    implicitWidth: ThemeSettings.rowWidth
    implicitHeight: ThemeSettings.rowHeight

    // Search match highlight background
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: ThemeSettings.highlightInset
        anchors.rightMargin: ThemeSettings.highlightInset
        radius: ThemeSettings.highlightRadius
        color: Colors.highlight
        opacity: root.searchHighlight ? 0.1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
    }

    // Accent left-edge strip
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: ThemeSettings.highlightInset }
        width: ThemeSettings.accentStripWidth
        radius: ThemeSettings.accentStripRadius
        color: Colors.highlight
        opacity: root.searchHighlight ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: ThemeSettings.panelPadding
        anchors.rightMargin: ThemeSettings.panelPadding
        spacing: ThemeSettings.rowGap

        // Label
        Text {
            width: ThemeSettings.labelWidth
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
            width: parent.width - ThemeSettings.labelWidth - parent.spacing
            height: parent.height - ThemeSettings.fieldVerticalInset
            radius: ThemeSettings.fieldRadius
            color: Colors.surface
            border.color: fieldInput.activeFocus ? Colors.highlight : Colors.border
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

            TextInput {
                id: fieldInput
                anchors.fill: parent
                anchors.leftMargin: ThemeSettings.fieldPaddingH
                anchors.rightMargin: ThemeSettings.fieldPaddingH
                anchors.topMargin: ThemeSettings.fieldPaddingV
                anchors.bottomMargin: ThemeSettings.fieldPaddingV
                text: root.value
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.text
                selectByMouse: true
                enabled: root.enabled
                clip: true
                HoverHandler { cursorShape: Qt.IBeamCursor }

                onTextEdited: root.textEdited(text)

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
