import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "." as SessionControlParts

// Centered content shell rendered inside the fullscreen session control window.
Rectangle {
    id: root

    readonly property int _gridColumns:
        width >= Math.round(760 * Theme.uiScale) ? 2 : 1
    readonly property real _stageMaxWidth:
        width >= Math.round(760 * Theme.uiScale)
            ? Math.round(760 * Theme.uiScale)
            : Math.min(width - Math.round(56 * Theme.uiScale), Math.round(360 * Theme.uiScale))
    readonly property real _cardHeight: Math.round(212 * Theme.uiScale)
    readonly property real _gridWidth:
        root._gridColumns === 2
            ? root._stageMaxWidth
            : Math.min(root._stageMaxWidth, Math.round(360 * Theme.uiScale))
    readonly property real _gridHeight:
        Math.ceil(root._actions.length / root._gridColumns) * root._cardHeight
        + Math.max(0, Math.ceil(root._actions.length / root._gridColumns) - 1) * Math.round(16 * Theme.uiScale)
    readonly property var _actions: [
        { id: "logout", label: "注销", iconGlyph: "\uf2f5", accentColor: Colors.highlight, destructive: true },
        { id: "shutdown", label: "关机", iconGlyph: "\uf011", accentColor: Colors.destructive, destructive: true },
        { id: "reboot", label: "重启", iconGlyph: "\uf2f1", accentColor: Colors.highlight, destructive: true },
        { id: "suspend", label: "睡眠", iconGlyph: "\uf186", accentColor: Colors.highlight, destructive: false }
    ]
    readonly property string _confirmActionId:
        SessionControlService.executingAction !== ""
            ? SessionControlService.executingAction
            : SessionControlService.confirmingAction
    readonly property bool _confirmVisualActive:
        _confirmActionId !== ""
        && SessionControlService.isDangerousAction(_confirmActionId)
        && (SessionControlService.phase === "confirm" || SessionControlService.phase === "executing")
    readonly property var _confirmActionMeta:
        _actionById(root._confirmActionId)

    property real _confirmStartX: 0
    property real _confirmStartY: 0
    property real _confirmStartWidth: 0
    property real _confirmStartHeight: 0

    color: "transparent"

    function _actionById(actionId) {
        for (let actionIndex = 0; actionIndex < root._actions.length; actionIndex++) {
            let action = root._actions[actionIndex]
            if (action.id === actionId)
                return action
        }

        return root._actions.length > 0 ? root._actions[0] : null
    }

    function _captureConfirmRect(anchorItem) {
        if (!anchorItem)
            return

        const topLeft = anchorItem.mapToItem(root, 0, 0)
        root._confirmStartX = topLeft.x
        root._confirmStartY = topLeft.y
        root._confirmStartWidth = anchorItem.width
        root._confirmStartHeight = anchorItem.height
    }

    function _handleActionPressed(actionId, anchorItem) {
        if (!actionId || SessionControlService.busy)
            return

        SessionControlService.previewAction(actionId)

        if (SessionControlService.isDangerousAction(actionId)) {
            root._captureConfirmRect(anchorItem)
            SessionControlService.beginDangerConfirmation(actionId)
            return
        }

        SessionControlService.executeAction(actionId)
    }

    Item {
        id: _stageRoot
        anchors.fill: parent
        layer.enabled: root._confirmVisualActive

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(28 * Theme.uiScale)
            spacing: Math.round(18 * Theme.uiScale)

            RowLayout {
                id: _headerRow
                Layout.fillWidth: true
                spacing: 14
                opacity: root._confirmVisualActive ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Easing.InOutCubic }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Session Control"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody + 14
                    font.weight: Font.DemiBold
                    color: Colors.text
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.52)
                    border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.68)
                    border.width: 1
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredHeight: _sourceLabel.implicitHeight + 18
                    Layout.preferredWidth: _sourceLabel.implicitWidth + 22

                    Text {
                        id: _sourceLabel
                        anchors.centerIn: parent
                        text: SessionControlService.source === "super-island" ? "SuperIsland" : "Shell"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall + 1
                        font.weight: Font.Medium
                        color: Colors.textMuted
                    }
                }

                Rectangle {
                    id: _closeButton
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20
                    color: _closeArea.containsMouse
                        ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.74)
                        : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.32)
                    border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, _closeArea.containsMouse ? 0.9 : 0.6)
                    border.width: 1

                    Behavior on color {
                        ColorAnimation { duration: Theme.anim.highlightDuration }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody + 2
                        color: Colors.text
                    }

                    MouseArea {
                        id: _closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SessionControlService.closeSessionControl("close-button")
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Item {
                    width: root._gridWidth
                    height: root._gridHeight
                    anchors.centerIn: parent

                    GridLayout {
                        anchors.fill: parent
                        columns: root._gridColumns
                        columnSpacing: Math.round(16 * Theme.uiScale)
                        rowSpacing: Math.round(16 * Theme.uiScale)

                        Repeater {
                            model: root._actions

                            delegate: Item {
                                id: _actionShell

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredWidth:
                                    root._gridColumns === 2
                                        ? Math.round((root._gridWidth - Math.round(16 * Theme.uiScale)) / 2)
                                        : root._gridWidth
                                Layout.preferredHeight: root._cardHeight

                                opacity: root._confirmVisualActive ? 0 : 1
                                scale: root._confirmVisualActive ? 0.94 : 1

                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Easing.InOutCubic }
                                }

                                Behavior on scale {
                                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                                }

                                SessionControlParts.SessionActionCard {
                                    anchors.fill: parent
                                    label: modelData.label
                                    iconGlyph: modelData.iconGlyph
                                    accentColor: modelData.accentColor
                                    destructive: modelData.destructive
                                    selected:
                                        !root._confirmVisualActive
                                        && SessionControlService.selectedAction === modelData.id
                                    onPressed: root._handleActionPressed(modelData.id, _actionShell)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SessionControlParts.SessionDangerConfirmOverlay {
        anchors.fill: parent
        stageSource: _stageRoot
        active: root._confirmVisualActive
        executing: SessionControlService.phase === "executing"
        actionMeta: root._confirmActionMeta
        startX: root._confirmStartX
        startY: root._confirmStartY
        startWidth: root._confirmStartWidth
        startHeight: root._confirmStartHeight
    }
}
