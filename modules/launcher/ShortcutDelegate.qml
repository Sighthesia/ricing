import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
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
    radius: MenuVisuals.rowRadius
    color: mouseArea.containsMouse
        ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.2)
        : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.1)
    readonly property color shellBadgeColor: Qt.rgba(
        Services.Color.mPrimary.r,
        Services.Color.mPrimary.g,
        Services.Color.mPrimary.b,
        0.26
    )
    readonly property color neutralBadgeColor: Qt.rgba(
        Services.Color.mOnSurface.r,
        Services.Color.mOnSurface.g,
        Services.Color.mOnSurface.b,
        0.2
    )
    readonly property color shellBadgeLabelColor: Services.Color.mPrimary
    readonly property color neutralBadgeLabelColor: Services.Color.mOnSurfaceVariant
    readonly property color editFieldColor: Qt.rgba(
        Services.Color.mOnSurface.r,
        Services.Color.mOnSurface.g,
        Services.Color.mOnSurface.b,
        0.14
    )
    readonly property color editFieldActiveColor: Qt.rgba(
        Services.Color.mOnSurface.r,
        Services.Color.mOnSurface.g,
        Services.Color.mOnSurface.b,
        0.24
    )

    property bool editing: false

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Row {
        anchors { fill: parent; leftMargin: MenuVisuals.listContentInset; rightMargin: MenuVisuals.listContentInset }
        spacing: MenuVisuals.contentSpacing

        // Category badge
        Rectangle {
            width: catText.implicitWidth + 12
            height: 20
            radius: MenuVisuals.badgeRadius
            anchors.verticalCenter: parent.verticalCenter
            color: delegate.managedByShell ? delegate.shellBadgeColor : delegate.neutralBadgeColor

            Text {
                id: catText
                anchors.centerIn: parent
                text: delegate.category
                color: delegate.managedByShell ? delegate.shellBadgeLabelColor : delegate.neutralBadgeLabelColor
                font.pixelSize: 10
            }
        }

        // Action label
        Text {
            width: parent.width * 0.4
            anchors.verticalCenter: parent.verticalCenter
            text: delegate.label
            color: Services.Color.mOnSurface
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        // Key sequence display / edit
        Rectangle {
            width: seqInput.visible ? 140 : seqText.implicitWidth + 16
            height: MenuVisuals.compactControlHeight
            radius: MenuVisuals.badgeRadius
            anchors.verticalCenter: parent.verticalCenter
            color: delegate.editing ? delegate.editFieldActiveColor : delegate.editFieldColor
            border.color: delegate.editing ? Services.Color.mPrimary : "transparent"
            border.width: 1

            // Display mode
            Text {
                id: seqText
                anchors.centerIn: parent
                text: delegate.sequence
                color: Services.Color.mOnSurface
                font.pixelSize: 12
                font.family: "monospace"
                visible: !delegate.editing
            }

            // Edit mode
            TextInput {
                id: seqInput
                anchors { fill: parent; margins: MenuVisuals.smallGap }
                color: Services.Color.mOnSurface
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
