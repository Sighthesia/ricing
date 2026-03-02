import QtQuick
import qs.config
import qs.services

Item {
    id: settingsToggle

    implicitWidth: Theme.barHeight - 8
    implicitHeight: Theme.barHeight - 8

    // Background rectangle: reveals on hover and settings mode
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Palette.highlight
        opacity: BarLayoutService.settingsMode
            ? Palette.highlightAlpha
            : (hoverArea.containsMouse ? 0.08 : 0)

        Behavior on opacity {
            NumberAnimation {
                duration: BarLayoutService.settingsMode
                    ? 180  // OutExpo for enter
                    : 180  // InExpo for exit (with delay handled below)
                easing.type: BarLayoutService.settingsMode
                    ? Easing.OutExpo
                    : Easing.InExpo
            }
        }
    }

    // Gear icon
    Text {
        id: icon
        anchors.centerIn: parent
        text: "\uf013"  // Nerd Font gear icon
        font.family: Theme.fontMono
        font.pixelSize: 16
        color: Palette.text

        rotation: BarLayoutService.settingsMode ? 45 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: BarLayoutService.settingsMode ? 500 : 220
                easing.type: BarLayoutService.settingsMode
                    ? Easing.OutElastic
                    : Easing.InExpo
                easing.amplitude: BarLayoutService.settingsMode ? 0.8 : 1.0
                easing.period: BarLayoutService.settingsMode ? 0.4 : 0.3
            }
        }
    }

    // Click handler
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            BarLayoutService.settingsMode = !BarLayoutService.settingsMode;
        }
    }

    // Periodic pulse in settings mode (every 3s)
    Timer {
        id: pulseTimer
        interval: 3000
        repeat: true
        running: BarLayoutService.settingsMode

        onTriggered: {
            // Walk up to BarWidgetWrapper parent and call pulse()
            if (settingsToggle.parent && settingsToggle.parent.pulse) {
                settingsToggle.parent.pulse(1);
            }
        }
    }

    // Global Esc to exit settings mode
    Shortcut {
        sequence: "Escape"
        enabled: BarLayoutService.settingsMode
        onActivated: {
            BarLayoutService.settingsMode = false;
        }
    }
}
