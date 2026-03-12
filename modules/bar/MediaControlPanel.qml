import Quickshell
import QtQuick
import qs.config
import qs.services
import "media" as MediaParts

// Drop-down media panel opened from the compact media widget blank area.
AnimatedPanelBase {
    id: root

    anchors { top: true; left: true }
    margins {
        top: Theme.barHeight
        left: Math.max(0, BarLayoutService.mediaControlPanelX - implicitWidth / 2)
    }
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: Theme.barWidget.mediaPanelWidth + Theme.settingsPanelPadding * 2 + 8
    implicitHeight: _content.implicitHeight + 8
    focusable: false
    closeOpacityDelay: Math.max(Theme.staggerDelay * 4, Math.round(Theme.anim.moveDuration / 2))
    closeOpacityDuration: Math.max(1, Math.round(Theme.anim.highlightDuration * 0.94))
    closeScaleDelay: Math.max(Theme.staggerDelay * 3, Math.round(Theme.anim.highlightDuration * 0.61))
    closeScaleDuration: Math.max(1, Math.round(Theme.anim.springDuration * 0.67))

    active: MediaControlService.panelOpen

    Timer {
        id: _staggerDelay
        interval: Math.max(Theme.staggerDelay * 4, Math.round(Theme.anim.moveDuration / 2)); repeat: false
        onTriggered: _content.runEnterAnimation()
    }

    // Panel frame.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1
    }

    // Panel content.
    MediaParts.MediaPanelContent {
        id: _content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.topMargin: 4
    }

    Connections {
        target: root
        function onPanelOpening() { _staggerDelay.restart() }
        function onPanelClosing() {
            _staggerDelay.stop()
            _content.runExitAnimation()
        }
    }
}