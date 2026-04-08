import Quickshell
import Quickshell.Wayland
import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config
import qs.services
import "." as SessionControlParts

// Fullscreen modal surface for logout and power-related session actions.
Variants {
    id: root

    model: Quickshell.screens

    PanelWindow {
        id: window

        required property var modelData

        readonly property bool _interactiveScreen:
            Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]
        readonly property string _confirmActionId:
            SessionControlService.executingAction !== ""
                ? SessionControlService.executingAction
                : SessionControlService.confirmingAction
        readonly property bool _confirmVisualActive:
            _confirmActionId !== ""
            && SessionControlService.isDangerousAction(_confirmActionId)
            && (SessionControlService.phase === "confirm" || SessionControlService.phase === "executing")
        readonly property int _outerMargin: Math.max(24, Math.round(32 * Theme.uiScale))
        readonly property int _contentWidth: Math.min(width - _outerMargin * 2, Math.round(1160 * Theme.uiScale))
        readonly property int _contentHeight: Math.min(height - _outerMargin * 2, Math.round(760 * Theme.uiScale))
        readonly property real _focusTargetRadius:
            Math.max(
                Math.round(260 * Theme.uiScale),
                Math.sqrt(_contentWidth * _contentWidth + _contentHeight * _contentHeight) * 0.26
            )
        readonly property real _focusMaxRadius:
            Math.sqrt(width * width + height * height) + Math.round(180 * Theme.uiScale)

        property real _focusOverlayOpacity: _confirmVisualActive ? 1 : 0
        property real _focusMaskRadius: _confirmVisualActive ? _focusTargetRadius : _focusMaxRadius

        screen: modelData
        visible: SessionControlService.visible
        focusable: SessionControlService.visible && window._interactiveScreen
        color: "transparent"
        anchors { left: true; top: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus:
            SessionControlService.visible && window._interactiveScreen
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None

        Behavior on _focusOverlayOpacity {
            NumberAnimation {
                duration: Theme.anim.highlightDuration
                easing.type: Easing.InOutCubic
            }
        }

        Behavior on _focusMaskRadius {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        Shortcut {
            sequence: "Escape"
            enabled: SessionControlService.visible && window._interactiveScreen
            onActivated: SessionControlService.handleEscape()
        }

        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.82)
        }

        Rectangle {
            width: Math.round(window.width * 0.44)
            height: width
            radius: width / 2
            x: -width * 0.18
            y: -height * 0.08
            color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
        }

        Rectangle {
            width: Math.round(window.width * 0.34)
            height: width
            radius: width / 2
            x: window.width - width * 0.82
            y: window.height - height * 0.76
            color: Qt.rgba(Colors.destructive.r, Colors.destructive.g, Colors.destructive.b, 0.09)
        }

        Item {
            id: _focusMaskSource
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true

            Rectangle {
                anchors.fill: parent
                color: "white"
            }

            Rectangle {
                width: window._focusMaskRadius * 2
                height: width
                radius: width / 2
                x: window.width / 2 - width / 2
                y: window.height / 2 - height / 2
                color: "black"
            }
        }

        Item {
            id: _focusDimSource
            anchors.fill: parent
            visible: false

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.24)
            }
        }

        OpacityMask {
            anchors.fill: parent
            source: _focusDimSource
            maskSource: _focusMaskSource
            opacity: window._focusOverlayOpacity
            visible: Theme.graphicalEffectsEnabled && (window._confirmVisualActive || window._focusOverlayOpacity > 0.01)
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.24)
            opacity: Theme.graphicalEffectsEnabled ? 0 : window._focusOverlayOpacity
            visible: !Theme.graphicalEffectsEnabled && (window._confirmVisualActive || window._focusOverlayOpacity > 0.01)
        }

        SessionControlParts.SessionControlContent {
            anchors.centerIn: parent
            width: window._contentWidth
            height: window._contentHeight
        }
    }
}
