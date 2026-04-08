import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.config
import qs.services
import "." as SessionControlParts

// Focused danger-confirmation layer that blurs surrounding content with a shrinking circular mask.
Item {
    id: root

    required property Item stageSource

    property bool active: false
    property bool executing: false
    property var actionMeta: null
    property real startX: 0
    property real startY: 0
    property real startWidth: 0
    property real startHeight: 0

    readonly property real _cardWidth: Math.min(width - Math.round(96 * Theme.uiScale), Math.round(320 * Theme.uiScale))
    readonly property real _cardHeight: Math.round(212 * Theme.uiScale)
    readonly property real _buttonWidth: Math.round(132 * Theme.uiScale)
    readonly property real _buttonHeight: Math.round(42 * Theme.uiScale)
    readonly property real _groupGap: Math.round(18 * Theme.uiScale)
    readonly property real _promptWidth: Math.max(_cardWidth, _buttonRow.implicitWidth)
    readonly property real _groupHeight: _cardHeight + _groupGap + _promptBlock.implicitHeight
    readonly property real _finalCardX: (width - _cardWidth) / 2
    readonly property real _finalCardY: (height - _groupHeight) / 2
    readonly property real _focusCenterX: width / 2
    readonly property real _focusCenterY: _finalCardY + _groupHeight / 2
    readonly property real _maskMaxRadius:
        Math.sqrt(width * width + height * height) + Math.round(140 * Theme.uiScale)
    readonly property real _maskTargetRadius:
        Math.max(
            Math.round(220 * Theme.uiScale),
            Math.sqrt(_promptWidth * _promptWidth + _groupHeight * _groupHeight) / 2 + Math.round(54 * Theme.uiScale)
        )

    property real _overlayProgress: active ? 1 : 0
    property real _maskRadius: active ? _maskTargetRadius : _maskMaxRadius

    visible: active || _overlayProgress > 0.01
    z: 20

    Behavior on _overlayProgress {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    Behavior on _maskRadius {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    FastBlur {
        id: _blurSource
        anchors.fill: parent
        source: root.stageSource
        radius: Theme.graphicalEffectsEnabled ? Math.round(36 * root._overlayProgress) : 0
        visible: false
    }

    Item {
        id: _blurMaskSource
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            color: "white"
        }

        Rectangle {
            width: root._maskRadius * 2
            height: width
            radius: width / 2
            x: root._focusCenterX - width / 2
            y: root._focusCenterY - height / 2
            color: "black"
        }
    }

    OpacityMask {
        anchors.fill: parent
        source: _blurSource
        maskSource: _blurMaskSource
        opacity: root._overlayProgress
        visible: Theme.graphicalEffectsEnabled && root.visible
    }

    Item {
        id: _dimSource
        anchors.fill: parent
        visible: false

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.42)
        }
    }

    OpacityMask {
        anchors.fill: parent
        source: _dimSource
        maskSource: _blurMaskSource
        opacity: root._overlayProgress
        visible: Theme.graphicalEffectsEnabled && root.visible
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.42)
        opacity: Theme.graphicalEffectsEnabled ? 0 : root._overlayProgress
        visible: !Theme.graphicalEffectsEnabled && root.visible
    }

    SessionControlParts.SessionActionCard {
        id: _focusCard

        x: root.active ? root._finalCardX : root.startX
        y: root.active ? root._finalCardY : root.startY
        width: root.active ? root._cardWidth : root.startWidth
        height: root.active ? root._cardHeight : root.startHeight
        opacity: root._overlayProgress

        label: root.actionMeta ? root.actionMeta.label : ""
        iconGlyph: root.actionMeta ? root.actionMeta.iconGlyph : ""
        accentColor: root.actionMeta ? root.actionMeta.accentColor : Colors.highlight
        destructive: root.actionMeta ? root.actionMeta.destructive === true : false
        selected: true
        interactive: false

        Behavior on x {
            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
        }

        Behavior on y {
            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
        }

        Behavior on width {
            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
        }

        Behavior on height {
            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
        }
    }

    ColumnLayout {
        id: _promptBlock

        width: root._promptWidth
        anchors.horizontalCenter: parent.horizontalCenter
        y: _focusCard.y + _focusCard.height + root._groupGap
        spacing: Math.round(12 * Theme.uiScale)
        opacity: root._overlayProgress
        visible: root.visible

        Behavior on y {
            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Easing.InOutCubic }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.executing
                ? (root.actionMeta ? ("正在" + root.actionMeta.label) : "正在执行")
                : (root.actionMeta ? ("确认" + root.actionMeta.label + "？") : "确认执行？")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody + 6
            font.weight: Font.DemiBold
            color: Colors.text
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: SessionControlService.lastError !== "" ? "执行失败" : ""
            visible: text !== ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall + 1
            color: Colors.destructive
        }

        RowLayout {
            id: _buttonRow

            Layout.alignment: Qt.AlignHCenter
            spacing: Math.round(12 * Theme.uiScale)

            Rectangle {
                Layout.preferredWidth: root._buttonWidth
                Layout.preferredHeight: root._buttonHeight
                radius: Theme.cornerRadius
                color: _cancelArea.containsMouse
                    ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.78)
                    : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.56)
                border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, _cancelArea.containsMouse ? 0.9 : 0.72)
                border.width: 1
                visible: !root.executing

                Behavior on color {
                    ColorAnimation { duration: Theme.anim.highlightDuration }
                }

                Text {
                    anchors.centerIn: parent
                    text: "取消"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.weight: Font.Medium
                    color: Colors.text
                }

                MouseArea {
                    id: _cancelArea
                    anchors.fill: parent
                    enabled: !root.executing
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SessionControlService.cancelDangerConfirmation()
                }
            }

            Rectangle {
                Layout.preferredWidth: root._buttonWidth
                Layout.preferredHeight: root._buttonHeight
                radius: Theme.cornerRadius
                color: _confirmArea.containsMouse && !root.executing
                    ? Qt.rgba(Colors.destructive.r, Colors.destructive.g, Colors.destructive.b, 0.90)
                    : Qt.rgba(Colors.destructive.r, Colors.destructive.g, Colors.destructive.b, 0.76)
                border.color: Qt.rgba(Colors.destructive.r, Colors.destructive.g, Colors.destructive.b, 0.96)
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: Theme.anim.highlightDuration }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.executing ? "执行中" : (root.actionMeta ? root.actionMeta.label : "确认")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.weight: Font.DemiBold
                    color: Colors.background
                }

                MouseArea {
                    id: _confirmArea
                    anchors.fill: parent
                    enabled: !root.executing
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.actionMeta) SessionControlService.executeAction(root.actionMeta.id)
                }
            }
        }
    }
}
