import Quickshell
import QtQuick
import qs.config
import qs.services
import "./settings"

// Floating settings panel that appears below the Bar at the right side of the screen.
// Uses AnimatedPanelBase for a drop-down expand/collapse animation.
AnimatedPanelBase {
    id: panelWindow

    readonly property var _closeButton: _closeButtonSurface
    readonly property int _headerHeight: 32
    readonly property bool _usesCenteredPlacement: true
    readonly property bool _isSettingsPanelBareHarness:
        Quickshell.env("DYMICSHELL_TEST_HARNESS") === "SettingsPanelWindowBareSmoke"

    // Sit below the bar; without left/right anchoring, the compositor keeps the panel centered.
    anchors { top: true }
    margins { top: Theme.barHeight }

    implicitWidth: 480
    // Fixed height avoids per-frame Wayland surface resize during expand/collapse
    // animations. Content scrolls internally via AppearancePage's Flickable.
    implicitHeight: 580

    // Keyboard input for hex color editing
    focusable: true

    // Logical open/close trigger — AnimatedPanelBase manages actual window visibility
    active: BarLayoutService.activePanel === "config"

    // Panel background card
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        // Subtle inner shadow effect: second border inset
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.cornerRadius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
        }

        // Clicking blank space inside the panel clears any jump-to highlights
        // and dismisses the search dropdown (unfocuses search field).
        MouseArea {
            anchors.fill: parent
            onClicked: {
                content.clearAllHighlights()
                content.dismissSearch()
            }
        }

        Row {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 12
                leftMargin: 12
                rightMargin: 12
            }
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "设置"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.weight: Font.Medium
                color: Colors.text
            }

            Item {
                width: Math.max(0, parent.width - _closeButtonSurface.width - 48)
                height: 1
            }

            Rectangle {
                id: _closeButtonSurface
                width: 28
                height: 28
                radius: Theme.cornerRadius - 2
                color: _closeButtonArea.containsMouse ? Colors.surface : "transparent"
                border.color: _closeButtonArea.containsMouse ? Colors.border : "transparent"
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    color: Colors.text
                }

                MouseArea {
                    id: _closeButtonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BarLayoutService.activePanel = "none"
                }
            }
        }
    }

    Loader {
        id: contentLoader
        anchors {
            fill: parent
            topMargin: panelWindow._headerHeight + 14
            leftMargin: 4
            rightMargin: 8
            bottomMargin: 10
        }
        sourceComponent: panelWindow._isSettingsPanelBareHarness
            ? settingsPanelStubComponent
            : settingsPanelContentComponent
    }

    readonly property Item content: contentLoader.item

    Component {
        id: settingsPanelContentComponent

        SettingsPanelContent {}
    }

    Component {
        id: settingsPanelStubComponent

        Item {
            function clearAllHighlights() {}
            function dismissSearch() {}
            function runEnterAnimation() {}
            function runExitAnimation() {}
        }
    }

    // Forward AnimatedPanelBase transition signals to content so it can run
    // stagger enter/exit animations on its child items.
    // Delay the enter stagger so it fires after the panel's own opacity animation
    // is mostly complete (60ms delay + 180ms duration = ~240ms total). This ensures
    // users see the panel expand first, then content slides in — without the internal
    // stagger being masked by the outer _wrapper opacity fade.
    Timer {
        id: _staggerDelay
        interval: 200; repeat: false
        onTriggered: content.runEnterAnimation()
    }

    Connections {
        target: panelWindow
        function onPanelOpening() { _staggerDelay.restart() }
        function onPanelClosing() {
            _staggerDelay.stop()
            content.runExitAnimation()
        }
    }
}
