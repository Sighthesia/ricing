import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "." as SessionControlParts

// Centered content shell rendered inside the fullscreen session control window.
Rectangle {
    id: root

    readonly property int _gridColumns:
        width >= Math.round(1320 * Theme.uiScale)
            ? 4
            : (width >= Math.round(880 * Theme.uiScale) ? 2 : 1)
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

    radius: Theme.cornerRadius + 12
    color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.62)
    border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.78)
    border.width: 1
    clip: true

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

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
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

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: root._gridColumns
                columnSpacing: Math.round(16 * Theme.uiScale)
                rowSpacing: Math.round(16 * Theme.uiScale)

                Repeater {
                    model: root._actions

                    delegate: Item {
                        id: _actionShell

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: Math.round(188 * Theme.uiScale)
                        Layout.preferredHeight: Math.round(212 * Theme.uiScale)

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

            Rectangle {
                id: _footerBar
                Layout.fillWidth: true
                Layout.preferredHeight: _footerRow.implicitHeight + 24
                radius: Theme.cornerRadius + 4
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.44)
                border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.64)
                border.width: 1
                opacity: root._confirmVisualActive ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Easing.InOutCubic }
                }

                RowLayout {
                    id: _footerRow
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: Qt.rgba(
                            SessionControlService.lastError !== "" ? Colors.destructive.r : Colors.highlight.r,
                            SessionControlService.lastError !== "" ? Colors.destructive.g : Colors.highlight.g,
                            SessionControlService.lastError !== "" ? Colors.destructive.b : Colors.highlight.b,
                            0.16
                        )

                        Text {
                            anchors.centerIn: parent
                            text: SessionControlService.lastError !== ""
                                ? "!"
                                : (_actionById(SessionControlService.selectedAction) ? _actionById(SessionControlService.selectedAction).iconGlyph : "\uf05a")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeBody + 2
                            color: SessionControlService.lastError !== "" ? Colors.destructive : Colors.highlight
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: SessionControlService.lastError !== ""
                                ? "执行失败"
                                : (_actionById(SessionControlService.selectedAction) ? _actionById(SessionControlService.selectedAction).label : "Session")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody + 1
                            font.weight: Font.Medium
                            color: Colors.text
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: SessionControlService.lastError !== "" ? "检查 systemctl / loginctl 权限" : "危险操作需要二次确认"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall + 1
                            color: Colors.textMuted
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.54)
                        border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.74)
                        border.width: 1
                        Layout.preferredWidth: Math.round(116 * Theme.uiScale)
                        Layout.preferredHeight: Math.round(42 * Theme.uiScale)

                        Text {
                            anchors.centerIn: parent
                            text: "关闭页面"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            font.weight: Font.Medium
                            color: Colors.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SessionControlService.closeSessionControl("footer-close")
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
