import QtQuick
import qs.config
import qs.services

Item {
    id: settingsToggle

    readonly property bool panelOpen: BarLayoutService.activePanel !== "none"

    // Expand width to accommodate tab bar when panel is open
    implicitWidth: panelOpen
        ? tabRow.implicitWidth + Theme.widgetSpacing + gearBtn.implicitWidth
        : gearBtn.implicitWidth
    implicitHeight: Theme.barHeight - Theme.barPadding

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Easing.InOutCubic }
    }

    // Tab bar: slides in from the left when any panel is open
    Row {
        id: tabRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: 4
        opacity: settingsToggle.panelOpen ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Easing.OutQuad }
        }

        // Layout tab
        Rectangle {
            width: 52; height: 24
            radius: Theme.cornerRadius - 4
            color: BarLayoutService.activePanel === "layout" ? Colors.highlight : Colors.surface
            opacity: BarLayoutService.activePanel === "layout" ? 0.9 : 0.6

            Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

            Text {
                anchors.centerIn: parent
                text: "布局"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.text
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: BarLayoutService.activePanel = "layout"
            }
        }

        // Config tab
        Rectangle {
            width: 52; height: 24
            radius: Theme.cornerRadius - 4
            color: BarLayoutService.activePanel === "config" ? Colors.highlight : Colors.surface
            opacity: BarLayoutService.activePanel === "config" ? 0.9 : 0.6

            Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

            Text {
                anchors.centerIn: parent
                text: "设置"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.text
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: BarLayoutService.activePanel = "config"
            }
        }
    }

    // Gear button area
    Item {
        id: gearBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Theme.barHeight - Theme.barPadding
        implicitHeight: Theme.barHeight - Theme.barPadding

        // Background rectangle: reveals on hover and any panel mode
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Colors.highlight
            opacity: settingsToggle.panelOpen
                ? Colors.highlightAlpha
                : (hoverArea.containsMouse ? 0.08 : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.highlightDuration
                    easing.type: settingsToggle.panelOpen ? Easing.OutExpo : Easing.InExpo
                }
            }
        }

        // Gear icon — rotates to X when any panel is open
        Text {
            id: icon
            anchors.centerIn: parent
            text: "\uf013"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeIcon
            color: Colors.text

            rotation: settingsToggle.panelOpen ? 45 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: settingsToggle.panelOpen
                        ? Theme.anim.enterDuration : Theme.anim.exitDuration
                    easing.type: settingsToggle.panelOpen ? Easing.OutElastic : Easing.InExpo
                    easing.amplitude: settingsToggle.panelOpen ? Theme.anim.enterAmplitude : 1.0
                    easing.period: settingsToggle.panelOpen ? Theme.anim.enterPeriod : 0.3
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                // Toggle: close if open, default to layout tab on first open
                BarLayoutService.activePanel =
                    settingsToggle.panelOpen ? "none" : "layout"
            }
        }
    }

    // Periodic pulse in any panel mode (every 3s)
    Timer {
        interval: Theme.pulseInterval
        repeat: true
        running: settingsToggle.panelOpen
        onTriggered: {
            if (settingsToggle.parent && settingsToggle.parent.pulse)
                settingsToggle.parent.pulse(1)
        }
    }

    // Global Esc always closes any panel
    Shortcut {
        sequence: "Escape"
        enabled: settingsToggle.panelOpen
        onActivated: BarLayoutService.activePanel = "none"
    }
}

