import QtQuick
import "../../services" as Services

// Single shortcut row: key sequence (editable) + action label + category badge.
Rectangle {
    id: delegate

    required property int index
    required property string entryId
    required property string label
    required property string sequence
    required property string category
    required property bool managedByShell

    width: ListView.view.width
    height: 52
    radius: 6
    color: mouseArea.containsMouse ? "#33ffffff" : "#1affffff"

    property bool editing: false

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Row {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 8

        // Category badge
        Rectangle {
            width: catText.implicitWidth + 12
            height: 20
            radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: delegate.managedByShell ? "#44448aff" : "#33ffffff"

            Text {
                id: catText
                anchors.centerIn: parent
                text: delegate.category
                color: delegate.managedByShell ? "#88aaff" : "#aaaaaa"
                font.pixelSize: 10
            }
        }

        // Action label
        Text {
            width: parent.width * 0.4
            anchors.verticalCenter: parent.verticalCenter
            text: delegate.label
            color: "white"
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        // Key sequence display / edit
        Rectangle {
            width: seqInput.visible ? 140 : seqText.implicitWidth + 16
            height: 28
            radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: delegate.editing ? "#44ffffff" : "#22ffffff"
            border.color: delegate.editing ? "#88aaff" : "transparent"
            border.width: 1

            // Display mode
            Text {
                id: seqText
                anchors.centerIn: parent
                text: delegate.sequence
                color: "#dddddd"
                font.pixelSize: 12
                font.family: "monospace"
                visible: !delegate.editing
            }

            // Edit mode
            TextInput {
                id: seqInput
                anchors { fill: parent; margins: 4 }
                color: "white"
                font.pixelSize: 12
                font.family: "monospace"
                visible: delegate.editing
                text: delegate.sequence

                Keys.onReturnPressed: delegate._commitEdit()
                Keys.onEscapePressed: delegate.editing = false
            }

            MouseArea {
                anchors.fill: parent
                visible: !delegate.editing
                onDoubleClicked: {
                    delegate.editing = true
                    seqInput.text = delegate.sequence
                    seqInput.forceActiveFocus()
                    seqInput.selectAll()
                }
            }
        }
    }

    function _commitEdit() {
        let newSeq = seqInput.text.trim()
        if (newSeq && newSeq !== delegate.sequence) {
            Services.NiriShortcutService.updateSequence(delegate.entryId, newSeq)
        }
        delegate.editing = false
    }
}
