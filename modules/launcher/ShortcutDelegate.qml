import QtQuick
import QtQuick.Effects
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
    property real _filterOffset: 0
    property real _filterSoftness: 0

    width: ListView.view.width
    height: 52
    radius: MenuVisuals.rowRadius
    layer.enabled: _filterSoftness > 0.01
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 12
        blur: delegate._filterSoftness * 0.35
    }
    transform: Translate { x: delegate._filterOffset }
    color: mouseArea.containsMouse
        ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listHoverOpacity)
        : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listRestOpacity)
    readonly property color shellBadgeColor: Qt.rgba(
        Services.Color.mPrimary.r,
        Services.Color.mPrimary.g,
        Services.Color.mPrimary.b,
        MenuVisuals.primaryBadgeOpacity
    )
    readonly property color neutralBadgeColor: Qt.rgba(
        Services.Color.mOnSurface.r,
        Services.Color.mOnSurface.g,
        Services.Color.mOnSurface.b,
        MenuVisuals.listHoverOpacity
    )
    readonly property color shellBadgeLabelColor: Services.Color.mPrimary
    readonly property color neutralBadgeLabelColor: Services.Color.mOnSurfaceVariant
    readonly property color editFieldColor: Qt.rgba(
        Services.Color.mOnSurface.r,
        Services.Color.mOnSurface.g,
        Services.Color.mOnSurface.b,
        MenuVisuals.fieldRestOpacity
    )
    readonly property color editFieldActiveColor: Qt.rgba(
        Services.Color.mOnSurface.r,
        Services.Color.mOnSurface.g,
        Services.Color.mOnSurface.b,
        MenuVisuals.fieldActiveOpacity
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
