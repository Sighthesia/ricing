import QtQuick
import qs.config
import qs.services

// A labeled toggle switch row for boolean settings.
//
// Usage:
//   ToggleSection {
//     label: "深色模式"
//     value: SettingsService.data.appearance.darkMode
//     filterQuery: root.searchQuery
//     onToggled: (v) => SettingsService.data.appearance.darkMode = v
//   }
Item {
    id: root

    property string label: ""
    property bool value: false
    signal toggled(bool newValue)

    // When non-empty, this item shows only if its label matches the query,
    // otherwise it hides itself (height=0) so the parent Column skips it.
    property string filterQuery: ""

    readonly property bool _matchesFilter: filterQuery === "" ||
        label.toLowerCase().indexOf(filterQuery.toLowerCase()) !== -1
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

    // Show a subtle accent tint when this item matches an active search.
    readonly property bool searchHighlight: filterQuery !== "" && _matchesFilter

    visible: height > 0.5 || opacity > 0.01
    opacity: _matchesFilter ? (enabled ? 1 : 0.55) : 0
    height: _matchesFilter ? implicitHeight : 0

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
        width: 3; radius: 1
        color: Colors.highlight
        opacity: root.searchHighlight ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
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

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 42; height: 24

            // Toggle track — transitions between surface and highlight color
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: root.value ? Colors.highlight : Colors.surface
                opacity: 0.85
                Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
            }

            // Sliding knob
            Rectangle {
                id: knob
                width: 18; height: 18
                radius: 9
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.text
                x: root.value ? 21 : 3
                Behavior on x {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: root.enabled
                onClicked: root.toggled(!root.value)
            }
        }
    }
}
